load helpers/common

bats_require_minimum_version 1.5.0

setup() { setup_sandbox; }

# am <app path>: app_management_ok with omamac's libraries.
am() {
  "$BASH5" -c "set -Eeuo pipefail
    source '$REPO_ROOT/lib/appmanagement.sh'
    app_management_ok \"\$1\"" _ "$1"
}

@test "allowed: 0, and no write test file is left" {
  app="$BATS_TEST_TMPDIR/Applications/Ghostty.app"
  mkdir -p "$app"
  run --separate-stderr am "$app"
  [ "$status" -eq 0 ]
  [ ! -e "$app/.omamac-write-test" ]
}

@test "Operation not permitted: 1, and prints nothing" {
  stub touch 'echo "touch: $2: Operation not permitted" >&2; exit 1'
  run --separate-stderr am "$BATS_TEST_TMPDIR/Applications/Ghostty.app"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "any other failure: 2, with the reason on stderr" {
  stub touch 'echo "touch: $2: No such file or directory" >&2; exit 1'
  run --separate-stderr am "$BATS_TEST_TMPDIR/Applications/Ghostty.app"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"No such file or directory"* ]]
}
