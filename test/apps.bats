load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
}

# in_apps <code>: run bash 5 code with the catalog loaded.
in_apps() {
  run "$BASH5" -c "set -Eeuo pipefail
    export OMAMAC_CHECKOUT='$REPO_ROOT'
    for f in paths ui questions choices core apps; do source '$REPO_ROOT/lib/'\$f.sh; done
    $1"
}

all_ids() {
  local k
  for k in apps_browsers apps_communication apps_media apps_screen_recording apps_storage apps_developer apps_ai apps_productivity; do
    "$BASH5" -c "source '$REPO_ROOT/lib/questions.sh'; question_values $k"
  done
  echo wispr-flow
}

@test "catalog: every option has a file, and every file is an option" {
  local id
  for id in $(all_ids); do [ -f "$REPO_ROOT/apps/$id" ] || { echo "missing apps/$id"; return 1; }; done
  [ "$(all_ids | sort)" = "$(ls "$REPO_ROOT/apps")" ]
}

@test "catalog: every file has a cask and an app" {
  local f
  for f in "$REPO_ROOT"/apps/*; do
    grep -q '^cask=.' "$f" && grep -q '^app=.' "$f" || { echo "$f"; return 1; }
  done
}

@test "catalog: exact casks, apps, passwords and allow lines" {
  in_apps 'for id in $(apps_ids); do printf "%s|%s|%s|%s|%s\n" "$id" "${APP_CASK[$id]}" "${APP_BUNDLE[$id]}" "${APP_PASSWORD[$id]}" "${APP_ALLOW[$id]}"; done'
  [ "$status" -eq 0 ]
  [ "$output" = "brave|brave-browser|Brave Browser.app||
chrome|google-chrome|Google Chrome.app||
firefox|firefox|Firefox.app||
whatsapp|whatsapp|WhatsApp.app||
telegram|telegram|Telegram.app||
signal|signal|Signal.app||
discord|discord|Discord.app||
slack|slack|Slack.app||
zoom|zoom|zoom.us.app|yes|Zoom: allow Camera and Microphone, and Screen Recording to share.
spotify|spotify|Spotify.app||
vlc|vlc|VLC.app||
cap|cap|Cap.app||Cap: allow Screen Recording, and Camera and Microphone if you use them.
dropbox|dropbox|Dropbox.app||
google-drive|google-drive|Google Drive.app|yes|
vscode|visual-studio-code|Visual Studio Code.app||
claude|claude|Claude.app||
chatgpt|chatgpt|ChatGPT.app||
copilot|github-copilot-app|GitHub Copilot.app||
antigravity|antigravity|Antigravity.app||
raycast|raycast|Raycast.app||
obsidian|obsidian|Obsidian.app||
wispr-flow|wispr-flow|Wispr Flow.app||Wispr Flow: allow Microphone and Accessibility." ]
}

@test "catalog: CASK_APP gets every cask's app" {
  in_apps 'echo "${CASK_APP[visual-studio-code]}|${CASK_APP[ghostty]}"'
  [ "$output" = "Visual Studio Code.app|Ghostty.app" ]
}

@test "catalog: a bad line stops sourcing and names the file and line" {
  local co="$BATS_TEST_TMPDIR/co"
  mkdir -p "$co/apps"
  printf 'cask=x\n\n# c\napp x\n' > "$co/apps/bad"
  run "$BASH5" -c "set -e; export OMAMAC_CHECKOUT='$co'
    for f in paths ui questions choices core; do source '$REPO_ROOT/lib/'\$f.sh; done
    source '$REPO_ROOT/lib/apps.sh'; echo sourced"
  [ "$status" -ne 0 ]
  [[ $output == *"apps/bad, line 4"* ]]
  [[ $output != *sourced* ]]
}

@test "catalog: an unknown key stops sourcing" {
  local co="$BATS_TEST_TMPDIR/co"
  mkdir -p "$co/apps"
  printf 'cask=x\napp=X.app\nsudo=yes\n' > "$co/apps/bad"
  run "$BASH5" -c "set -e; export OMAMAC_CHECKOUT='$co'
    for f in paths ui questions choices core; do source '$REPO_ROOT/lib/'\$f.sh; done
    source '$REPO_ROOT/lib/apps.sh'; echo sourced"
  [ "$status" -ne 0 ]
  [[ $output == *"apps/bad, line 3"* ]]
}

@test "apps_chosen: the picked ids, one per line, in question order" {
  in_apps 'CHOICES[apps_media]=vlc; CHOICES[apps_developer]=vscode; CHOICES[wispr_flow]=yes; apps_chosen'
  [ "$output" = $'vlc\nvscode\nwispr-flow' ]
}

@test "apps_key and apps_label" {
  in_apps 'apps_key wispr-flow; apps_key vscode; apps_label wispr-flow; apps_label vscode; apps_label google-drive'
  [ "$output" = $'wispr_flow\napps_developer\nWispr Flow\nVS Code\nGoogle Drive' ]
}

@test "apps_drop changes only its own answer" {
  in_apps 'CHOICES[apps_media]="spotify vlc"; CHOICES[wispr_flow]=yes
    apps_drop vlc; echo "${CHOICES[apps_media]}|${CHOICES[wispr_flow]}"
    apps_drop wispr-flow; echo "${CHOICES[apps_media]}|${CHOICES[wispr_flow]}"'
  [ "$output" = $'spotify|yes\nspotify|no' ]
}

@test "fake-brew: a cask in apps/ puts its app in Applications" {
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask zoom
  [ -d "$OMAMAC_TEST_APPLICATIONS/zoom.us.app" ]
}

# The tests below install. P is the fake Homebrew; gum is there, so ui_run spins.
apps_brew() {
  install_fake_brew
  P="$OMAMAC_TEST_BREW_PREFIX"
  "$P/bin/brew" install gum
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/run.log"
}

# in_steps <code>: like in_apps, with the Docker step too, and only the code's own brew calls logged.
in_steps() {
  : > "$STUB_LOG"
  run "$BASH5" -c "set -Eeuo pipefail
    export OMAMAC_CHECKOUT='$REPO_ROOT'
    for f in paths ui questions choices core apps clis docker; do source '$REPO_ROOT/lib/'\$f.sh; done
    $1"
}

# answers <key=value>…: the saved answers, bare.env with these changed.
answers() {
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  local kv
  for kv in "$@"; do sed -i '' "s/^${kv%%=*}=.*/$kv/" "$CHOICES_FILE"; done
}

# first_run: install.sh with the saved answers, Install? answered yes; only its own calls logged.
first_run() {
  gum_answers yes
  : > "$STUB_LOG"
  "$BASH5" "$REPO_ROOT/install.sh"
}

# changes: the brew calls that change something, in order.
changes() { grep -E '^brew (install|reinstall|uninstall|upgrade|tap|services)' "$STUB_LOG" || true; }

@test "password step: Zoom, Google Drive and Docker Desktop in one call, first, in the open" {
  apps_brew
  answers apps_communication=zoom apps_storage=google-drive docker=docker-desktop
  run first_run
  [ "$status" -eq 0 ]
  [ "$(changes | head -1)" = "brew install --cask zoom google-drive docker-desktop" ]
  [ "$(changes | grep -c 'zoom')" -eq 1 ]
  [ "$(changes | grep -c 'docker-desktop')" -eq 1 ]
  [[ "$output" == *"Installing Zoom, Google Drive, Docker Desktop"$'\n'* ]]
  [[ "$output" != *"Homebrew asks for your password for"* ]]
  run ! grep -q '^gum spin.*zoom' "$STUB_LOG"
}

@test "password step: nothing missing, no password line and no call" {
  apps_brew
  "$P/bin/brew" install --cask zoom
  # By hand: not Homebrew's to install.
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/Google Drive.app"
  in_steps 'CHOICES[apps_communication]=zoom; CHOICES[apps_storage]=google-drive; apps_install_password; echo "pending=[$(apps_password_pending)]"'
  [ "$status" -eq 0 ]
  [ "$output" = "pending=[]" ]
  [ -z "$(changes)" ]
  in_steps 'apps_install_password; echo "pending=[$(apps_password_pending)]"'
  [ "$output" = "pending=[]" ]
}

@test "password step: Zoom listed but its app gone, reinstalled in a second call" {
  apps_brew
  "$P/bin/brew" install --cask zoom
  rm -rf "$OMAMAC_TEST_APPLICATIONS/zoom.us.app"
  in_steps 'CHOICES[apps_communication]=zoom; CHOICES[apps_storage]=google-drive; apps_install_password'
  [ "$status" -eq 0 ]
  [ "$(changes)" = $'brew install --cask google-drive\nbrew reinstall --cask zoom' ]
  [ -d "$OMAMAC_TEST_APPLICATIONS/zoom.us.app" ]
  run ! grep -q '^gum spin' "$STUB_LOG"
}

@test "password step: only the given ids, and Docker Desktop's note" {
  apps_brew
  in_steps 'CHOICES[apps_communication]=zoom; CHOICES[docker]=docker-desktop
    apps_password_pending; apps_password_pending docker-desktop
    DOCKER_NOTES=(); apps_install_password docker-desktop; printf "%s\n" "${DOCKER_NOTES[@]}"'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = zoom ]
  [ "${lines[1]}" = docker-desktop ]
  [ "${lines[2]}" = docker-desktop ]
  [ "${lines[3]}" = "Installing Docker Desktop" ]
  [[ "$output" == *$'\n'"Open Docker Desktop once to finish its setup." ]]
  [ "$(changes)" = "brew install --cask docker-desktop" ]
}

@test "password step: a brew failure returns non-zero with errexit off" {
  apps_brew
  export T_BREW_FAIL=1
  in_steps 'set +e; CHOICES[apps_communication]=zoom; apps_install_password || echo "rc=$?"'
  [[ "$output" == *"rc=1"* ]]
  [[ "$output" == *"Log: $OMAMAC_LOG"* ]]
}

@test "apps_install: one call per missing app, a brew app skipped, a hand app named" {
  apps_brew
  "$P/bin/brew" install --cask spotify
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/Obsidian.app"
  in_steps 'CHOICES[apps_media]="spotify vlc"; CHOICES[apps_developer]=vscode
    CHOICES[apps_productivity]=obsidian; CHOICES[apps_communication]=zoom; apps_install'
  [ "$status" -eq 0 ]
  [ "$(changes)" = $'brew install --cask vlc\nbrew install --cask visual-studio-code' ]
  grep -q '^gum spin --title Installing VLC ' "$STUB_LOG"
  grep -q '^gum spin --title Installing VS Code ' "$STUB_LOG"
  [[ "$output" == *"ℹ Obsidian is already installed, not through Homebrew. omamac won't update it. To let Homebrew take it over: brew install --cask --adopt obsidian"* ]]
  [ -d "$OMAMAC_TEST_APPLICATIONS/VLC.app" ]
}

@test "apps_install: a hand-installed Zoom or Google Drive gets the hand line too" {
  apps_brew
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/zoom.us.app" "$OMAMAC_TEST_APPLICATIONS/Google Drive.app"
  in_steps 'CHOICES[apps_communication]=zoom; CHOICES[apps_storage]=google-drive; apps_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Zoom is already installed, not through Homebrew. omamac won't update it."* ]]
  [[ "$output" == *"ℹ Google Drive is already installed, not through Homebrew. omamac won't update it."* ]]
  [ -z "$(changes)" ]
}

@test "apps_install: ✓ when any app is chosen, even with nothing to install; nothing when none is" {
  apps_brew
  "$P/bin/brew" install --cask zoom
  in_steps 'CHOICES[apps_communication]=zoom; apps_install'
  [ "$status" -eq 0 ]
  [ "$output" = "✓ Your apps are installed" ]
  in_steps 'apps_install'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "apps_install: listed but the app is gone, reinstalled; only the given ids" {
  apps_brew
  "$P/bin/brew" install --cask vlc
  rm -rf "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  in_steps 'CHOICES[apps_media]=vlc; CHOICES[apps_developer]=vscode; apps_install vlc'
  [ "$status" -eq 0 ]
  [ "$(changes)" = "brew reinstall --cask vlc" ]
  # doctor's Reinstall of one app: not the whole run's line.
  [[ "$output" != *"Your apps are installed"* ]]
}

@test "a failed Chrome download stops the run naming Chrome; the next run installs only Chrome" {
  apps_brew
  answers 'apps_browsers=brave chrome'
  T_BREW_FAIL_CASK=google-chrome run first_run
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while installing Chrome."* ]]
  [ -d "$OMAMAC_TEST_APPLICATIONS/Brave Browser.app" ]
  run first_run
  [ "$status" -eq 0 ]
  [ "$(changes | grep -- '--cask')" = "brew install --cask google-chrome" ]
}

@test "a second full run calls no install" {
  apps_brew
  answers apps_communication=zoom apps_media=vlc docker=docker-desktop wispr_flow=yes
  run first_run
  [ "$status" -eq 0 ]
  run first_run
  [ "$status" -eq 0 ]
  [ -z "$(changes)" ]
  [[ "$output" != *"Homebrew asks for your password"* ]]
}

# Adoption: a hand-installed app offered to Homebrew at the first run.

# in_ask <code>: like in_steps, with lib/ask.sh, so the code can ask.
in_ask() {
  : > "$STUB_LOG"
  run "$BASH5" -c "set -Eeuo pipefail
    export OMAMAC_CHECKOUT='$REPO_ROOT'
    for f in paths ui questions choices ask core apps; do source '$REPO_ROOT/lib/'\$f.sh; done
    $1"
}

prompts() { grep -E '^gum (choose|confirm)' "$STUB_LOG" || true; }

@test "apps_ask_adopt: VLC by hand, yes: the help line, the question, adopted, picks kept" {
  apps_brew
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  gum_answers yes
  in_ask 'CHOICES[apps_media]="spotify vlc"; apps_ask_adopt spotify vlc
    echo "adopt=${APPS_ADOPT[*]}|${CHOICES[apps_media]}"'
  [ "$status" -eq 0 ]
  [ "$output" = "ℹ VLC is already installed, but not through Homebrew. Homebrew can take it over, so it's updated and managed like your other apps.
adopt=vlc|spotify vlc" ]
  [ "$(prompts)" = "gum confirm --default=false Let Homebrew take over VLC?" ]
}

@test "apps_ask_adopt: VLC by hand, no: the no line, VLC leaves its picks, the rest stay" {
  apps_brew
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  gum_answers no
  in_ask 'CHOICES[apps_media]="spotify vlc"; CHOICES[apps_developer]=vscode
    apps_ask_adopt spotify vlc vscode
    echo "adopt=[${APPS_ADOPT[*]}]|${CHOICES[apps_media]}|${CHOICES[apps_developer]}"'
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\n'"ℹ omamac leaves VLC as it is and drops it from your picks."$'\n'"adopt=[]|spotify|vscode" ]]
}

@test "apps_ask_adopt: Zoom by hand is told why, not asked, and leaves its picks" {
  apps_brew
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/zoom.us.app"
  gum_answers
  in_ask 'CHOICES[apps_communication]="slack zoom"; apps_ask_adopt slack zoom
    echo "adopt=[${APPS_ADOPT[*]}]|${CHOICES[apps_communication]}"'
  [ "$status" -eq 0 ]
  [ "$output" = "ℹ Zoom is already installed, not through Homebrew. Homebrew can only take it over by installing it again, so omamac leaves it.
adopt=[]|slack" ]
  [ -z "$(prompts)" ]
}

@test "apps_ask_adopt: Wispr Flow by hand, no: wispr_flow=no" {
  apps_brew
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/Wispr Flow.app"
  gum_answers no
  in_ask 'CHOICES[wispr_flow]=yes; apps_ask_adopt wispr-flow; echo "wispr_flow=${CHOICES[wispr_flow]}"'
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum confirm --default=false Let Homebrew take over Wispr Flow?" ]
  [[ "$output" == *$'\n'"wispr_flow=no" ]]
}

@test "apps_ask_adopt: an app from Homebrew or not there: nothing printed, nothing asked" {
  apps_brew
  "$P/bin/brew" install --cask vlc
  gum_answers
  in_ask 'CHOICES[apps_media]="spotify vlc"; apps_ask_adopt spotify vlc; echo "adopt=[${APPS_ADOPT[*]}]|${CHOICES[apps_media]}"'
  [ "$status" -eq 0 ]
  [ "$output" = "adopt=[]|spotify vlc" ]
  [ -z "$(prompts)" ]
}

@test "apps_ask_adopt: returns non-zero when Homebrew can't list" {
  apps_brew
  export T_BREW_LIST_FAIL=1
  in_ask 'set +e; apps_ask_adopt vlc; echo "rc=$?"'
  [[ "$output" == *"rc=1" ]]
}

# vlc_by_hand: VLC in Applications, not from Homebrew, with a file of the user's inside.
vlc_by_hand() {
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  echo mine > "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker"
}

@test "apps_install: VLC by hand and adopted: one --adopt call, the app untouched, then from Homebrew" {
  apps_brew
  vlc_by_hand
  in_steps 'CHOICES[apps_media]=vlc; APPS_ADOPT=(vlc); apps_install; core_cask_state vlc'
  [ "$status" -eq 0 ]
  [ "$(changes)" = "brew install --cask --adopt vlc" ]
  grep -q '^gum spin --title Handing VLC to Homebrew ' "$STUB_LOG"
  [ "$(cat "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker")" = mine ]
  [[ "$output" == *$'\n'brew ]]
}

@test "apps_install: VLC by hand, not adopted: the hand line, no brew call" {
  apps_brew
  vlc_by_hand
  in_steps 'CHOICES[apps_media]=vlc; apps_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ VLC is already installed, not through Homebrew. omamac won't update it. To let Homebrew take it over: brew install --cask --adopt vlc"* ]]
  [ -z "$(changes)" ]
}

@test "apps_install: a failed adopt returns non-zero, names the step, leaves the app" {
  apps_brew
  vlc_by_hand
  export T_BREW_FAIL_CASK=vlc
  in_steps 'set +e; CHOICES[apps_media]=vlc; APPS_ADOPT=(vlc); apps_install; echo "rc=$? step=$OMAMAC_STEP"'
  [[ "$output" == *"rc=1 step=handing VLC to Homebrew" ]]
  [ "$(cat "$OMAMAC_TEST_APPLICATIONS/VLC.app/marker")" = mine ]
  [ ! -e "$P/Caskroom/vlc" ]
}
