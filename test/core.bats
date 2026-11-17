load helpers/common

bats_require_minimum_version 1.5.0

ALL="starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq"

setup() {
  setup_sandbox
  install_fake_brew
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
}

# in_lib <code>: run bash 5 code with the core list loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/core.sh'
    $1"
}

# have <formula>…: mark formulas as already installed.
have() { local f; for f in "$@"; do mkdir -p "$OMAMAC_TEST_BREW_PREFIX/Cellar/$f"; done; }

@test "the core list is the spec's" {
  in_lib 'echo "${CORE_FORMULAS[*]}"'
  [ "$output" = "$ALL" ]
}

@test "fresh: one brew install with every core formula" {
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Core tools are installed"* ]]
  [ "$(grep -c '^brew install' "$STUB_LOG")" -eq 1 ]
  grep -qx "brew install $ALL" "$STUB_LOG"
  [ "$(grep -c '^brew list' "$STUB_LOG")" -eq 1 ]
}

@test "all present: no brew install at all" {
  # shellcheck disable=SC2086 # the list is words
  have $ALL
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Core tools are installed"* ]]
  run ! grep -q '^brew install' "$STUB_LOG"
}

@test "one removed: installs only that one" {
  # shellcheck disable=SC2086
  have $ALL
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Cellar/eza"
  in_lib 'core_missing'
  [ "$output" = "eza" ]
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  grep -qx "brew install eza" "$STUB_LOG"
  [ "$(grep -c '^brew install' "$STUB_LOG")" -eq 1 ]
}

@test "brew can't list: fails, installs nothing" {
  T_BREW_LIST_FAIL=1 in_lib 'core_install'
  [ "$status" -ne 0 ]
  [[ "$output" != *"Core tools are installed"* ]]
  run ! grep -q '^brew install' "$STUB_LOG"
}

@test "a brew failure returns non-zero and shows the log" {
  T_BREW_FAIL=1 in_lib 'core_install'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Log:"* ]]
  [[ "$output" != *"Core tools are installed"* ]]
}
