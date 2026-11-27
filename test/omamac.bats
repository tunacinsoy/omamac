load helpers/common

bats_require_minimum_version 1.5.0

setup() { setup_sandbox; }

omamac() { "$BASH5" "$REPO_ROOT/bin/omamac" "$@"; }

@test "no args prints usage" {
  run omamac
  [ "$status" -eq 0 ]
  for w in install update theme doctor uninstall configure; do [[ "$output" == *"$w"* ]]; done
}

@test "usage names configure and the commands doc" {
  run omamac help
  [[ "$output" == *"  configure   Turn a macOS setting on or off"* ]]
  [[ "$output" == *"With no command, omamac asks what you want to do."* ]]
  [[ "$output" == *"docs/commands.md"* ]]
}

# menu_look: what a terminal has: the terminal look, gum and the tty.
menu_look() {
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
  export OMAMAC_TEST_UI_TERMINAL=1 TMPDIR="$BATS_TEST_TMPDIR"
  : > "$STUB_LOG"
}

@test "no args in a terminal: asks what to do" {
  menu_look
  gum_answers "exit 1"
  run omamac
  [ "$status" -eq 130 ]
  [ "$(grep '^gum choose' "$STUB_LOG")" = "gum choose --header What do you want to do? --label-delimiter=: Install something:install Remove something:uninstall Change a macOS setting:configure Switch the theme:theme Change the font size:font-size Update everything:update Check everything:doctor" ]
  [[ "$output" != *"Usage:"* ]]
}

@test "no args in a terminal: the pick runs that command" {
  menu_look
  # No saved answers, so each command stops at once, in its own words.
  for cmd in install uninstall configure theme; do
    gum_answers "$cmd"
    run omamac
    [ "$status" -eq 1 ]
    [[ "$output" == *"omamac doesn't know your answers. Fix: run the one-liner."* ]]
  done
  [ "$(grep -c '^gum choose' "$STUB_LOG")" -eq 4 ]
  # doctor reports and exits 1 on the missing answers; update stops on the
  # checkout it can't pull, with its own fix.
  gum_answers doctor
  run omamac
  [ "$status" -eq 1 ]
  [[ "$output" == *"Your answers"* ]]
  gum_answers update
  run omamac
  [ "$status" -ne 0 ]
  [[ "$output" == *"check your internet connection"* ]]
}

@test "no args in a terminal: a broken prompt says to run omamac again" {
  menu_look
  gum_answers "exit 3"
  run omamac
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac couldn't ask about What do you want to do?. Run omamac again."* ]]
  [[ "$output" != *"one-liner"* ]]
}

@test "no args in a terminal: Change a macOS setting opens configure's menu" {
  menu_look
  mkdir -p "$HOME/.local/state/omamac"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$HOME/.local/state/omamac/choices.env"
  gum_answers configure "exit 130"
  run omamac
  [ "$status" -eq 130 ]
  grep -q '^gum choose --header What do you want to change?' "$STUB_LOG"
}

@test "no args in a terminal: Change the font size opens its picker" {
  menu_look
  mkdir -p "$HOME/.local/state/omamac"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$HOME/.local/state/omamac/choices.env"
  gum_answers font-size "exit 130"
  run omamac
  [ "$status" -eq 130 ]
  grep -q '^gum choose --header Which size?' "$STUB_LOG"
}

@test "no args with the terminal look but no terminal to ask in: usage" {
  menu_look
  unopenable_tty "$BATS_TEST_TMPDIR/tty"
  gum_answers
  run omamac
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: omamac <command>"* ]]
  run ! grep -q '^gum choose' "$STUB_LOG"
}

@test "help, -h and --help print the same usage" {
  run omamac
  base=$output
  for a in help -h --help; do
    run omamac "$a"
    [ "$status" -eq 0 ]
    [ "$output" = "$base" ]
  done
}

@test "unknown command" {
  run --separate-stderr omamac frob
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Unknown command: frob"* ]]
  [[ "$stderr" == *"Usage: omamac <command>"* ]]
}

@test "ui_run logs output and returns the status" {
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/l"
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
  run "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/ui.sh"; ui_run t bash -c "echo out; exit 3"'
  [ "$status" -eq 3 ]
  grep -q out "$OMAMAC_LOG"
  [[ "$output" == *"Log:"* ]]
}

@test "ui_run logs stdout and stderr" {
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/l"
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
  run "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/ui.sh"; ui_run t bash -c "echo out; echo err >&2; exit 3"'
  [ "$status" -eq 3 ]
  grep -q out "$OMAMAC_LOG"
  grep -q err "$OMAMAC_LOG"
}

@test "ui_run_open names the step, logs both streams and returns the status" {
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/l"
  run "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/ui.sh"; ui_run_open "Doing it" bash -c "echo out; echo err >&2; exit 3"'
  [ "$status" -eq 3 ]
  [[ "$output" == *"Doing it"* ]]
  [[ "$output" == *"✗ Log: $OMAMAC_LOG"* ]]
  grep -q out "$OMAMAC_LOG"
  grep -q err "$OMAMAC_LOG"
}

@test "ui_run_open never uses gum spin" {
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/l"
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
  : > "$STUB_LOG"
  run "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/ui.sh"; ui_run_open t true'
  [ "$status" -eq 0 ]
  run ! grep -q '^gum spin' "$STUB_LOG"
}

@test "ui_run without gum still logs and returns the status" {
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/l"
  rm "$STUB_DIR/gum"
  run "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/ui.sh"; ui_run t bash -c "echo out; exit 3"'
  [ "$status" -eq 3 ]
  grep -q out "$OMAMAC_LOG"
  [[ "$output" == *"✗ Log:"* ]]
}
