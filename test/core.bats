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

# have_cask <cask>: mark a cask as installed through Homebrew.
have_cask() { mkdir -p "$OMAMAC_TEST_BREW_PREFIX/Caskroom/$1"; }

@test "the core list is the spec's" {
  in_lib 'echo "${CORE_FORMULAS[*]}"'
  [ "$output" = "$ALL" ]
}

@test "fresh: one brew install with every core formula" {
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Core tools are installed"* ]]
  grep -qx "brew install $ALL" "$STUB_LOG"
  [ "$(grep -c '^brew install' "$STUB_LOG")" -eq 2 ]
  [ "$(grep -c '^brew list --formula' "$STUB_LOG")" -eq 1 ]
}

@test "all present: no brew install at all" {
  # shellcheck disable=SC2086 # the list is words
  have $ALL
  have_cask ghostty
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Core tools are installed"* ]]
  run ! grep -q '^brew install' "$STUB_LOG"
}

@test "one removed: installs only that one" {
  # shellcheck disable=SC2086
  have $ALL
  have_cask ghostty
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

@test "fresh: one cask install for Ghostty" {
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^brew install --cask' "$STUB_LOG")" -eq 1 ]
  grep -qx "brew install --cask ghostty" "$STUB_LOG"
  [ "$(grep -n '^brew install' "$STUB_LOG" | tail -1 | cut -d: -f2-)" = "brew install --cask ghostty" ]
}

@test "Ghostty from Homebrew: no cask install" {
  have_cask ghostty
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  run ! grep -q 'install --cask' "$STUB_LOG"
}

@test "Ghostty by hand: used as it is" {
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/Ghostty.app"
  in_lib 'core_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ghostty is already installed, not through Homebrew"* ]]
  run ! grep -q 'install --cask' "$STUB_LOG"
}

@test "core_cask_state" {
  in_lib 'core_cask_state ghostty'
  [ "$output" = missing ]
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/Ghostty.app"
  in_lib 'core_cask_state ghostty'
  [ "$output" = hand ]
  have_cask ghostty
  in_lib 'core_cask_state ghostty'
  [ "$output" = brew ]
  T_BREW_LIST_FAIL=1 in_lib 'core_cask_state ghostty'
  [ "$status" -ne 0 ]
}
