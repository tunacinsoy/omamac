load helpers/common

bats_require_minimum_version 1.5.0

# The formulas a finished first run has: the core, then bash, gum and lazydocker.
OMAMAC_FORMULAS='starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq bash gum lazydocker'

setup() {
  setup_sandbox
  install_fake_brew
  export TMPDIR="$BATS_TEST_TMPDIR"
  # shellcheck disable=SC2086 # one formula per word
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install $OMAMAC_FORMULAS
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask ghostty docker-desktop
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  # Answered yes, so install doesn't ask about them (tests below ask on purpose).
  # Docker Desktop is already installed, so its step does nothing.
  sed -i '' -e 's/^desktops=.*/desktops=yes/' -e 's/^window_margins=.*/window_margins=yes/' -e 's/^docker=.*/docker=docker-desktop/' "$CHOICES_FILE"
  # Only the run's own calls.
  : > "$STUB_LOG"
}

# omamac_install: omamac install, only ever in the sandbox, never on the real Mac.
# bin/omamac runs from the checkout it lives in, here the repo; install doesn't pull.
omamac_install() {
  if [ -z "${BATS_TEST_TMPDIR:-}" ] || [[ $HOME != "$BATS_TEST_TMPDIR"/* ]]; then
    echo "add.bats: HOME isn't the sandbox; not running omamac install" >&2
    return 1
  fi
  "$BASH5" "$REPO_ROOT/bin/omamac" install "$@"
}

# choose <key> <value>: set one saved answer.
choose() { sed -i '' "s/^$1=.*/$1=$2/" "$CHOICES_FILE"; }

prompts() { grep -E '^gum (choose|confirm)' "$STUB_LOG" || true; }

# The choices file's checksum and mtime.
choices_stamp() { echo "$(shasum < "$CHOICES_FILE") $(stat -f %m "$CHOICES_FILE")"; }

@test "offers only unpicked options" {
  choose languages node
  gum_answers "" ""
  run omamac_install
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 2 ]
  [[ "$(prompts | sed -n 1p)" == *"--label-delimiter=: Ruby on Rails:ruby Go:go Python:python Elixir:elixir Rust:rust Java:java" ]]
  [[ "$(prompts | sed -n 1p)" != *Node.js* ]]
  [[ "$(prompts | sed -n 2p)" == *"Azure CLI:azure AWS CLI:aws Google Cloud CLI:gcloud GitHub CLI:gh Terraform:terraform" ]]
}

@test "nothing left: says so, asks nothing" {
  choose languages 'ruby node go python elixir rust java'
  choose cloud_clis 'azure aws gcloud gh terraform'
  before=$(choices_stamp)
  gum_answers
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"You've picked everything omamac offers here."* ]]
  [ -z "$(prompts)" ]
  [ "$(choices_stamp)" = "$before" ]
  run ! grep -qE '^(brew|mise) install' "$STUB_LOG"
}

@test "a question with nothing left is skipped" {
  choose languages 'ruby node go python elixir rust java'
  gum_answers ""
  run omamac_install
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 1 ]
  [[ "$(prompts)" == *"Cloud command-line tools"* ]]
}

@test "nothing picked: nothing saved, no Install?" {
  before=$(choices_stamp)
  gum_answers "" ""
  sleep 1.1
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing picked, so nothing changed."* ]]
  run ! grep -q '^gum confirm' "$STUB_LOG"
  [ "$(choices_stamp)" = "$before" ]
  [ ! -e "$HOME/.config/omamac" ]
}

@test "no at Install?: choices.env unchanged, no mise or brew install" {
  before=$(choices_stamp)
  gum_answers go "" no
  sleep 1.1
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Languages: Go"* ]]
  [[ "$output" != *"Cloud CLIs:"* ]]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
  grep -qx 'gum confirm --default=false Install?' "$STUB_LOG"
  [ "$(choices_stamp)" = "$before" ]
  run ! grep -qE '^(brew|mise) install' "$STUB_LOG"
  [ ! -e "$HOME/.config/omamac" ]
}

@test "yes: saves the merged answers and installs only the additions" {
  choose languages node
  choose cloud_clis gh
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gh
  (cd "$HOME" && "$OMAMAC_TEST_BREW_PREFIX/bin/mise" install node)
  : > "$STUB_LOG"
  gum_answers "rust go" aws yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Languages: Go, Rust"* ]]
  [[ "$output" == *"Cloud CLIs: AWS CLI"* ]]
  grep -qx 'languages=node go rust' "$CHOICES_FILE"
  grep -qx 'cloud_clis=aws gh' "$CHOICES_FILE"
  [ "$(grep '^mise install' "$STUB_LOG")" = "mise install go rust" ]
  [ "$(grep '^brew install' "$STUB_LOG")" = "brew install awscli" ]
  grep -qx 'go = "latest"' "$HOME/.config/mise/conf.d/omamac.toml"
  logs=("$HOME"/.local/state/omamac/logs/*.log)
  [ "${#logs[@]}" -eq 1 ]
  [[ "$output" == *"Installed: Go, Rust, AWS CLI"* ]]
  [[ "$output" == *"Log: ${logs[0]}"* ]]
  [[ "$output" == *"Open a new terminal window to use them."* ]]
}

@test "Ctrl-C at a question: exit 130, nothing saved" {
  before=$(choices_stamp)
  gum_answers "exit 130"
  run omamac_install
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
  [ "$(choices_stamp)" = "$before" ]
  [ ! -e "$HOME/.config/omamac" ]
}

@test "no choices file: stops with the fix" {
  rm "$CHOICES_FILE"
  gum_answers "" ""
  run omamac_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ omamac doesn't know your answers. Fix: run the one-liner."* ]]
  [ -z "$(prompts)" ]
  [ ! -e "$CHOICES_FILE" ]
}

@test "a bad choices file: stops, naming the line" {
  echo 'colour=red' >> "$CHOICES_FILE"
  gum_answers "" ""
  run omamac_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"line 18: omamac has no question 'colour'"* ]]
  [ -z "$(prompts)" ]
}

@test "a failing step names itself and says to run omamac update" {
  gum_answers go "" yes
  T_MISE_FAIL=1 run omamac_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while installing your languages."* ]]
  [[ "$output" == *"Fix the problem and run omamac update."* ]]
}

@test "extra arguments: usage, exit 2" {
  gum_answers "" ""
  run --separate-stderr omamac_install go
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Usage: omamac <command>"* ]]
  [ -z "$(prompts)" ]
}

@test "desktops no: asked again; yes applies" {
  choose desktops no
  gum_answers "" "" yes yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktops as workspaces"* ]]
  grep -qx 'desktops=yes' "$CHOICES_FILE"
  [ "$(defaults read com.apple.dock mru-spaces)" = 0 ]
  [ "$(defaults read NSGlobalDomain AppleSpacesSwitchOnActivate)" = 1 ]
}

@test "desktops yes: not asked" {
  gum_answers "" ""
  run omamac_install
  [[ "$(prompts)" != *"desktops"* ]]
  [ "$(prompts | wc -l | tr -d ' ')" = 2 ]
}

@test "answer no again: nothing changes" {
  choose desktops no
  before=$(choices_stamp)
  gum_answers "" "" no
  sleep 1.1
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing picked, so nothing changed."* ]]
  grep -qx 'desktops=no' "$CHOICES_FILE"
  [ "$(choices_stamp)" = "$before" ]
  run ! grep -q '^defaults write' "$STUB_LOG"
}

@test "install asks Docker only when the answer is none" {
  choose docker colima
  gum_answers "" ""
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$(prompts)" != *"How should Docker run?"* ]]
  [ "$(prompts | wc -l | tr -d ' ')" = 2 ]
}

@test "install: Enter on Docker picks No Docker, nothing changes" {
  choose docker none
  before=$(choices_stamp)
  gum_answers "" "" none
  sleep 1.1
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing picked, so nothing changed."* ]]
  grep -qx 'docker=none' "$CHOICES_FILE"
  [ "$(choices_stamp)" = "$before" ]
}

@test "install: picking colima replaces none and installs it" {
  choose docker none
  gum_answers "" "" colima yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$(prompts)" == *"How should Docker run?"* ]]
  [[ "$output" == *"Docker: colima"* ]]
  [[ "$output" == *"colima starts Docker in the background now and at each login."* ]]
  [[ "$output" == *"The first start downloads Linux and takes a few minutes."* ]]
  grep -qx 'docker=colima' "$CHOICES_FILE"
  grep -q '^brew install colima ' "$STUB_LOG"
}

@test "install: Docker Desktop is named as installed" {
  choose docker none
  gum_answers go "" docker-desktop yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker: Docker Desktop"* ]]
  [[ "$output" == *"Installed: Go, Docker Desktop"* ]]
  grep -qx 'docker=docker-desktop' "$CHOICES_FILE"
}
