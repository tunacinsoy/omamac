load helpers/common

bats_require_minimum_version 1.5.0

# The formulas a finished first run has: the core, then bash and gum.
OMAMAC_FORMULAS='starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq bash gum'

setup() {
  setup_sandbox
  install_fake_brew
  export TMPDIR="$BATS_TEST_TMPDIR"
  # shellcheck disable=SC2086 # one formula per word
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install $OMAMAC_FORMULAS
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask ghostty
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  DROPIN="$HOME/.config/mise/conf.d/omamac.toml"
  # Only the run's own calls.
  : > "$STUB_LOG"
}

# omamac_uninstall: omamac uninstall, only ever in the sandbox, never on the real Mac.
omamac_uninstall() {
  if [ -z "${BATS_TEST_TMPDIR:-}" ] || [[ $HOME != "$BATS_TEST_TMPDIR"/* ]]; then
    echo "remove.bats: HOME isn't the sandbox; not running omamac uninstall" >&2
    return 1
  fi
  "$BASH5" "$REPO_ROOT/bin/omamac" uninstall "$@"
}

# choose <key> <value>: set one saved answer.
choose() { sed -i '' "s/^$1=.*/$1=$2/" "$CHOICES_FILE"; }

# languages <id>…: what a first run left: the choice, mise's tools, the drop-in.
languages() {
  choose languages "$*"
  # Elixir's tools are erlang and elixir.
  [ "$*" != elixir ] || set -- erlang elixir
  (cd "$HOME" && "$OMAMAC_TEST_BREW_PREFIX/bin/mise" install "$@")
  mkdir -p "$(dirname "$DROPIN")"
  { echo '[tools]'; printf '%s = "latest"\n' "$@"; } > "$DROPIN"
  : > "$STUB_LOG"
}

prompts() { grep -E '^gum (choose|confirm)' "$STUB_LOG" || true; }

# Every file under HOME with its checksum and mtime, logs included.
snapshot() {
  (cd "$HOME" && find . -type f | sort | while read -r f; do echo "$f $(shasum < "$f") $(stat -f %m "$f")"; done)
}

@test "a core name is refused" {
  gum_answers
  for name in herdr zsh gum; do
    run --separate-stderr omamac_uninstall "$name"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"$name is part of omamac's core and can't be removed on its own."* ]]
  done
  [ -z "$(prompts)" ]
}

@test "ghostty is core" {
  gum_answers
  run --separate-stderr omamac_uninstall ghostty
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"ghostty is part of omamac's core"* ]]
}

@test "an unknown name lists what can go" {
  gum_answers
  run --separate-stderr omamac_uninstall php
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"omamac can't remove 'php'. It can remove: ruby, node, go, python, elixir, rust, java, azure, aws, gcloud, gh, terraform."* ]]
  [ -z "$(prompts)" ]
}

@test "not chosen: exit 0, no file changed" {
  languages node
  before=$(snapshot)
  gum_answers
  sleep 1.1
  run omamac_uninstall go
  [ "$status" -eq 0 ]
  [[ "$output" == *"Go isn't installed by omamac."* ]]
  [ -z "$(prompts)" ]
  [ "$(snapshot)" = "$before" ]
}

@test "go: drop-in loses go, mise prune --tools go from HOME, choices lose go" {
  languages node go
  gum_answers yes
  run omamac_uninstall go
  [ "$status" -eq 0 ]
  [[ "$output" == *"Go: mise's go"* ]]
  [[ "$output" == *"✓ Go is removed"* ]]
  [[ "$output" != *"mise kept"* ]]
  grep -qx 'gum confirm --default=false Remove Go?' "$STUB_LOG"
  [ "$(grep '^mise prune' "$STUB_LOG")" = "mise prune --tools go" ]
  [ ! -e "$OMAMAC_TEST_BREW_PREFIX/mise/go" ]
  [ -e "$OMAMAC_TEST_BREW_PREFIX/mise/node" ]
  grep -qx 'node = "latest"' "$DROPIN"
  run ! grep -q '^go ' "$DROPIN"
  grep -qx 'languages=node' "$CHOICES_FILE"
}

@test "a second uninstall go changes nothing" {
  languages go
  gum_answers yes
  run omamac_uninstall go
  [ "$status" -eq 0 ]
  first=$(snapshot)
  : > "$STUB_LOG"
  sleep 1.1
  run omamac_uninstall go
  [ "$status" -eq 0 ]
  [[ "$output" == *"Go isn't installed by omamac."* ]]
  [ -z "$(prompts)" ]
  [ "$(snapshot)" = "$first" ]
}

@test "a pinned tool mise keeps is reported" {
  languages node
  gum_answers yes
  T_MISE_KEEP=node run omamac_uninstall node
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ mise kept node: another of your mise configs uses it."* ]]
  grep -qx 'languages=' "$CHOICES_FILE"
  [[ "$output" == *"✓ Node.js is removed"* ]]
}

@test "terraform: brew uninstall hashicorp/tap/terraform, never untap" {
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install hashicorp/tap/terraform
  choose cloud_clis terraform
  : > "$STUB_LOG"
  gum_answers yes
  run omamac_uninstall terraform
  [ "$status" -eq 0 ]
  [[ "$output" == *"Terraform: hashicorp/tap/terraform"* ]]
  [ "$(grep '^brew uninstall' "$STUB_LOG")" = "brew uninstall hashicorp/tap/terraform" ]
  run ! grep -q '^brew untap' "$STUB_LOG"
  [ ! -e "$OMAMAC_TEST_BREW_PREFIX/Cellar/terraform" ]
  grep -qx 'cloud_clis=' "$CHOICES_FILE"
}

@test "gcloud: brew uninstall --cask gcloud-cli" {
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask gcloud-cli
  choose cloud_clis 'gcloud gh'
  : > "$STUB_LOG"
  gum_answers yes
  run omamac_uninstall gcloud
  [ "$status" -eq 0 ]
  [[ "$output" == *"Google Cloud CLI: the gcloud-cli cask"* ]]
  [ "$(grep '^brew uninstall' "$STUB_LOG")" = "brew uninstall --cask gcloud-cli" ]
  [ ! -e "$OMAMAC_TEST_BREW_PREFIX/Caskroom/gcloud-cli" ]
  grep -qx 'cloud_clis=gh' "$CHOICES_FILE"
}

@test "removed by hand: no brew call, choice dropped" {
  choose cloud_clis gh
  gum_answers yes
  run omamac_uninstall gh
  [ "$status" -eq 0 ]
  run ! grep -q '^brew uninstall' "$STUB_LOG"
  grep -qx 'cloud_clis=' "$CHOICES_FILE"
}

@test "brew refuses: exit 1, choice still saved" {
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gh
  choose cloud_clis gh
  gum_answers yes
  T_BREW_UNINSTALL_FAIL=1 run omamac_uninstall gh
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while removing GitHub CLI."* ]]
  [ "$(grep -c 'omamac stopped' <<< "$output")" -eq 1 ]
  [[ "$output" == *"Fix the problem and run omamac uninstall again."* ]]
  grep -qx 'cloud_clis=gh' "$CHOICES_FILE"
}

@test "no at Remove?: nothing changes" {
  languages elixir
  before=$(snapshot)
  gum_answers no
  sleep 1.1
  run omamac_uninstall elixir
  [ "$status" -eq 0 ]
  [[ "$output" == *"Elixir: mise's erlang and elixir"* ]]
  [[ "$output" == *"Nothing was removed."* ]]
  run ! grep -q '^mise prune' "$STUB_LOG"
  [ "$(snapshot)" = "$before" ]
}

@test "Ctrl-C at Remove?: exit 130" {
  languages go
  before=$(snapshot)
  gum_answers "exit 130"
  sleep 1.1
  run omamac_uninstall go
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "no name: Nothing first, then the chosen labels" {
  languages node go
  choose cloud_clis terraform
  before=$(snapshot)
  gum_answers none
  sleep 1.1
  run omamac_uninstall
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum choose --header What should omamac remove? --label-delimiter=: Nothing:none Node.js:node Go:go Terraform:terraform" ]
  [ "$(snapshot)" = "$before" ]
}

@test "no name: the pick is removed" {
  languages node go
  gum_answers go yes
  run omamac_uninstall
  [ "$status" -eq 0 ]
  grep -qx 'gum confirm --default=false Remove Go?' "$STUB_LOG"
  grep -qx 'languages=node' "$CHOICES_FILE"
}

@test "no name, nothing chosen: no prompt" {
  gum_answers
  run omamac_uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"omamac installed no languages or cloud CLIs, so there's nothing to remove."* ]]
  [ -z "$(prompts)" ]
}

@test "more than one name: usage, exit 2" {
  gum_answers
  run --separate-stderr omamac_uninstall go node
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Usage: omamac <command>"* ]]
  [ -z "$(prompts)" ]
}

# desktops_on: what a first run with desktops=yes left.
desktops_on() {
  mkdir -p "$T_DEFAULTS_DIR"
  defaults write com.apple.Accessibility ReduceMotionEnabled -int 0
  "$BASH5" -c "
    set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    source '$REPO_ROOT/lib/paths.sh'; source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/questions.sh'; source '$REPO_ROOT/lib/choices.sh'
    source '$REPO_ROOT/lib/settings.sh'
    CHOICES[desktops]=yes; settings_apply" > /dev/null
  choose desktops yes
  : > "$STUB_LOG"
}

REC() { echo "$HOME/.local/state/omamac/macos-settings.tsv"; }

@test "uninstall desktops" {
  desktops_on
  gum_answers yes
  run omamac_uninstall desktops
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktops as workspaces: your earlier Spaces, app-switching and Reduce motion settings"* ]]
  grep -qx 'gum confirm --default=false Remove Desktops as workspaces?' "$STUB_LOG"
  grep -qx 'desktops=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
  run defaults read com.apple.dock mru-spaces
  [ "$status" -ne 0 ]
  [ "$(defaults read com.apple.Accessibility ReduceMotionEnabled)" = 0 ]
}

@test "uninstall window-margins maps the name" {
  choose window_margins yes
  defaults write com.apple.WindowManager EnableTiledWindowMargins -bool true
  mkdir -p "$(dirname "$(REC)")"
  printf 'com.apple.WindowManager\tEnableTiledWindowMargins\tabsent\n' > "$(REC)"
  gum_answers yes
  run omamac_uninstall window-margins
  [ "$status" -eq 0 ]
  [[ "$output" == *"Window margins: your earlier window-margin setting"* ]]
  grep -qx 'window_margins=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
  run defaults read com.apple.WindowManager EnableTiledWindowMargins
  [ "$status" -ne 0 ]
}

@test "not set by omamac" {
  gum_answers
  run omamac_uninstall desktops
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktops as workspaces isn't set by omamac."* ]]
  [ -z "$(prompts)" ]
}

@test "no-name menu offers settings answered yes" {
  choose languages node
  choose window_margins yes
  gum_answers none
  run omamac_uninstall
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum choose --header What should omamac remove? --label-delimiter=: Nothing:none Node.js:node Window margins:window-margins" ]
}

@test "a failed restore leaves the answer yes and the rest recorded" {
  desktops_on
  gum_answers yes
  T_DEFAULTS_FAIL=NSGlobalDomain:AppleSpacesSwitchOnActivate run omamac_uninstall desktops
  [ "$status" -ne 0 ]
  grep -qx 'desktops=yes' "$CHOICES_FILE"
  [[ "$(cat "$(REC)")" != *mru-spaces* ]]
  [[ "$(cat "$(REC)")" == *AppleSpacesSwitchOnActivate* ]]
  [[ "$(cat "$(REC)")" == *ReduceMotionEnabled* ]]
  gum_answers yes
  run omamac_uninstall desktops
  [ "$status" -eq 0 ]
  grep -qx 'desktops=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
}
