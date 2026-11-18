load helpers/common

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
    source '$REPO_ROOT/lib/settings.sh'
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
  [[ "$output" == *"Put back: mru-spaces"* ]]
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

@test "record with a key from an earlier run is never rewritten" {
  mkdir -p "$(dirname "$REC")"
  printf 'com.apple.dock\tmru-spaces\tboolean\ttrue\n' > "$REC"
  seed com.apple.dock mru-spaces boolean true
  in_lib 'CHOICES[desktops]=yes; settings_apply'
  [ "$status" -eq 0 ]
  [ "$(value com.apple.dock mru-spaces)" = 0 ]
  [[ "$output" == *"Put back: mru-spaces"* ]]
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
