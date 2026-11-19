load helpers/common

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
  for k in apps_browsers apps_communication apps_media apps_screen_recording apps_storage apps_developer apps_productivity; do
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
zoom|zoom|zoom.us.app|yes|Zoom: allow Camera and Microphone, and Screen Recording to share your screen.
spotify|spotify|Spotify.app||
vlc|vlc|VLC.app||
cap|cap|Cap.app||Cap: allow Screen Recording, and Camera and Microphone if you use them.
dropbox|dropbox|Dropbox.app||
google-drive|google-drive|Google Drive.app|yes|
vscode|visual-studio-code|Visual Studio Code.app||
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
