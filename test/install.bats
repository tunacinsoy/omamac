load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/run.log"
  # Most tests are a run with saved answers, as the VM's fixture gives:
  # no questions, then "Install?" answered yes (twice, for tests that re-run).
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  gum_answers yes yes
}

# A Mac where nothing was answered yet.
fresh_answers() {
  rm -f "$CHOICES_FILE"
  gum_answers "${FRESH_ANSWERS[@]}" "$@"
}

prompts() { grep -E '^gum (choose|confirm)' "$STUB_LOG" || true; }

install() { "$BASH5" "$REPO_ROOT/install.sh"; }

# Every file under HOME with its checksum and mtime, except the logs.
snapshot() {
  (cd "$HOME" && find . -type f -not -path './.local/state/omamac/logs/*' | sort |
    while read -r f; do echo "$f $(shasum < "$f") $(stat -f %m "$f")"; done)
}

@test "stops under bash 3.2" {
  run /bin/bash "$REPO_ROOT/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs bash 5"* ]]
}

@test "fresh Mac: writes the zsh file and both lines" {
  run install
  [ "$status" -eq 0 ]
  cmp "$HOME/.config/omamac/zshrc" "$REPO_ROOT/config/zshrc"
  [ -f "$HOME/.config/omamac/herdr.toml" ]
  # shellcheck disable=SC2016
  [ "$(cat "$HOME/.zprofile")" = 'eval "$(/opt/homebrew/bin/brew shellenv)" # added by omamac' ]
  [ "$(cat "$HOME/.zshrc")" = '[[ -r ~/.config/omamac/zshrc ]] && source ~/.config/omamac/zshrc # added by omamac' ]
}

@test "used Mac: appends and keeps the user's lines" {
  echo 'alias x=y' > "$HOME/.zshrc"
  run install
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$HOME/.zshrc")" = 'alias x=y' ]
  [ "$(sed -n 2p "$HOME/.zshrc")" = '[[ -r ~/.config/omamac/zshrc ]] && source ~/.config/omamac/zshrc # added by omamac' ]
  [ "$(wc -l < "$HOME/.zshrc" | tr -d ' ')" = 2 ]
}

@test "an existing brew shellenv line is respected" {
  # shellcheck disable=SC2016
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' > "$HOME/.zprofile"
  before=$(shasum < "$HOME/.zprofile")
  run install
  [ "$status" -eq 0 ]
  [ "$(shasum < "$HOME/.zprofile")" = "$before" ]
}

@test "second run changes nothing" {
  run install
  [ "$status" -eq 0 ]
  first=$(snapshot)
  sleep 1.1
  run install
  [ "$status" -eq 0 ]
  [ "$(snapshot)" = "$first" ]
}

@test "the zsh file puts omamac on the PATH once" {
  run install
  [ "$status" -eq 0 ]
  run zsh -c "source $HOME/.config/omamac/zshrc; source $HOME/.config/omamac/zshrc; echo \$PATH"
  [ "$status" -eq 0 ]
  count=$(grep -o '\.local/share/omamac/bin' <<< "$output" | wc -l | tr -d ' ')
  [ "$count" -eq 1 ]
}

@test "never-touch list stays untouched" {
  local mine=(.config/herdr/config.toml .config/mise/config.toml .config/starship.toml .config/btop/btop.conf) f before=''
  for f in "${mine[@]}"; do
    mkdir -p "$(dirname "$HOME/$f")"
    echo 'mine' > "$HOME/$f"
    before+="$(shasum < "$HOME/$f") $(stat -f %m "$HOME/$f");"
  done
  fresh_answers yes
  run install
  [ "$status" -eq 0 ]
  for p in .ssh .gitconfig .npmrc .m2/settings.xml .curlrc; do
    [ ! -e "$HOME/$p" ]
  done
  local after=''
  for f in "${mine[@]}"; do after+="$(shasum < "$HOME/$f") $(stat -f %m "$HOME/$f");"; done
  [ "$after" = "$before" ]
  run grep -rnE '/etc/|/Library/' "$REPO_ROOT/install.sh" "$REPO_ROOT/lib"
  # Only comment lines may match, and Ghostty's own folder under $HOME.
  [ -z "$(grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' <<< "$output" | grep -vF '$HOME/Library/Application Support/com.mitchellh.ghostty')" ]
}

@test "never-touch: colima leaves ~/.docker/config.json alone" {
  # colima writes this file, and docker login keeps credentials in it: it's never omamac's.
  sed -i '' 's/^docker=.*/docker=colima/' "$CHOICES_FILE"
  mkdir -p "$HOME/.docker"
  echo '{"auths":{}}' > "$HOME/.docker/config.json"
  touch -t 202001010000 "$HOME/.docker/config.json"
  before="$(shasum < "$HOME/.docker/config.json") $(stat -f %m "$HOME/.docker/config.json")"
  run install
  [ "$status" -eq 0 ]
  [ -L "$HOME/.docker/cli-plugins/docker-compose" ]
  [ "$(shasum < "$HOME/.docker/config.json") $(stat -f %m "$HOME/.docker/config.json")" = "$before" ]
}

@test "a failing step names itself, not a log that lacks it" {
  echo 'alias x=y' > "$HOME/.zshrc"
  chmod 444 "$HOME/.zshrc"
  run install
  [ "$status" -eq 1 ]
  [[ "$output" == *".zshrc"* ]]
  [[ "$output" != *"Log:"* ]]
  [[ "$output" == *"run the one-liner again"* ]]
}

@test "summary tells the user what to do next" {
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Open Ghostty (it starts herdr), then run omamac."* ]]
  [[ "$output" != *"Open a new terminal window"* ]]
}

@test "summary names Ghostty and the clicks" {
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Open Ghostty"* ]]
  [[ "$output" == *"App Management"* ]]
  [[ "$output" == *"click Open"* ]]
  [[ "$output" == *"three Ghostty settings"* ]]
  [[ "$output" == *"colours"* ]]
  [[ "$output" == *"command"* ]]
  [[ "$output" == *"macos-option-as-alt"* ]]
}

@test "fresh: asks, saves, then writes the Phase 1 files" {
  fresh_answers yes
  run install
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 19 ]
  grep -qx 'apps_browsers=brave firefox' "$CHOICES_FILE"
  grep -qx 'docker=none' "$CHOICES_FILE"
  [ "$(grep -c '=' "$CHOICES_FILE")" = 18 ]
  [ -e "$HOME/.config/omamac/zshrc" ]
  [[ "$output" == *"Theme: Tokyo Night"* ]]
}

@test "re-run: no questions, the summary, Install? once" {
  run install
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum confirm --default=false Install?" ]
  [[ "$output" == *"Docker: No Docker"* ]]
  cmp "$CHOICES_FILE" "$REPO_ROOT/test/fixtures/bare.env"
}

@test "Install? no: exit 0, nothing written" {
  fresh_answers no
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
  [ ! -e "$CHOICES_FILE" ]
  [ ! -e "$HOME/.config/omamac" ]
  [ ! -e "$HOME/.zshrc" ]
  [ ! -e "$HOME/.zprofile" ]
}

@test "Ctrl-C at a question: exit 130, nothing written" {
  rm -f "$CHOICES_FILE"
  gum_answers tokyo-night "exit 130"
  run install
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
  [[ "$output" != *"omamac stopped while"* ]]
  [ ! -e "$CHOICES_FILE" ]
  [ ! -e "$HOME/.zshrc" ]
}

@test "broken choices.env: stops before any question" {
  printf 'theme=nord\ncolour=red\n' > "$CHOICES_FILE"
  before=$(shasum < "$CHOICES_FILE")
  run install
  [ "$status" -eq 1 ]
  [[ "$output" == *"line 2"* ]]
  [ -z "$(prompts)" ]
  [ "$(shasum < "$CHOICES_FILE")" = "$before" ]
  [ ! -e "$HOME/.zshrc" ]
}

@test "saving fails: stops naming it, no zsh file or lines" {
  fresh_answers yes
  chmod 555 "$(dirname "$CHOICES_FILE")"
  run install
  chmod 755 "$(dirname "$CHOICES_FILE")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"saving your answers"* ]]
  [ ! -e "$HOME/.config/omamac/zshrc" ]
  [ ! -e "$HOME/.zshrc" ]
}

@test "Ctrl-C at Install?: exit 130, nothing written" {
  fresh_answers "exit 130"
  run install
  [ "$status" -eq 130 ]
  [ ! -e "$CHOICES_FILE" ]
  [ ! -e "$HOME/.zshrc" ]
}

@test "partial file: only the new question is asked, saved answers kept" {
  sed -i '' -e '/^docker=/d' -e 's/^apps_media=$/apps_media=vlc/' "$CHOICES_FILE"
  gum_answers docker-desktop yes
  run install
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 2 ]
  grep -qx 'docker=docker-desktop' "$CHOICES_FILE"
  grep -qx 'apps_media=vlc' "$CHOICES_FILE"
  [ "$(grep -c '=' "$CHOICES_FILE")" = 18 ]
}

@test "no on a re-run keeps the saved answers and says nothing about asking again" {
  gum_answers no
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
  [[ "$output" != *"asks"* ]]
  cmp "$CHOICES_FILE" "$REPO_ROOT/test/fixtures/bare.env"
}

@test "no on a first run says the next run asks again" {
  fresh_answers no
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"The next run asks those questions again."* ]]
}

@test "installs the core and LazyVim after Install?" {
  run install
  [ "$status" -eq 0 ]
  [ "$(grep -c '^brew install .*starship' "$STUB_LOG")" = 1 ]
  [ -f "$HOME/.config/nvim/lua/plugins/omamac.lua" ]
  [[ "$output" == *"Installed: Homebrew, bash, gum, omamac, Ghostty and the core tools"* ]]
  [[ "$output" == *"and the languages, cloud CLIs and coding agents you chose."* ]]
}

@test "summary names Reduce motion only when macOS refused it" {
  fresh_answers yes
  export T_DEFAULTS_REFUSE=com.apple.universalaccess
  run install
  [ "$status" -eq 0 ]
  # Once from the step, once from the summary box.
  [ "$(grep -c 'Turn on Reduce motion' <<< "$output")" -eq 2 ]
  unset T_DEFAULTS_REFUSE
  fresh_answers yes
  run install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Turn on Reduce motion"* ]]
}

@test "installs the chosen languages after Install?" {
  fresh_answers yes
  run install
  [ "$status" -eq 0 ]
  grep -qx 'mise install node python' "$STUB_LOG"
  [ "$(grep -c '^mise install' "$STUB_LOG")" = 1 ]
}

@test "installs the chosen cloud CLIs after Install?" {
  fresh_answers yes
  run install
  [ "$status" -eq 0 ]
  grep -qx 'brew install gh' "$STUB_LOG"
  [[ "$output" == *"✓ Your CLIs are installed"* ]]
}

@test "Install? no: no brew install, no nvim" {
  fresh_answers no
  run install
  [ "$status" -eq 0 ]
  [ "$(grep -c '^brew install' "$STUB_LOG")" = 1 ]  # only setup's gum
  [ ! -e "$HOME/.config/omamac/zshrc" ]
  [ ! -e "$HOME/.config/nvim" ]
  run ! grep -q '^brew install .*starship' "$STUB_LOG"
}

@test "a re-run calls no brew upgrade" {
  run install
  [ "$status" -eq 0 ]
  run install
  [ "$status" -eq 0 ]
  [ "$(grep -c '^brew upgrade' "$STUB_LOG" || true)" = 0 ]
  [ "$(grep -c '^brew install .*starship' "$STUB_LOG")" = 1 ]
}

@test "never-touch: a user's nvim folder is left alone" {
  mkdir -p "$HOME/.config/nvim"
  echo 'mine' > "$HOME/.config/nvim/init.lua"
  before=$(cd "$HOME/.config/nvim" && find . -type f -exec shasum {} + | sort)
  run install
  [ "$status" -eq 0 ]
  [ "$(cd "$HOME/.config/nvim" && find . -type f -exec shasum {} + | sort)" = "$before" ]
}

@test "a failing core install stops naming its step, no nvim" {
  T_BREW_FAIL=1 run install
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while installing the core tools."* ]]
  [ ! -e "$HOME/.config/nvim" ]
}

@test "Docker Desktop installs first, so Homebrew asks for the password while the user is there" {
  # The fixture also picks Zoom, so one call covers both.
  cp "$REPO_ROOT/test/fixtures/docker-desktop.env" "$CHOICES_FILE"
  : > "$STUB_LOG"
  run install
  [ "$status" -eq 0 ]
  [ "$(grep -nE '^brew install' "$STUB_LOG" | head -1 | cut -d: -f2-)" = "brew install --cask zoom docker-desktop" ]
  [ "$(grep -nx 'brew install --cask zoom docker-desktop' "$STUB_LOG" | cut -d: -f1)" -lt "$(grep -n '^brew install .*jq' "$STUB_LOG" | head -1 | cut -d: -f1)" ]
}

# answer <key> <value>: change one saved answer.
answer() { sed -i '' "s/^$1=.*/$1=$2/" "$CHOICES_FILE"; }

@test "the password step is named before Install?, in no line that says Install?" {
  answer apps_communication zoom
  gum_answers no
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Homebrew asks for your password once more, after you confirm, for: Zoom."* ]]
  [[ "$output" != *"Install?"* ]]
  run ! grep -q '^brew install --cask' "$STUB_LOG"
}

@test "no password app: no once-more line" {
  run install
  [ "$status" -eq 0 ]
  [[ "$output" != *"once more"* ]]
}

@test "summary names the apps and what they ask macOS for" {
  answer apps_screen_recording cap
  answer wispr_flow yes
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"and the languages, cloud CLIs, coding agents and apps you chose."* ]]
  [[ "$output" == *"The first time you open Ghostty and each app, macOS asks you"$'\n'"to confirm; click Open."$'\n'"Cap: allow Screen Recording, and Camera and Microphone if you use them."$'\n'"Wispr Flow: allow Microphone and Accessibility."$'\n'* ]]
  [[ "$output" != *"Zoom: allow"* ]]
}

@test "summary with apps and Docker names all four" {
  answer apps_media vlc
  answer docker colima
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"and the languages, cloud CLIs, coding agents, apps and Docker you chose."* ]]
}

@test "no apps: the summary's Ghostty lines are today's" {
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"The first time you open Ghostty, macOS asks you to confirm;"$'\n'"click Open."$'\n'* ]]
  [[ "$output" != *"each app"* ]]
}

# Adoption: VLC is picked and in Applications, not from Homebrew.
vlc_by_hand() {
  answer apps_media vlc
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  echo mine > "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker"
}

ADOPT_Q="gum confirm --default=false Let Homebrew take over VLC?"
INSTALL_Q="gum confirm --default=false Install?"

@test "adopt: asked before the summary box; yes keeps VLC and adopts it" {
  vlc_by_hand
  gum_answers yes yes
  run install
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$ADOPT_Q"$'\n'"$INSTALL_Q" ]
  [[ "$output" == *"Homebrew can take it over"*"Media: VLC"* ]]
  grep -qx 'apps_media=vlc' "$CHOICES_FILE"
  grep -qx 'brew install --cask --adopt vlc' "$STUB_LOG"
  [ "$(cat "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker")" = mine ]
}

@test "adopt: no drops VLC from the summary and the saved answers; no brew call names it" {
  vlc_by_hand
  gum_answers no yes
  run install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Media: none"* ]]
  grep -qx 'apps_media=' "$CHOICES_FILE"
  run ! grep -qE '^brew .*vlc' "$STUB_LOG"
}

@test "adopt: no, then Install? no: nothing saved, and the next run asks again" {
  vlc_by_hand
  before=$(shasum < "$CHOICES_FILE")
  gum_answers no no
  run install
  [ "$status" -eq 0 ]
  [ "$(shasum < "$CHOICES_FILE")" = "$before" ]
  : > "$STUB_LOG"
  gum_answers no no
  run install
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$ADOPT_Q"$'\n'"$INSTALL_Q" ]
}

@test "adopt: a second run after adopting asks nothing new" {
  vlc_by_hand
  gum_answers yes yes
  run install
  [ "$status" -eq 0 ]
  : > "$STUB_LOG"
  gum_answers yes
  run install
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$INSTALL_Q" ]
  run ! grep -q -- '--adopt' "$STUB_LOG"
}

@test "adopt: a failed adopt stops the run naming VLC; the next run asks again and adopts" {
  vlc_by_hand
  gum_answers yes yes
  T_BREW_FAIL_CASK=vlc run install
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while handing VLC to Homebrew."* ]]
  [ "$(cat "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker")" = mine ]
  : > "$STUB_LOG"
  gum_answers yes yes
  run install
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$ADOPT_Q"$'\n'"$INSTALL_Q" ]
  grep -qx 'brew install --cask --adopt vlc' "$STUB_LOG"
}
