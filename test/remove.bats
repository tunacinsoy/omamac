load helpers/common
load helpers/dock

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

@test "a core name is refused even without saved answers" {
  rm "$CHOICES_FILE"
  gum_answers
  run --separate-stderr omamac_uninstall herdr
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"herdr is part of omamac's core and can't be removed on its own."* ]]
  [[ "$stderr" != *"doesn't know your answers"* ]]
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
  [[ "$stderr" == *"omamac can't remove 'php'. It can remove: ruby, node, go, python, elixir, rust, java, azure, aws, gcloud, gh, terraform, claude-code, antigravity-cli, opencode, brave, chrome, firefox, whatsapp, telegram, signal, discord, slack, zoom, spotify, vlc, cap, dropbox, google-drive, vscode, claude, chatgpt, copilot, antigravity, raycast, obsidian, wispr-flow, desktops, window-margins, colima, docker-desktop, dock, dock-autohide."* ]]
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
  [[ "$output" == *"omamac installed nothing you can remove."* ]]
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
    source '$REPO_ROOT/lib/core.sh'; source '$REPO_ROOT/lib/apps.sh'
    source '$REPO_ROOT/lib/settings.sh'; source '$REPO_ROOT/lib/dock.sh'
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
  grep -q '^killall Dock' "$STUB_LOG"
  [[ "$(cat "$(REC)")" == *AppleSpacesSwitchOnActivate* ]]
  [[ "$(cat "$(REC)")" == *ReduceMotionEnabled* ]]
  gum_answers yes
  run omamac_uninstall desktops
  [ "$status" -eq 0 ]
  grep -qx 'desktops=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
}

# colonized: what a colima run leaves: five formulas, both links, the service,
# a running colima, the marker, and the user's data.
colonized() {
  choose docker colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install colima docker docker-compose docker-buildx lazydocker
  mkdir -p "$HOME/.docker/cli-plugins" "$HOME/.colima/default" "$OMAMAC_TEST_BREW_PREFIX/services" "$(dirname "$MARKER")"
  for p in docker-compose docker-buildx; do
    ln -s "$OMAMAC_TEST_BREW_PREFIX/opt/$p/bin/$p" "$HOME/.docker/cli-plugins/$p"
  done
  : > "$OMAMAC_TEST_BREW_PREFIX/services/colima"
  : > "$OMAMAC_TEST_BREW_PREFIX/colima-running"
  : > "$HOME/.colima/default/x"
  : > "$MARKER"
  : > "$STUB_LOG"
}
MARKER_REL=.local/state/omamac/colima-service

@test "uninstall colima: not the answer exits 0" {
  gum_answers
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  [[ "$output" == *"colima isn't installed by omamac."* ]]
  [ -z "$(prompts)" ]
  ! grep -q '^brew ' "$STUB_LOG"
}

@test "uninstall colima: shows what goes and where data stays" {
  MARKER=$HOME/$MARKER_REL; colonized
  gum_answers no
  run omamac_uninstall colima
  [[ "$output" == *"colima: colima, docker, docker-compose, docker-buildx and lazydocker. Your images, containers and volumes stay in ~/.colima."* ]]
  grep -qx 'gum confirm --default=false Remove colima?' "$STUB_LOG"
}

@test "uninstall colima: no changes nothing" {
  MARKER=$HOME/$MARKER_REL; colonized
  gum_answers no
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing was removed."* ]]
  run ! grep -q '^brew ' "$STUB_LOG"
  grep -qx 'docker=colima' "$CHOICES_FILE"
}

@test "uninstall colima: removes in order, answer last" {
  MARKER=$HOME/$MARKER_REL; colonized
  gum_answers yes
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ colima is removed"* ]]
  [ "$(grep -E '^(brew (services stop|uninstall)|colima stop)' "$STUB_LOG")" = "brew services stop colima
colima stop
brew uninstall colima docker docker-compose docker-buildx lazydocker" ]
  [ ! -e "$HOME/.docker/cli-plugins" ]
  [ ! -e "$MARKER" ]
  grep -qx 'docker=none' "$CHOICES_FILE"
}

@test "uninstall colima: keeps a user's plugin and ~/.colima" {
  MARKER=$HOME/$MARKER_REL; colonized
  rm "$HOME/.docker/cli-plugins/docker-buildx"
  echo mine > "$HOME/.docker/cli-plugins/docker-buildx"
  gum_answers yes
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.docker/cli-plugins/docker-buildx")" = mine ]
  [ ! -e "$HOME/.docker/cli-plugins/docker-compose" ]
  [ -e "$HOME/.colima/default/x" ]
}

@test "uninstall colima: keeps a user's link that points at nothing" {
  MARKER=$HOME/$MARKER_REL; colonized
  rm "$HOME/.docker/cli-plugins/docker-buildx"
  ln -s /Applications/Docker.app/Contents/Resources/cli-plugins/docker-buildx "$HOME/.docker/cli-plugins/docker-buildx"
  gum_answers yes
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.docker/cli-plugins/docker-buildx")" = /Applications/Docker.app/Contents/Resources/cli-plugins/docker-buildx ]
}

@test "uninstall colima: a second run changes nothing" {
  MARKER=$HOME/$MARKER_REL; colonized
  gum_answers yes
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  : > "$STUB_LOG"
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  ! grep -q '^brew ' "$STUB_LOG"
}

@test "uninstall colima: a failed brew uninstall keeps the answer" {
  MARKER=$HOME/$MARKER_REL; colonized
  gum_answers yes
  T_BREW_UNINSTALL_FAIL=1 run omamac_uninstall colima
  [ "$status" -ne 0 ]
  grep -qx 'docker=colima' "$CHOICES_FILE"
}

@test "uninstall none and docker are refused" {
  gum_answers
  for name in none docker; do
    run --separate-stderr omamac_uninstall "$name"
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"can't remove"* ]]
  done
}

@test "uninstall with no name offers colima" {
  MARKER=$HOME/$MARKER_REL; colonized
  gum_answers none
  run omamac_uninstall
  [ "$status" -eq 0 ]
  [[ "$(prompts)" == *"Nothing:none colima:colima"* ]]
}

@test "uninstall colima: a retry with the colima formula gone still finishes" {
  MARKER=$HOME/$MARKER_REL; colonized
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Cellar/colima"
  gum_answers yes
  run omamac_uninstall colima
  [ "$status" -eq 0 ]
  run ! grep -qE '^(brew services|colima)' "$STUB_LOG"
  grep -qx 'brew uninstall docker docker-compose docker-buildx lazydocker' "$STUB_LOG"
  [ ! -e "$MARKER" ]
  grep -qx 'docker=none' "$CHOICES_FILE"
}

# dockered: what a Docker Desktop run leaves: the cask, its app and lazydocker.
dockered() {
  choose docker docker-desktop
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install lazydocker
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask docker-desktop
  : > "$STUB_LOG"
}
# deny_app_management: touch fails inside the app folder only; bats and git need the real touch.
deny_app_management() {
  stub touch 'case "$1" in *.omamac-write-test) echo "touch: $1: Operation not permitted" >&2; exit 1 ;; esac; exec /usr/bin/touch "$@"'
}
# no_brew_changes: the run made no brew change (reads are fine).
no_brew_changes() { run ! grep -qE '^brew (uninstall|install|reinstall)' "$STUB_LOG"; }

@test "uninstall docker-desktop: not the answer exits 0" {
  choose docker colima
  gum_answers
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker Desktop isn't installed by omamac."* ]]
  [ -z "$(prompts)" ]
  no_brew_changes
}

@test "uninstall docker-desktop: shows what goes, no changes nothing" {
  dockered
  gum_answers no no
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker Desktop: the app and lazydocker. Your images, containers and volumes stay."* ]]
  no_brew_changes
  grep -qx 'docker=docker-desktop' "$CHOICES_FILE"
}

@test "uninstall docker-desktop: removes in order, answer last" {
  dockered
  gum_answers no yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  [ "$(grep '^brew uninstall' "$STUB_LOG")" = "brew uninstall --cask docker-desktop
brew uninstall lazydocker" ]
  [[ "$output" == *"Docker Desktop: the app and lazydocker. Your images, containers and volumes stay."*"ℹ Homebrew may ask for your password."*"Removing Docker Desktop"* ]]
  [ ! -e "$OMAMAC_TEST_APPLICATIONS/Docker.app" ]
  grep -qx 'docker=none' "$CHOICES_FILE"
  run ! grep -q -- '--zap' "$STUB_LOG"
}

@test "uninstall docker-desktop: App Management off changes nothing" {
  dockered
  deny_app_management
  stub open
  gum_answers yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 1 ]
  [[ "$output" == *"App Management"* ]]
  [[ "$output" == *"then run omamac uninstall docker-desktop again."* ]]
  no_brew_changes
  grep -qx 'docker=docker-desktop' "$CHOICES_FILE"
}

@test "uninstall docker-desktop: a hand-installed app says it stays before the question" {
  dockered
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/docker-desktop"
  gum_answers no
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  # Answering no still shows the line, so it is printed before the answer is read.
  [[ "$output" == *"Docker Desktop wasn't installed by omamac, so it stays."* ]]
  [[ "$output" == *"Nothing was removed."* ]]
}

@test "uninstall docker-desktop: a hand-installed app stays" {
  dockered
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/docker-desktop"
  gum_answers yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker Desktop wasn't installed by omamac, so it stays."* ]]
  run ! grep -q '^brew uninstall --cask' "$STUB_LOG"
  grep -qx 'brew uninstall lazydocker' "$STUB_LOG"
  [ -e "$OMAMAC_TEST_APPLICATIONS/Docker.app" ]
  grep -qx 'docker=none' "$CHOICES_FILE"
}

@test "uninstall docker-desktop: app trashed, cask listed" {
  dockered
  rm -rf "$OMAMAC_TEST_APPLICATIONS/Docker.app"
  deny_app_management
  gum_answers no yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  grep -qx 'brew uninstall --cask docker-desktop' "$STUB_LOG"
  grep -qx 'docker=none' "$CHOICES_FILE"
}

@test "uninstall docker-desktop: a failed cask removal keeps the answer" {
  dockered
  export T_BREW_UNINSTALL_FAIL=1
  gum_answers no yes
  run omamac_uninstall docker-desktop
  [ "$status" -ne 0 ]
  run ! grep -qx 'brew uninstall lazydocker' "$STUB_LOG"
  grep -qx 'docker=docker-desktop' "$CHOICES_FILE"
}

@test "uninstall docker-desktop: a second run changes nothing" {
  dockered
  gum_answers no yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  : > "$STUB_LOG"
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  no_brew_changes
}

@test "uninstall docker-desktop: the user's own docker formula stays" {
  dockered
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install docker
  gum_answers no yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  run ! grep -qE '^brew uninstall docker( |$)' "$STUB_LOG"
  [ -e "$OMAMAC_TEST_BREW_PREFIX/Cellar/docker" ]
}

@test "uninstall with no name offers Docker Desktop" {
  dockered
  gum_answers none
  run omamac_uninstall
  [ "$status" -eq 0 ]
  [[ "$(prompts)" == *"Nothing:none Docker Desktop:docker-desktop"* ]]
}

@test "uninstall docker-desktop: yes to the data question zaps it" {
  dockered
  gum_answers yes yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  [ "$(grep -E '^(gum confirm|brew uninstall)' "$STUB_LOG")" = "gum confirm --default=false Also remove Docker Desktop's settings and data?
gum confirm --default=false Remove Docker Desktop?
brew uninstall --cask --zap docker-desktop
brew uninstall lazydocker" ]
  [[ "$output" == *"ℹ On yes, Homebrew also deletes Docker Desktop's images, containers and volumes, and ~/.docker (Docker's settings and saved logins)."* ]]
  [[ "$output" == *"Docker Desktop: the app and lazydocker, with Docker Desktop's images, containers, volumes and ~/.docker."* ]]
  [[ "$output" != *"Your images, containers and volumes stay."* ]]
  grep -qx 'docker=none' "$CHOICES_FILE"
}

@test "uninstall docker-desktop: the help line comes before the data question" {
  dockered
  gum_answers "exit 130"
  run omamac_uninstall docker-desktop
  [ "$status" -eq 130 ]
  [[ "$output" == *"On yes, Homebrew also deletes Docker Desktop's images"* ]]
  [[ "$output" != *"Docker Desktop: the app"* ]]
  no_brew_changes
}

@test "uninstall docker-desktop: a hand-installed app gets no data question" {
  dockered
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/docker-desktop"
  gum_answers yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum confirm --default=false Remove Docker Desktop?" ]
  [[ "$output" != *"On yes"* ]]
}

# app_run <key> <id> <cask>: what a run with that app picked left: the pick, the cask and its app.
app_run() {
  if [ "$1" = wispr_flow ]; then choose wispr_flow yes; else choose "$1" "$2"; fi
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask "$3"
  : > "$STUB_LOG"
}

@test "uninstall vlc: the order, and the data with it on yes" {
  app_run apps_media vlc vlc
  gum_answers yes yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  [ "$(grep -E '^(gum confirm|brew uninstall)' "$STUB_LOG")" = "gum confirm --default=false Also remove VLC's settings and data?
gum confirm --default=false Remove VLC?
brew uninstall --cask --zap vlc" ]
  [[ "$output" == *"ℹ On yes, Homebrew also deletes what VLC keeps in ~/Library."*"VLC: the app, with its settings and data."*"ℹ Homebrew may ask for your password."*"Removing VLC"*"✓ VLC is removed"* ]]
  # In the open, so Homebrew's password prompt shows.
  run ! grep -q '^gum spin.*vlc' "$STUB_LOG"
  [ ! -e "$OMAMAC_TEST_APPLICATIONS/VLC.app" ]
  [ ! -e "$OMAMAC_TEST_BREW_PREFIX/Caskroom/vlc" ]
  grep -qx 'apps_media=' "$CHOICES_FILE"
}

@test "uninstall vlc: the help line comes before the data question" {
  app_run apps_media vlc vlc
  gum_answers "exit 130"
  run omamac_uninstall vlc
  [ "$status" -eq 130 ]
  [[ "$output" == *"On yes, Homebrew also deletes what VLC keeps in ~/Library."* ]]
  [[ "$output" != *"VLC: the app"* ]]
  no_brew_changes
  grep -qx 'apps_media=vlc' "$CHOICES_FILE"
}

@test "uninstall vlc: Enter alone at the data question removes only the app" {
  app_run apps_media 'spotify vlc' vlc
  # fake-gum answers no as Enter would: the question defaults to no.
  gum_answers no yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  grep -qx "gum confirm --default=false Also remove VLC's settings and data?" "$STUB_LOG"
  [[ "$output" == *"VLC: the app."* ]]
  [[ "$output" != *"with its settings and data"* ]]
  [ "$(grep '^brew uninstall' "$STUB_LOG")" = "brew uninstall --cask vlc" ]
  [ ! -e "$OMAMAC_TEST_APPLICATIONS/VLC.app" ]
  grep -qx 'apps_media=spotify' "$CHOICES_FILE"
}

@test "uninstall vlc: no at Remove VLC? changes nothing" {
  app_run apps_media vlc vlc
  gum_answers yes no
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing was removed."* ]]
  no_brew_changes
  [ -e "$OMAMAC_TEST_APPLICATIONS/VLC.app" ]
  grep -qx 'apps_media=vlc' "$CHOICES_FILE"
}

@test "uninstall vlc: not picked exits 0 with no brew call" {
  gum_answers
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  [[ "$output" == *"VLC isn't installed by omamac."* ]]
  [ -z "$(prompts)" ]
  run ! grep -q '^brew ' "$STUB_LOG"
}

@test "uninstall vlc: installed by hand, only the pick goes" {
  choose apps_media vlc
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  gum_answers yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  [[ "$output" == *"VLC: installed by hand, so the app stays. omamac only forgets your pick."* ]]
  [ "$(prompts)" = "gum confirm --default=false Remove VLC?" ]
  [[ "$output" == *"✓ VLC is removed from your answers"* ]]
  [ -n "$(ls "$HOME/.local/state/omamac/logs")" ]
  no_brew_changes
  [ -e "$OMAMAC_TEST_APPLICATIONS/VLC.app" ]
  grep -qx 'apps_media=' "$CHOICES_FILE"
}

@test "uninstall vlc: removed with brew by hand, no brew call, pick dropped" {
  choose apps_media vlc
  gum_answers yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  # Homebrew doesn't list it, so there is no data for it to delete.
  [ "$(prompts)" = "gum confirm --default=false Remove VLC?" ]
  [[ "$output" == *"VLC: the app."* ]]
  [[ "$output" == *"✓ VLC is removed"* ]]
  no_brew_changes
  grep -qx 'apps_media=' "$CHOICES_FILE"
}

@test "uninstall vlc: app trashed, cask listed" {
  app_run apps_media vlc vlc
  rm -rf "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  deny_app_management
  gum_answers no yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  grep -qx 'brew uninstall --cask vlc' "$STUB_LOG"
  grep -qx 'apps_media=' "$CHOICES_FILE"
}

@test "uninstall vlc: App Management off asks nothing and keeps the pick" {
  app_run apps_media vlc vlc
  deny_app_management
  stub open
  gum_answers yes yes
  run omamac_uninstall vlc
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ macOS won't let your terminal change apps, so nothing was removed."* ]]
  [[ "$output" == *"App Management, turn on your terminal, then run omamac uninstall vlc again."* ]]
  grep -q '^open x-apple.systempreferences:' "$STUB_LOG"
  [ -z "$(prompts)" ]
  no_brew_changes
  grep -qx 'apps_media=vlc' "$CHOICES_FILE"
}

@test "uninstall zoom: a root-owned app isn't write-tested; the data question comes first" {
  app_run apps_communication zoom zoom
  # Zoom's installer package leaves the app owned by root.
  stub touch 'case "$1" in *.omamac-write-test) echo "touch: $1: Permission denied" >&2; exit 1 ;; esac; exec /usr/bin/touch "$@"'
  gum_answers no yes
  run omamac_uninstall zoom
  [ "$status" -eq 0 ]
  run ! grep -q 'omamac-write-test' "$STUB_LOG"
  [ "$(prompts | head -1)" = "gum confirm --default=false Also remove Zoom's settings and data?" ]
  grep -qx 'brew uninstall --cask zoom' "$STUB_LOG"
  grep -qx 'apps_communication=' "$CHOICES_FILE"
}

@test "uninstall vlc: a failed brew uninstall keeps the pick" {
  app_run apps_media vlc vlc
  gum_answers no yes
  T_BREW_UNINSTALL_FAIL=1 run omamac_uninstall vlc
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while removing VLC."* ]]
  grep -qx 'apps_media=vlc' "$CHOICES_FILE"
}

@test "uninstall vlc: a second run calls no brew" {
  app_run apps_media vlc vlc
  gum_answers yes yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  : > "$STUB_LOG"
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  [[ "$output" == *"VLC isn't installed by omamac."* ]]
  run ! grep -q '^brew ' "$STUB_LOG"
}

@test "uninstall wispr-flow saves wispr_flow=no" {
  app_run wispr_flow wispr-flow wispr-flow
  gum_answers no yes
  run omamac_uninstall wispr-flow
  [ "$status" -eq 0 ]
  grep -qx 'gum confirm --default=false Remove Wispr Flow?' "$STUB_LOG"
  grep -qx 'brew uninstall --cask wispr-flow' "$STUB_LOG"
  [ ! -e "$OMAMAC_TEST_APPLICATIONS/Wispr Flow.app" ]
  grep -qx 'wispr_flow=no' "$CHOICES_FILE"
}

@test "uninstall: a wrong app name lists the app ids" {
  gum_answers
  for name in "VS Code" apps_media wispr_flow; do
    run --separate-stderr omamac_uninstall "$name"
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"omamac can't remove '$name'. It can remove: "*", vscode, "*", wispr-flow, "* ]]
  done
  [ -z "$(prompts)" ]
}

@test "no name: the chosen apps come after the settings" {
  choose window_margins yes
  choose apps_media vlc
  choose wispr_flow yes
  choose docker docker-desktop
  gum_answers none
  run omamac_uninstall
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum choose --header What should omamac remove? --label-delimiter=: Nothing:none Window margins:window-margins VLC:vlc Wispr Flow:wispr-flow Docker Desktop:docker-desktop" ]
}

@test "no name: a picked app is removed" {
  app_run apps_developer vscode visual-studio-code
  gum_answers vscode no yes
  run omamac_uninstall
  [ "$status" -eq 0 ]
  grep -qx 'brew uninstall --cask visual-studio-code' "$STUB_LOG"
  grep -qx 'apps_developer=' "$CHOICES_FILE"
}

# dock_on [<code>]: what a first run with dock=yes left. The code sets more answers.
dock_on() {
  "$BASH5" -c "
    set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    for f in paths ui questions choices core apps settings dock; do source '$REPO_ROOT/lib/'\$f.sh; done
    CHOICES[dock]=yes; ${1:-:}; settings_apply" > /dev/null
  choose dock yes
  : > "$STUB_LOG"
}

# app_url <app>: its URL in the fake Applications.
app_url() { echo "file://${OMAMAC_TEST_APPLICATIONS// /%20}/$1/"; }

DOCK_RECORD_REL=.local/state/omamac/dock-before.plist

@test "uninstall dock puts the Dock back and show-recents" {
  dock_seed file:///System/Applications/Mail.app/ file:///Applications/Things.app/ \
    -- "file://$HOME/Downloads/"
  apps=$(dock_urls persistent-apps)
  others=$(dock_urls persistent-others)
  dock_on
  [ "$(defaults read com.apple.dock show-recents)" = 0 ]
  gum_answers yes
  run omamac_uninstall dock
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock cleanup: your Dock goes back to how it was before omamac cleaned it. Changes you made to it since are undone."* ]]
  grep -qx 'gum confirm --default=false Remove Dock cleanup?' "$STUB_LOG"
  [[ "$output" == *"✓ Dock cleanup is removed"* ]]
  [ "$(dock_urls persistent-apps)" = "$apps" ]
  [ "$(dock_urls persistent-others)" = "$others" ]
  run defaults read com.apple.dock show-recents
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/$DOCK_RECORD_REL" ]
  grep -qx 'dock=no' "$CHOICES_FILE"
}

@test "uninstall dock: no changes nothing" {
  dock_seed file:///System/Applications/Mail.app/
  dock_on
  cp "$T_DEFAULTS_DIR/com.apple.dock.plist" "$BATS_TEST_TMPDIR/after.plist"
  gum_answers no
  run omamac_uninstall dock
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing was removed."* ]]
  cmp "$T_DEFAULTS_DIR/com.apple.dock.plist" "$BATS_TEST_TMPDIR/after.plist"
  [ "$(defaults read com.apple.dock show-recents)" = 0 ]
  [ -f "$HOME/$DOCK_RECORD_REL" ]
  grep -qx 'dock=yes' "$CHOICES_FILE"
}

@test "uninstall dock with no record puts show-recents back only" {
  dock_on
  rm "$HOME/$DOCK_RECORD_REL"
  gum_answers yes
  run omamac_uninstall dock
  [ "$status" -eq 0 ]
  run ! grep -q '^defaults import' "$STUB_LOG"
  run defaults read com.apple.dock show-recents
  [ "$status" -ne 0 ]
  grep -qx 'dock=no' "$CHOICES_FILE"
}

@test "uninstall dock: not set by omamac" {
  gum_answers
  run omamac_uninstall dock
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock cleanup isn't set by omamac."* ]]
  [ -z "$(prompts)" ]
}

@test "uninstall dock-autohide maps the name" {
  choose dock_autohide yes
  defaults write com.apple.dock autohide -bool true
  mkdir -p "$(dirname "$(REC)")"
  printf 'com.apple.dock\tautohide\tabsent\n' > "$(REC)"
  gum_answers yes
  run omamac_uninstall dock-autohide
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock auto-hide: your earlier Dock auto-hide setting"* ]]
  grep -qx 'gum confirm --default=false Remove Dock auto-hide?' "$STUB_LOG"
  run defaults read com.apple.dock autohide
  [ "$status" -ne 0 ]
  grep -qx 'dock_autohide=no' "$CHOICES_FILE"
}

@test "uninstall vlc with dock=yes takes its tile out" {
  app_run apps_media vlc vlc
  dock_on 'CHOICES[apps_media]=vlc'
  [[ "$(dock_urls persistent-apps)" == *"$(app_url VLC.app)"* ]]
  gum_answers no yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  [[ "$(dock_urls persistent-apps)" != *VLC* ]]
  [ "$(cat "$HOME/.local/state/omamac/dock-added")" = Ghostty.app ]
}

@test "uninstall vlc installed by hand keeps its tile" {
  choose apps_media vlc
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  dock_on 'CHOICES[apps_media]=vlc'
  gum_answers yes
  run omamac_uninstall vlc
  [ "$status" -eq 0 ]
  [[ "$(dock_urls persistent-apps)" == *"$(app_url VLC.app)"* ]]
  run ! grep -q '^defaults import' "$STUB_LOG"
}

@test "uninstall docker-desktop with dock=yes takes its tile out" {
  dockered
  dock_on 'CHOICES[docker]=docker-desktop'
  [[ "$(dock_urls persistent-apps)" == *"$(app_url Docker.app)"* ]]
  gum_answers no yes
  run omamac_uninstall docker-desktop
  [ "$status" -eq 0 ]
  [[ "$(dock_urls persistent-apps)" != *Docker* ]]
  grep -qx 'docker=none' "$CHOICES_FILE"
}

@test "no name: the menu offers both Dock answers" {
  choose dock yes
  choose dock_autohide yes
  gum_answers none
  run omamac_uninstall
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum choose --header What should omamac remove? --label-delimiter=: Nothing:none Dock cleanup:dock Dock auto-hide:dock-autohide" ]
}

@test "every name omamac uninstall takes is one thing only" {
  run "$BASH5" -c "source '$REPO_ROOT/lib/questions.sh'
    for k in \"\${QUESTION_KEYS[@]}\"; do
      case \${QUESTION_KIND[\$k]} in multi) question_values \"\$k\" ;; esac
    done
    echo wispr-flow desktops window-margins colima docker-desktop dock dock-autohide | tr ' ' '\n'"
  [ "$status" -eq 0 ]
  [ -z "$(sort <<< "$output" | uniq -d)" ]
}

@test "antigravity-cli: brew uninstall --cask antigravity-cli, the Antigravity app stays" {
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask antigravity-cli antigravity
  choose coding_agents 'antigravity-cli opencode'
  choose apps_ai antigravity
  : > "$STUB_LOG"
  gum_answers yes
  run omamac_uninstall antigravity-cli
  [ "$status" -eq 0 ]
  [[ "$output" == *"Antigravity CLI: the antigravity-cli cask"* ]]
  [ "$(grep '^brew uninstall' "$STUB_LOG")" = "brew uninstall --cask antigravity-cli" ]
  [ -e "$OMAMAC_TEST_BREW_PREFIX/Caskroom/antigravity" ]
  grep -qx 'coding_agents=opencode' "$CHOICES_FILE"
  grep -qx 'apps_ai=antigravity' "$CHOICES_FILE"
}

@test "opencode: brew uninstall opencode" {
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install opencode
  choose coding_agents opencode
  : > "$STUB_LOG"
  gum_answers yes
  run omamac_uninstall opencode
  [ "$status" -eq 0 ]
  [ "$(grep '^brew uninstall' "$STUB_LOG")" = "brew uninstall opencode" ]
  grep -qx 'coding_agents=' "$CHOICES_FILE"
}
