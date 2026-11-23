load helpers/common
load helpers/hotkeys

setup() {
  setup_sandbox
  REC="$HOME/.local/state/omamac/macos-settings.tsv"
  TAB=$'\t'
}

# in_lib <code>: run bash 5 code with the settings step loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/questions.sh'
    source '$REPO_ROOT/lib/choices.sh'
    source '$REPO_ROOT/lib/core.sh'
    source '$REPO_ROOT/lib/apps.sh'
    source '$REPO_ROOT/lib/settings.sh'
    source '$REPO_ROOT/lib/dock.sh'
    trap 'echo \"FAILED: \$OMAMAC_STEP\"' ERR
    $1"
}

# seed <domain> <key> <type> <value>: set a value through the fake.
seed() {
  local flag=-int
  [ "$3" != boolean ] || flag=-bool
  defaults write "$1" "$2" "$flag" "$4"
  : > "$STUB_LOG"
}

# value <domain> <key>: what `defaults read` says, or "absent".
value() { defaults read "$1" "$2" 2> /dev/null || echo absent; }

@test "no yes answers: defaults is never written" {
  in_lib 'CHOICES[desktops]=no; CHOICES[window_margins]=no; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" != *"defaults write"* ]]
  [[ "$(stub_calls)" != *killall* ]]
  [ ! -e "$REC" ]
}

@test "desktops on a clean Mac" {
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktops as workspaces"* ]]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  [ "$(value NSGlobalDomain AppleSpacesSwitchOnActivate)" = 1 ]
  [ "$(value com.apple.universalaccess reduceMotion)" = 1 ]
  [ "$(value com.apple.Accessibility ReduceMotionEnabled)" = 1 ]
  [ "$(cat "$REC")" = "com.apple.dock${TAB}mru-spaces${TAB}absent
NSGlobalDomain${TAB}AppleSpacesSwitchOnActivate${TAB}absent
$(hotkey_lines)
com.apple.universalaccess${TAB}reduceMotion${TAB}absent
com.apple.Accessibility${TAB}ReduceMotionEnabled${TAB}integer${TAB}0" ]
  [ "$(grep -c '^killall Dock' "$STUB_LOG")" -eq 1 ]
}

@test "window margins on a clean Mac" {
  in_lib 'CHOICES[window_margins]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.WindowManager EnableTiledWindowMargins)" = 1 ]
  [ "$(cat "$REC")" = "com.apple.WindowManager${TAB}EnableTiledWindowMargins${TAB}absent" ]
  [[ "$(stub_calls)" != *killall* ]]
}

@test "second apply changes nothing" {
  in_lib 'CHOICES[desktops]=yes; CHOICES[window_margins]=yes; settings_apply'
  [ "$status" -eq 0 ]
  cp "$REC" "$BATS_TEST_TMPDIR/rec.before"
  : > "$STUB_LOG"
  in_lib 'CHOICES[desktops]=yes; CHOICES[window_margins]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" != *"defaults write"* ]]
  [[ "$(stub_calls)" != *killall* ]]
  cmp "$REC" "$BATS_TEST_TMPDIR/rec.before"
}

@test "a value the user changed is put back, the record kept" {
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  cp "$REC" "$BATS_TEST_TMPDIR/rec.before"
  seed com.apple.dock mru-spaces boolean true
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Put back: Spaces order"* ]]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  cmp "$REC" "$BATS_TEST_TMPDIR/rec.before"
  # And once more: still byte for byte.
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  cmp "$REC" "$BATS_TEST_TMPDIR/rec.before"
}

@test "already the wanted value: not written, not recorded" {
  seed com.apple.dock mru-spaces boolean false
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" != *"defaults write com.apple.dock mru-spaces"* ]]
  [[ "$(cat "$REC")" != *mru-spaces* ]]
}

@test "Reduce motion refused" {
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  export T_DEFAULTS_REFUSE=com.apple.universalaccess
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turn on Reduce motion: search for Reduce motion in System Settings."* ]]
  [ "$(value com.apple.Accessibility ReduceMotionEnabled)" = 0 ]
  [[ "$(stub_calls)" != *"defaults write com.apple.Accessibility"* ]]
  [[ "$(cat "$REC")" != *educeMotion* ]]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  [ "$(value NSGlobalDomain AppleSpacesSwitchOnActivate)" = 1 ]
}

@test "another defaults failure stops the run" {
  export T_DEFAULTS_FAIL=NSGlobalDomain:AppleSpacesSwitchOnActivate
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAILED: setting AppleSpacesSwitchOnActivate in NSGlobalDomain"* ]]
  [[ "$(cat "$REC")" != *AppleSpacesSwitchOnActivate* ]]
}

@test "a record that can't be written: a plain key is put back and the run fails" {
  mkdir -p "$(dirname "$REC")"
  chmod 555 "$(dirname "$REC")"
  in_lib 'CHOICES[window_margins]=yes; settings_apply'
  chmod 755 "$(dirname "$REC")"
  [ "$status" -ne 0 ]
  [ "$(value com.apple.WindowManager EnableTiledWindowMargins)" = absent ]
}

@test "a record that can't be written: the Reduce motion unit is put back and the run fails" {
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  mkdir -p "$(dirname "$REC")"
  chmod 555 "$(dirname "$REC")"
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  chmod 755 "$(dirname "$REC")"
  [ "$status" -ne 0 ]
  [ "$(value com.apple.universalaccess reduceMotion)" = absent ]
  [ "$(value com.apple.Accessibility ReduceMotionEnabled)" = 0 ]
}

@test "a failing key still restarts the Dock when an earlier key changed it" {
  export T_DEFAULTS_FAIL=NSGlobalDomain:AppleSpacesSwitchOnActivate
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -ne 0 ]
  [ "$(grep -c '^killall Dock' "$STUB_LOG")" -eq 1 ]
}

@test "plain labels, and Put back prints once per label" {
  seed com.apple.dock mru-spaces boolean true
  seed com.apple.universalaccess reduceMotion boolean false
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  mkdir -p "$(dirname "$REC")"
  printf 'com.apple.dock\tmru-spaces\tboolean\ttrue\ncom.apple.universalaccess\treduceMotion\tboolean\tfalse\ncom.apple.Accessibility\tReduceMotionEnabled\tinteger\t0\n' > "$REC"
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Put back: Spaces order"* ]]
  [ "$(grep -c 'Put back: Reduce motion' <<< "$output")" -eq 1 ]
  [[ "$output" != *mru-spaces* ]]
}

@test "record with a key from an earlier run is never rewritten" {
  mkdir -p "$(dirname "$REC")"
  printf 'com.apple.dock\tmru-spaces\tboolean\ttrue\n' > "$REC"
  seed com.apple.dock mru-spaces boolean true
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  [[ "$output" == *"Put back: Spaces order"* ]]
  [ "$(grep -c mru-spaces "$REC")" -eq 1 ]
  [[ "$(grep mru-spaces "$REC")" == *"boolean${TAB}true" ]]
}

@test "Reduce motion domain refused for reading: neither key changed or recorded" {
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  export T_DEFAULTS_REFUSE=com.apple.Accessibility
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turn on Reduce motion: search for Reduce motion in System Settings."* ]]
  [ "$(value com.apple.universalaccess reduceMotion)" = absent ]
  [[ "$(cat "$REC")" != *educeMotion* ]]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  [ "$(grep -c '^killall Dock' "$STUB_LOG")" -eq 1 ]
}

@test "second Reduce motion key refused on write: the first is put back, nothing recorded" {
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  export T_DEFAULTS_REFUSE_WRITE=com.apple.Accessibility
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turn on Reduce motion: search for Reduce motion in System Settings."* ]]
  [ "$(value com.apple.universalaccess reduceMotion)" = absent ]
  [ "$(value com.apple.Accessibility ReduceMotionEnabled)" = 0 ]
  [[ "$(cat "$REC")" != *educeMotion* ]]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  [ "$(grep -c '^killall Dock' "$STUB_LOG")" -eq 1 ]
}

@test "second Reduce motion key refused on write: a present first key gets its old value back" {
  seed com.apple.universalaccess reduceMotion boolean false
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  export T_DEFAULTS_REFUSE_WRITE=com.apple.Accessibility
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.universalaccess reduceMotion)" = 0 ]
  [[ "$(cat "$REC")" != *educeMotion* ]]
}

@test "restore puts back absent and present values" {
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  : > "$STUB_LOG"
  in_lib 'settings_uninstall desktops'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.dock mru-spaces)" = absent ]
  [ "$(value NSGlobalDomain AppleSpacesSwitchOnActivate)" = absent ]
  [ "$(value com.apple.universalaccess reduceMotion)" = absent ]
  [ "$(value com.apple.Accessibility ReduceMotionEnabled)" = 0 ]
  [[ "$(stub_calls)" == *"defaults write com.apple.Accessibility ReduceMotionEnabled -int 0"* ]]
  [ ! -e "$REC" ]
  [ "$(grep -c '^killall Dock' "$STUB_LOG")" -eq 1 ]
}

@test "restore again changes nothing" {
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  in_lib 'settings_uninstall desktops'
  : > "$STUB_LOG"
  in_lib 'settings_uninstall desktops'
  [ "$status" -eq 0 ]
  [ -z "$(stub_calls)" ]
}

@test "restore only touches that answer's keys" {
  in_lib 'CHOICES[desktops]=yes; CHOICES[window_margins]=yes; settings_apply'
  in_lib 'settings_uninstall window_margins'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.WindowManager EnableTiledWindowMargins)" = absent ]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  [ "$(grep -c . "$REC")" -eq 10 ]
}

@test "restore with Reduce motion refused" {
  seed com.apple.Accessibility ReduceMotionEnabled integer 0
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  export T_DEFAULTS_REFUSE=com.apple.universalaccess
  : > "$STUB_LOG"
  in_lib 'settings_uninstall desktops'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turn off Reduce motion: search for Reduce motion in System Settings."* ]]
  [[ "$(stub_calls)" != *"com.apple.Accessibility ReduceMotionEnabled"* ]]
  [ "$(T_DEFAULTS_REFUSE= value com.apple.Accessibility ReduceMotionEnabled)" = 1 ]
  [ "$(value com.apple.dock mru-spaces)" = absent ]
  [ "$(value NSGlobalDomain AppleSpacesSwitchOnActivate)" = absent ]
  [ ! -e "$REC" ]
}

@test "restore with no Reduce motion line says omamac didn't change it" {
  in_lib 'CHOICES[window_margins]=yes; settings_apply'
  printf 'com.apple.dock\tmru-spaces\tabsent\n' > "$REC"
  in_lib 'settings_uninstall desktops'
  [ "$status" -eq 0 ]
  [[ "$output" == *"omamac didn't change Reduce motion; if you turned it on yourself, search for Reduce motion in System Settings."* ]]
}

@test "Dock cleanup sets show-recents off, once" {
  in_lib 'CHOICES[dock]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Dock cleanup"* ]]
  [ "$(value com.apple.dock show-recents)" = 0 ]
  [ "$(cat "$REC")" = "com.apple.dock${TAB}show-recents${TAB}absent" ]
  [ "$(grep -c '^killall Dock' "$STUB_LOG")" -eq 1 ]
}

@test "Dock auto-hide sets autohide on; a second run writes nothing" {
  in_lib 'CHOICES[dock_autohide]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Dock auto-hide"* ]]
  [ "$(value com.apple.dock autohide)" = 1 ]
  : > "$STUB_LOG"
  in_lib 'CHOICES[dock_autohide]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" != *"defaults write"* ]]
  [[ "$(stub_calls)" != *killall* ]]
}

@test "uninstalling Dock auto-hide deletes autohide" {
  in_lib 'CHOICES[dock_autohide]=yes; settings_apply'
  in_lib 'settings_uninstall dock_autohide'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.dock autohide)" = absent ]
  [ ! -e "$REC" ]
}

@test "fake-defaults export then import round-trips a plist" {
  export T_DEFAULTS_DIR="${T_DEFAULTS_DIR:-$BATS_TEST_TMPDIR/defaults}"
  mkdir -p "$T_DEFAULTS_DIR"
  run defaults export com.apple.dock "$BATS_TEST_TMPDIR/a.plist"
  [ "$status" -eq 0 ]
  [ -s "$BATS_TEST_TMPDIR/a.plist" ]
  plutil -insert x -string hi "$BATS_TEST_TMPDIR/a.plist"
  run defaults import com.apple.dock "$BATS_TEST_TMPDIR/a.plist"
  [ "$status" -eq 0 ]
  defaults export com.apple.dock "$BATS_TEST_TMPDIR/b.plist"
  [ "$(plutil -extract x raw "$BATS_TEST_TMPDIR/b.plist")" = hi ]
  grep -q 'defaults import com.apple.dock' "$STUB_LOG"
}

@test "fake-defaults import fails on T_DEFAULTS_FAIL" {
  defaults export com.apple.dock "$BATS_TEST_TMPDIR/a.plist"
  T_DEFAULTS_FAIL=com.apple.dock:import run defaults import com.apple.dock "$BATS_TEST_TMPDIR/a.plist"
  [ "$status" -ne 0 ]
}

@test "desktop widgets hidden on a clean Mac; a second run writes nothing" {
  in_lib 'CHOICES[desktop_widgets]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Desktop widgets"* ]]
  [ "$(value com.apple.WindowManager StandardHideWidgets)" = 1 ]
  [ "$(value com.apple.WindowManager StageManagerHideWidgets)" = 1 ]
  [ "$(cat "$REC")" = "com.apple.WindowManager${TAB}StandardHideWidgets${TAB}absent
com.apple.WindowManager${TAB}StageManagerHideWidgets${TAB}absent" ]
  [[ "$(stub_calls)" != *killall* ]]
  : > "$STUB_LOG"
  in_lib 'CHOICES[desktop_widgets]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" != *"defaults write"* ]]
}

@test "desktop widgets: uninstall puts back an earlier value and deletes an absent one" {
  seed com.apple.WindowManager StandardHideWidgets boolean false
  in_lib 'CHOICES[desktop_widgets]=yes; settings_apply'
  in_lib 'settings_uninstall desktop_widgets'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.WindowManager StandardHideWidgets)" = 0 ]
  [ "$(value com.apple.WindowManager StageManagerHideWidgets)" = absent ]
  [ ! -e "$REC" ]
}

@test "desktop widgets: Put back prints once for both keys" {
  in_lib 'CHOICES[desktop_widgets]=yes; settings_apply'
  seed com.apple.WindowManager StandardHideWidgets boolean false
  seed com.apple.WindowManager StageManagerHideWidgets boolean false
  in_lib 'CHOICES[desktop_widgets]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(grep -c 'Put back: Desktop widgets' <<< "$output")" -eq 1 ]
}

@test "Ctrl 1–6 on a clean Mac: on, reloaded once, a second run changes nothing" {
  local i
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  for i in "${!HOTKEY_IDS[@]}"; do
    [ "$(hotkey_xml "${HOTKEY_IDS[$i]}")" = "$(hotkey_on "${HOTKEY_CODES[$i]}")" ]
  done
  [ "$(grep -c '^activateSettings -u$' "$STUB_LOG")" -eq 1 ]
  : > "$STUB_LOG"
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" != *"defaults import"* ]]
  [[ "$(stub_calls)" != *activateSettings* ]]
}

@test "Ctrl 1–6: other shortcuts in the domain are left alone" {
  local before
  hotkey_seed 64 '{"enabled":false,"value":{"parameters":[32,49,1048576],"type":"standard"}}'
  before=$(hotkey_xml 64)
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(hotkey_xml 64)" = "$before" ]
}

@test "Ctrl 1–6: a shortcut that was off is recorded as it was and put back exactly" {
  local before118 before119
  hotkey_seed 118 '{"enabled":false,"value":{"parameters":[65535,18,262144],"type":"standard"}}'
  hotkey_seed 119 '{"enabled":1,"value":{"parameters":[65535,19,262144],"type":"standard"}}'
  before118=$(hotkey_xml 118)
  before119=$(hotkey_xml 119)
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(hotkey_xml 118)" = "$(hotkey_on 18)" ]
  # enabled 1 is not what omamac writes, so it is written over and recorded too.
  [ "$(hotkey_xml 119)" = "$(hotkey_on 19)" ]
  grep -q "^com.apple.symbolichotkeys${TAB}AppleSymbolicHotKeys.118${TAB}json${TAB}{" "$REC"
  : > "$STUB_LOG"
  in_lib 'settings_uninstall desktops'
  [ "$status" -eq 0 ]
  [ "$(hotkey_xml 118)" = "$before118" ]
  [ "$(hotkey_xml 119)" = "$before119" ]
  [ "$(hotkey_xml 120)" = absent ]
  [ "$(hotkey_xml 123)" = absent ]
  [ "$(grep -c '^activateSettings -u$' "$STUB_LOG")" -eq 1 ]
  [ ! -e "$REC" ]
}

@test "Ctrl 1–6 already on: not written, not recorded" {
  local i
  for i in "${!HOTKEY_IDS[@]}"; do
    hotkey_seed "${HOTKEY_IDS[$i]}" '{"enabled":true,"value":{"parameters":[65535,'"${HOTKEY_CODES[$i]}"',262144],"type":"standard"}}'
  done
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" != *"defaults import com.apple.symbolichotkeys"* ]]
  [[ "$(cat "$REC")" != *AppleSymbolicHotKeys* ]]
  [[ "$(stub_calls)" != *activateSettings* ]]
}

@test "Ctrl 1–6 changed by the user: put back, the record kept" {
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  cp "$REC" "$BATS_TEST_TMPDIR/rec.before"
  hotkey_seed 120 '{"enabled":false,"value":{"parameters":[65535,20,262144],"type":"standard"}}'
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Put back: Ctrl 1–6"* ]]
  [ "$(hotkey_xml 120)" = "$(hotkey_on 20)" ]
  cmp "$REC" "$BATS_TEST_TMPDIR/rec.before"
}

@test "Ctrl 1–6: no activateSettings, or a failing one, is only logged" {
  export OMAMAC_TEST_ACTIVATE_SETTINGS="$BATS_TEST_TMPDIR/none"
  in_lib 'OMAMAC_LOG="$HOME/log"; CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  grep -q 'the shortcuts work after the next login' "$HOME/log"
  in_lib 'settings_uninstall desktops'
  export OMAMAC_TEST_ACTIVATE_SETTINGS="$STUB_DIR/activateSettings"
  stub activateSettings 'exit 1'
  in_lib 'OMAMAC_LOG="$HOME/log"; CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  grep -q 'activateSettings -u failed' "$HOME/log"
}

@test "Ctrl 1–6: a failing import stops the run, nothing recorded" {
  export T_DEFAULTS_FAIL=com.apple.symbolichotkeys:import
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAILED: setting AppleSymbolicHotKeys.118 in com.apple.symbolichotkeys"* ]]
  [[ "$(cat "$REC")" != *AppleSymbolicHotKeys* ]]
  [ "$(hotkey_xml 118)" = absent ]
}
