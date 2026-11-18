load helpers/common

bats_require_minimum_version 1.5.0

setup() { setup_sandbox; }

omamac() { "$BASH5" "$REPO_ROOT/bin/omamac" "$@"; }

@test "no args prints usage" {
  run omamac
  [ "$status" -eq 0 ]
  for w in install update theme doctor uninstall; do [[ "$output" == *"$w"* ]]; done
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

@test@test "unknown command" {
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

@test "ui_run without gum still logs and returns the status" {
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/l"
  rm "$STUB_DIR/gum"
  run "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/ui.sh"; ui_run t bash -c "echo out; exit 3"'
  [ "$status" -eq 3 ]
  grep -q out "$OMAMAC_LOG"
  [[ "$output" == *"✗ Log:"* ]]
}
