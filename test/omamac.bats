load helpers/common

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

@test "commands not built yet say so" {
  for c in install update theme uninstall; do
    run --separate-stderr omamac "$c"
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
    [ "$stderr" = "omamac $c isn't available yet." ]
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
  run "$BASH5" -c 'source "$REPO_ROOT/lib/ui.sh"; ui_run t bash -c "echo out; exit 3"'
  [ "$status" -eq 3 ]
  grep -q out "$OMAMAC_LOG"
  [[ "$output" == *"Log:"* ]]
}

@test "ui_run logs stdout and stderr" {
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/l"
  run "$BASH5" -c 'source "$REPO_ROOT/lib/ui.sh"; ui_run t bash -c "echo out; echo err >&2; exit 3"'
  [ "$status" -eq 3 ]
  grep -q out "$OMAMAC_LOG"
  grep -q err "$OMAMAC_LOG"
}
