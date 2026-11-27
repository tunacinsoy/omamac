load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install bash gum
  export TMPDIR="$BATS_TEST_TMPDIR"
  OM="$HOME/.config/omamac"
  SIZE_FILE="$HOME/.local/state/omamac/font-size"
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  stub ps
  stub herdr
}

teardown() { chmod -R u+w "$HOME" 2>/dev/null || true; }

# omamac_font_size [<arg>…]: omamac font-size, only ever in the sandbox.
omamac_font_size() {
  if [ -z "${BATS_TEST_TMPDIR:-}" ] || [[ $HOME != "$BATS_TEST_TMPDIR"/* ]]; then
    echo "fontsize_cmd.bats: HOME isn't the sandbox; not running omamac font-size" >&2
    return 1
  fi
  "$BASH5" "$REPO_ROOT/bin/omamac" font-size "$@"
}

# listener <file>: a process that writes "reloaded" to <file> on SIGUSR2; prints its pid.
listener() {
  bash -c 'trap "echo reloaded > \"$1\"; exit 0" USR2; while :; do sleep 0.1; done' _ "$1" > /dev/null 2>&1 &
  echo $!
}

LABELS='10:10 11  more on screen:11 12:12 13:13 14  laptop:14 15:15 16  external monitor:16 17:17 18  monitor further away:18 19:19 20  presenting or sharing your screen:20 Default:default'

@test "font-size 16: saved, written, reloaded, one line" {
  local g i
  g=$(listener "$BATS_TEST_TMPDIR/ghostty")
  stub ps "printf '%s\\n' '  $g /Applications/Ghostty.app/Contents/MacOS/ghostty'"
  run omamac_font_size 16
  [ "$status" -eq 0 ]
  [ "$(<"$SIZE_FILE")" = 16 ]
  grep -qx 'font-size = 16' "$OM/ghostty.conf"
  [ "$output" = "✓ Font size: 16" ]
  for i in $(seq 50); do [ -e "$BATS_TEST_TMPDIR/ghostty" ] && break; sleep 0.1; done
  kill "$g" 2> /dev/null || true
  [ "$(<"$BATS_TEST_TMPDIR/ghostty")" = reloaded ]
}

@test "font-size default removes the size" {
  run omamac_font_size 16
  [ "$status" -eq 0 ]
  run omamac_font_size default
  [ "$status" -eq 0 ]
  [ ! -e "$SIZE_FILE" ]
  ! grep -q '^font-size' "$OM/ghostty.conf"
  [ "$output" = "✓ Font size: Default" ]
}

@test "font-size rejects near-numbers" {
  local v
  for v in 9 21 016 16.5 ' 16' abc ''; do
    run omamac_font_size "$v"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Font sizes are 10 to 20, or default."* ]]
    [ ! -e "$SIZE_FILE" ]
  done
}

@test "font-size with two arguments prints usage" {
  run omamac_font_size 16 17
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "font-size with no saved answers stops" {
  rm "$CHOICES_FILE"
  run omamac_font_size 16
  [ "$status" -eq 1 ]
  [[ "$output" == *"doesn't know your answers"* ]]
  [ ! -e "$SIZE_FILE" ]
}

@test "the picker starts on the current size" {
  echo 16 > "$SIZE_FILE"
  gum_answers 18
  run omamac_font_size
  [ "$status" -eq 0 ]
  [ "$(grep '^gum choose' "$STUB_LOG")" = "gum choose --header Which size? --label-delimiter=: --selected=16  external monitor $LABELS" ]
  [ "$(<"$SIZE_FILE")" = 18 ]
  [ "$output" = "✓ Font size: 18" ]
}

@test "the picker starts on Default with no size" {
  gum_answers default
  run omamac_font_size
  [ "$status" -eq 0 ]
  grep -q -- '^gum choose --header Which size? --label-delimiter=: --selected=Default 10:10 ' "$STUB_LOG"
  [ ! -e "$SIZE_FILE" ]
}

@test "Esc at the picker changes nothing" {
  run omamac_font_size 16
  local before
  before=$(stat -f %m "$OM/ghostty.conf")
  sleep 1
  gum_answers "exit 1"
  run omamac_font_size
  [ "$status" -eq 130 ]
  [ "$(<"$SIZE_FILE")" = 16 ]
  [ "$(stat -f %m "$OM/ghostty.conf")" = "$before" ]
}

@test "font-size never touches the user's Ghostty config" {
  mkdir -p "$HOME/.config/ghostty"
  echo 'font-size = 14' > "$HOME/.config/ghostty/config"
  cp "$HOME/.config/ghostty/config" "$BATS_TEST_TMPDIR/before"
  run omamac_font_size 17
  [ "$status" -eq 0 ]
  cmp "$HOME/.config/ghostty/config" "$BATS_TEST_TMPDIR/before"
}

@test "terminal look: one Font size row, nothing about Ghostty" {
  terminal_look
  run omamac_font_size 17
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | uncoloured)" = "  ✓ Font size       17" ]
}
