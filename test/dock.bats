load helpers/common
load helpers/dock

setup() {
  setup_sandbox
  RECORD="$HOME/.local/state/omamac/dock-before.plist"
  ADDED="$HOME/.local/state/omamac/dock-added"
  PLIST="$T_DEFAULTS_DIR/com.apple.dock.plist"
  APPS="$OMAMAC_TEST_APPLICATIONS"
  mkdir -p "$APPS/Ghostty.app" "$APPS/VLC.app"
  CHOOSE='CHOICES[dock]=yes; CHOICES[apps_media]=vlc'
}

# in_lib <code>: run bash 5 code with the settings and Dock steps loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    export OMAMAC_CHECKOUT='$REPO_ROOT'
    for f in paths ui questions choices core apps settings dock; do source '$REPO_ROOT/lib/'\$f.sh; done
    trap 'echo \"FAILED: \$OMAMAC_STEP\"' ERR
    $1"
}

# url <app>: the URL of an app in the fake Applications.
url() { echo "file://${APPS// /%20}/${1// /%20}/"; }

count() { grep -c "^$1" "$STUB_LOG" || true; }

@test "a first run cleans the Dock and adds omamac's apps" {
  dock_seed file:///System/Applications/Mail.app/ \
    file:///System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/ \
    'file:///Applications/Keynote.app/|com.apple.iWork.Keynote' \
    file:///Applications/Things.app/ spacer \
    -- "file://$HOME/Downloads/" file:///Users/x/Projects/
  cp "$PLIST" "$BATS_TEST_TMPDIR/seeded.plist"
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps)" = "file:///Applications/Things.app/
spacer
$(url Ghostty.app)
$(url VLC.app)" ]
  [ "$(dock_urls persistent-others)" = file:///Users/x/Projects/ ]
  cmp "$RECORD" "$BATS_TEST_TMPDIR/seeded.plist"
  [ "$(cat "$ADDED")" = "Ghostty.app
VLC.app" ]
  [ "$(count 'defaults import com.apple.dock')" -eq 1 ]
  [ "$(count 'killall Dock')" -eq 1 ]
}

@test "a new tile holds only its type and URL" {
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(plutil -extract persistent-apps.0.tile-type raw "$PLIST")" = file-tile ]
  [ "$(plutil -extract persistent-apps.0.tile-data.file-data._CFURLStringType raw "$PLIST")" = 15 ]
  ! plutil -extract persistent-apps.0.tile-data.bundle-identifier raw "$PLIST"
}

@test "a second run changes nothing" {
  dock_seed file:///Applications/Things.app/
  in_lib "$CHOOSE; settings_apply"
  cp "$PLIST" "$BATS_TEST_TMPDIR/after.plist"
  : > "$STUB_LOG"
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(count 'defaults import')" -eq 0 ]
  [ "$(count killall)" -eq 0 ]
  cmp "$PLIST" "$BATS_TEST_TMPDIR/after.plist"
}

@test "an app the user pinned is kept once, and not put back once removed" {
  dock_seed "$(url VLC.app)"
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps)" = "$(url VLC.app)
$(url Ghostty.app)" ]
  grep -qx VLC.app "$ADDED"
  dock_seed "$(url Ghostty.app)"
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps)" = "$(url Ghostty.app)" ]
}

@test "a name with spaces gets %20, and its tile counts as there" {
  mkdir -p "$APPS/Visual Studio Code.app"
  in_lib "$CHOOSE; CHOICES[apps_developer]=vscode; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps | tail -1)" = "file://$APPS/Visual%20Studio%20Code.app/" ]
  rm -f "$RECORD" "$ADDED"
  dock_seed "file://$APPS/Visual%20Studio%20Code.app/"
  in_lib "$CHOOSE; CHOICES[apps_developer]=vscode; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps | grep -c 'Visual%20Studio%20Code')" -eq 1 ]
}

@test "an app installed later is added after the others, the record kept" {
  in_lib "$CHOOSE; settings_apply"
  cp "$RECORD" "$BATS_TEST_TMPDIR/record.before"
  mkdir -p "$APPS/Spotify.app"
  : > "$STUB_LOG"
  in_lib 'CHOICES[dock]=yes; CHOICES[apps_media]="spotify vlc"; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps)" = "$(url Ghostty.app)
$(url VLC.app)
$(url Spotify.app)" ]
  grep -qx Spotify.app "$ADDED"
  [ "$(count 'defaults import')" -eq 1 ]
  cmp "$RECORD" "$BATS_TEST_TMPDIR/record.before"
}

@test "an app from a run that failed before the Dock step is added next run" {
  in_lib "$CHOOSE; settings_apply"
  mkdir -p "$APPS/Spotify.app"
  defaults write com.apple.dock show-recents -bool true
  T_DEFAULTS_FAIL=com.apple.dock:show-recents in_lib 'CHOICES[dock]=yes; CHOICES[apps_media]="spotify vlc"; settings_apply'
  [ "$status" -ne 0 ]
  ! grep -qx Spotify.app "$ADDED"
  in_lib 'CHOICES[dock]=yes; CHOICES[apps_media]="spotify vlc"; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps | tail -1)" = "$(url Spotify.app)" ]
  grep -qx Spotify.app "$ADDED"
}

@test "Docker Desktop is added last" {
  mkdir -p "$APPS/Docker.app"
  in_lib "$CHOOSE; CHOICES[docker]=docker-desktop; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps)" = "$(url Ghostty.app)
$(url VLC.app)
$(url Docker.app)" ]
}

@test "an app not in Applications is not added" {
  rm -rf "$APPS/VLC.app"
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps)" = "$(url Ghostty.app)" ]
  [ "$(cat "$ADDED")" = Ghostty.app ]
}

@test "a Dock without either array" {
  dock_seed
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ "$(dock_urls persistent-apps)" = "$(url Ghostty.app)
$(url VLC.app)" ]
  [ -z "$(dock_urls persistent-others)" ]
}

@test "a failed import removes the record; the next run cleans up" {
  dock_seed file:///System/Applications/Mail.app/
  T_DEFAULTS_FAIL=com.apple.dock:import in_lib "$CHOOSE; settings_apply"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAILED: cleaning up the Dock"* ]]
  [ ! -e "$RECORD" ]
  [ ! -e "$ADDED" ]
  [ "$(dock_urls persistent-apps)" = file:///System/Applications/Mail.app/ ]
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  [ -f "$RECORD" ]
  [ "$(dock_urls persistent-apps)" = "$(url Ghostty.app)
$(url VLC.app)" ]
}

@test "the copy is removed" {
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
  in_lib "$CHOOSE; settings_apply"
  [ "$status" -eq 0 ]
  T_DEFAULTS_FAIL=com.apple.dock:import in_lib "rm -f '$RECORD'; $CHOOSE; settings_apply"
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "dock=no: the Dock is not read" {
  in_lib 'CHOICES[dock]=no; CHOICES[apps_media]=vlc; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(count 'defaults export')" -eq 0 ]
  [ ! -e "$RECORD" ]
}
