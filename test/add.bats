load helpers/common

load helpers/dock
bats_require_minimum_version 1.5.0

# The formulas a finished first run has: the core, then bash, gum and lazydocker.
OMAMAC_FORMULAS='starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq bash gum lazydocker'

ALL_BROWSERS='brave chrome firefox'
ALL_COMMUNICATION='whatsapp telegram signal discord slack zoom'
ALL_CASKS='brave-browser google-chrome firefox whatsapp telegram signal discord slack zoom spotify vlc cap dropbox google-drive visual-studio-code claude chatgpt github-copilot-app antigravity raycast obsidian wispr-flow'
ALL_AGENTS='claude-code codex copilot-cli antigravity-cli opencode'

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
  sed -i '' -e 's/^dock=.*/dock=yes/' -e 's/^dock_autohide=.*/dock_autohide=yes/' -e 's/^desktops=.*/desktops=yes/' -e 's/^window_margins=.*/window_margins=yes/' -e 's/^docker=.*/docker=docker-desktop/' "$CHOICES_FILE"
  # Every app picked and installed, so install doesn't ask about them either.
  sed -i '' -e "s/^apps_browsers=.*/apps_browsers=$ALL_BROWSERS/" -e "s/^apps_communication=.*/apps_communication=$ALL_COMMUNICATION/" \
    -e 's/^apps_media=.*/apps_media=spotify vlc/' -e 's/^apps_screen_recording=.*/apps_screen_recording=cap/' \
    -e 's/^apps_storage=.*/apps_storage=dropbox google-drive/' -e 's/^apps_developer=.*/apps_developer=vscode/' \
    -e 's/^apps_ai=.*/apps_ai=claude chatgpt copilot antigravity/' \
    -e 's/^apps_productivity=.*/apps_productivity=raycast obsidian/' -e 's/^wispr_flow=.*/wispr_flow=yes/' "$CHOICES_FILE"
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask $ALL_CASKS
  # Every coding agent picked and installed too: the tests below ask about languages and cloud CLIs.
  choose coding_agents "$ALL_AGENTS"
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install opencode
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask claude-code codex copilot-cli antigravity-cli
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

@test "install offers the unpicked coding agents after the cloud CLIs" {
  choose languages 'ruby node go python elixir rust java'
  choose coding_agents 'claude-code codex'
  gum_answers "" opencode yes
  run omamac_install
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 3 ]
  [[ "$(prompts | sed -n 1p)" == *"Terraform:terraform" ]]
  [[ "$(prompts | sed -n 2p)" == *"--label-delimiter=: Copilot CLI:copilot-cli Antigravity CLI:antigravity-cli opencode CLI:opencode" ]]
  grep -qx 'coding_agents=claude-code codex opencode' "$CHOICES_FILE"
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
  [[ "$output" == *"line 20: omamac has no question 'colour'"* ]]
  [ -z "$(prompts)" ]
}

@test "a failing step names itself and says to run omamac update" {
  gum_answers go "" yes
  T_MISE_FAIL=1 run omamac_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while installing your languages."* ]]
  [[ "$output" == *"Fix the problem and run omamac update."* ]]
}

@test "a failure before the answers are saved says to run omamac install again" {
  # The adoption check lists casks as soon as VLC is picked.
  choose apps_media ""
  gum_answers vlc
  T_BREW_LIST_FAIL=1 run omamac_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"Fix the problem and run omamac install again."* ]]
  [[ "$output" != *"omamac update"* ]]
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

@test "install: the app groups and Wispr Flow come first, with only the unpicked apps" {
  choose apps_media spotify
  choose wispr_flow no
  gum_answers "" no "" ""
  run omamac_install
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 4 ]
  [ "$(prompts | sed -n 1p)" = "gum choose --no-limit --header Media --label-delimiter=: VLC:vlc" ]
  [ "$(prompts | sed -n 2p)" = "gum confirm --default=false Install Wispr Flow for voice dictation?" ]
  [[ "$(prompts | sed -n 3p)" == *"Programming languages"* ]]
}

@test "install: a picked app is installed after Install?" {
  choose apps_media spotify
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/vlc" "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  gum_answers vlc "" "" yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Media: VLC"* ]]
  grep -qx 'apps_media=spotify vlc' "$CHOICES_FILE"
  [ "$(grep -E '^brew (install|reinstall)' "$STUB_LOG")" = "brew install --cask vlc" ]
  # Install? first, then the cask.
  [ "$(grep -nx 'gum confirm --default=false Install?' "$STUB_LOG" | cut -d: -f1)" -lt "$(grep -nx 'brew install --cask vlc' "$STUB_LOG" | cut -d: -f1)" ]
  [[ "$output" == *"Installed: VLC"* ]]
  [[ "$output" == *"The first time you open each app, macOS asks you to confirm; click Open."* ]]
}

@test "install: Zoom's password step is named before Install?" {
  choose apps_communication 'whatsapp telegram signal discord slack'
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/zoom" "$OMAMAC_TEST_APPLICATIONS/zoom.us.app"
  gum_answers zoom "" "" no
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Communication: Zoom"* ]]
  [[ "$output" == *"ℹ Homebrew asks for your password once more, after you confirm, for: Zoom."* ]]
  [[ "$output" != *"Install?"* ]]
  run ! grep -q '^brew install' "$STUB_LOG"
}

@test "install: a picked app's allow line is in the box" {
  choose apps_screen_recording ''
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/cap" "$OMAMAC_TEST_APPLICATIONS/Cap.app"
  gum_answers cap "" "" yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed: Cap"$'\n'*"Cap: allow Screen Recording, and Camera and Microphone if you use them."* ]]
}

# Adoption: an app picked here that is already in Applications, not from Homebrew.
by_hand() { # <cask> <App.app>
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/$1" "$OMAMAC_TEST_APPLICATIONS/$2"
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/$2"
  echo mine > "$OMAMAC_TEST_APPLICATIONS/$2/marker"
}

@test "install adopt: VLC by hand, yes: the box names VLC and brew adopts it" {
  choose apps_media spotify
  by_hand vlc VLC.app
  gum_answers vlc yes "" "" yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Homebrew can take it over"*"Media: VLC"* ]]
  grep -qx 'apps_media=spotify vlc' "$CHOICES_FILE"
  grep -qx 'brew install --cask --adopt vlc' "$STUB_LOG"
  [ "$(cat "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker")" = mine ]
}

@test "install adopt: VLC by hand, no, and VS Code picked: the box names only VS Code" {
  choose apps_media spotify
  choose apps_developer ''
  by_hand vlc VLC.app
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/visual-studio-code" "$OMAMAC_TEST_APPLICATIONS/Visual Studio Code.app"
  gum_answers vlc no vscode "" "" yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Developer: VS Code"* ]]
  [[ "$output" != *"Media: VLC"* ]]
  grep -qx 'apps_media=spotify' "$CHOICES_FILE"
  run ! grep -qE '^brew .*vlc' "$STUB_LOG"
  grep -qx 'brew install --cask visual-studio-code' "$STUB_LOG"
}

@test "install adopt: VLC by hand, yes, the adopt fails: exit 1, the pick is kept" {
  choose apps_media spotify
  by_hand vlc VLC.app
  gum_answers vlc yes "" "" yes
  T_BREW_FAIL_CASK=vlc run omamac_install
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while handing VLC to Homebrew."* ]]
  grep -qx 'apps_media=spotify vlc' "$CHOICES_FILE"
  [ "$(cat "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker")" = mine ]
}

@test "install adopt: Wispr Flow by hand, yes: brew adopts it and wispr_flow is yes" {
  choose wispr_flow no
  by_hand wispr-flow "Wispr Flow.app"
  gum_answers yes yes "" "" yes
  run omamac_install
  [ "$status" -eq 0 ]
  grep -qx 'brew install --cask --adopt wispr-flow' "$STUB_LOG"
  grep -qx 'wispr_flow=yes' "$CHOICES_FILE"
}

@test "install adopt: every pick answered no: nothing changed, exit 0" {
  choose apps_media spotify
  by_hand vlc VLC.app
  before=$(choices_stamp)
  gum_answers vlc no "" ""
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing picked, so nothing changed."* ]]
  [ "$(choices_stamp)" = "$before" ]
  [ -z "$(grep -E '^brew (install|reinstall)' "$STUB_LOG")" ]
}

@test "install adopt: Wispr Flow by hand, no: wispr_flow stays no" {
  choose wispr_flow no
  by_hand wispr-flow "Wispr Flow.app"
  gum_answers yes no "" ""
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing picked, so nothing changed."* ]]
  grep -qx 'wispr_flow=no' "$CHOICES_FILE"
}

@test "install adopt: a not-installed app is asked nothing" {
  choose apps_media ''
  rm -rf "$OMAMAC_TEST_BREW_PREFIX/Caskroom/vlc" "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  gum_answers "spotify vlc" "" "" yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Let Homebrew take over"* ]]
  [ -z "$(prompts | grep 'Let Homebrew take over')" ]
}

@test "install adopt: an app already from Homebrew is asked nothing" {
  choose apps_media spotify
  gum_answers vlc "" "" yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Let Homebrew take over"* ]]
  [ -z "$(prompts | grep 'Let Homebrew take over')" ]
}

@test "dock no: asked again; yes cleans the Dock" {
  choose dock no
  dock_seed "file:///System/Applications/Mail.app/" "file:///Applications/Foo.app/"
  gum_answers "" "" yes yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock cleanup"* ]]
  grep -qx 'dock=yes' "$CHOICES_FILE"
  grep -q '^defaults export com.apple.dock' "$STUB_LOG"
  grep -q '^defaults import com.apple.dock' "$STUB_LOG"
}

@test "dock yes: not asked" {
  gum_answers "" ""
  run omamac_install
  [[ "$(prompts)" != *"Clean up the Dock?"* ]]
  [ "$(prompts | wc -l | tr -d ' ')" = 2 ]
}

@test "dock auto-hide no: asked again; yes applies" {
  choose dock_autohide no
  gum_answers "" "" yes yes
  run omamac_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock auto-hide"* ]]
  grep -qx 'dock_autohide=yes' "$CHOICES_FILE"
  [ "$(defaults read com.apple.dock autohide)" = 1 ]
}

@test "dock auto-hide yes: not asked" {
  gum_answers "" ""
  run omamac_install
  [[ "$(prompts)" != *"Hide the Dock"* ]]
}

@test "install languages: asks only that section, only the unpicked" {
  choose languages node
  gum_answers go yes
  run omamac_install languages
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 2 ]
  [[ "$(prompts | sed -n 1p)" == *"--label-delimiter=: Ruby on Rails:ruby Go:go Python:python Elixir:elixir Rust:rust Java:java" ]]
  [[ "$(prompts | sed -n 2p)" == "gum confirm --default=false Install?" ]]
  grep -qx 'languages=node go' "$CHOICES_FILE"
}

@test "install go rust: no questions but Install?, then both are installed" {
  gum_answers yes
  run omamac_install go rust
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum confirm --default=false Install?" ]
  [[ "$output" == *"Languages: Go, Rust"* ]]
  grep -qx 'languages=go rust' "$CHOICES_FILE"
  grep -qx 'go = "latest"' "$HOME/.config/mise/conf.d/omamac.toml"
  grep -qx 'rust = "latest"' "$HOME/.config/mise/conf.d/omamac.toml"
}

@test "install an id already picked: says so, asks nothing, changes nothing" {
  choose languages go
  before=$(choices_stamp)
  gum_answers
  run omamac_install go
  [ "$status" -eq 0 ]
  [[ "$output" == *"Go is already installed."* ]]
  [[ "$output" == *"Nothing picked, so nothing changed."* ]]
  [ -z "$(prompts)" ]
  [ "$(choices_stamp)" = "$before" ]
}

@test "install an unknown name: names the sections, asks nothing, changes nothing" {
  before=$(choices_stamp)
  gum_answers
  run omamac_install go nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"omamac doesn't know 'nope'. Name a section (apps, languages, cloud-clis, coding-agents, docker, macos) or what to install, such as go, docker-desktop, vscode."* ]]
  [ -z "$(prompts)" ]
  [ "$(choices_stamp)" = "$before" ]
}

@test "install colima with Docker Desktop picked: says to uninstall it first" {
  before=$(choices_stamp)
  gum_answers
  run omamac_install colima
  [ "$status" -eq 2 ]
  [[ "$output" == *"Docker is already Docker Desktop. To switch, uninstall it first: omamac uninstall docker-desktop."* ]]
  [ "$(choices_stamp)" = "$before" ]
}

@test "install colima with no Docker: picked" {
  choose docker none
  gum_answers yes
  run omamac_install colima
  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker: colima"* ]]
  grep -qx 'docker=colima' "$CHOICES_FILE"
}

@test "install dock-autohide: a macOS setting by its uninstall name" {
  choose dock_autohide no
  gum_answers yes
  run omamac_install dock-autohide
  [ "$status" -eq 0 ]
  grep -qx 'dock_autohide=yes' "$CHOICES_FILE"
}

@test "install a section and an id together: one question, one Install?" {
  gum_answers aws yes
  run omamac_install cloud-clis go
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 2 ]
  [[ "$(prompts | sed -n 1p)" == *"Cloud command-line tools"* ]]
  grep -qx 'cloud_clis=aws' "$CHOICES_FILE"
  grep -qx 'languages=go' "$CHOICES_FILE"
}

@test "install vlc installed by hand: Homebrew is offered to take it over" {
  choose apps_media spotify
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/vlc"
  gum_answers yes yes
  run omamac_install vlc
  [ "$status" -eq 0 ]
  grep -q '^gum confirm .*Let Homebrew take over VLC?' "$STUB_LOG"
  grep -qx 'apps_media=spotify vlc' "$CHOICES_FILE"
  grep -q '^brew install --cask --adopt .*vlc' "$STUB_LOG"
}

@test "no section name is also a name to install" {
  run "$BASH5" -c "OMAMAC_CHECKOUT='$REPO_ROOT'
    for lib in paths ui questions choices log core apps clis ask add; do source '$REPO_ROOT/lib/'\$lib.sh; done
    for s in \"\${ADD_SECTIONS[@]}\"; do add_section \"\$s\" >/dev/null || echo \"not a section: \$s\"; ! add_id_key \"\$s\" || echo \"also a name: \$s\"; done"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
