load helpers/common

MSG="herdr didn't start, so this is a plain zsh window. Run omamac doctor to see why."

setup() {
  setup_sandbox
  # Only the stubs and the system tools: no real herdr or zsh from Homebrew.
  PATH="$STUB_DIR:/usr/bin:/bin"
  stub zsh
  # The launcher is a login shell: macOS's path_helper puts /usr/bin before the stubs.
  # A .zprofile puts them back, as a user's .zprofile puts Homebrew first.
  printf 'export PATH="%s:$PATH"\n' "$STUB_DIR" > "$HOME/.zprofile"
}

@test "herdr exits 0: the window closes" {
  stub herdr 'exit 0'
  run "$REPO_ROOT/bin/omamac-terminal"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qx 'herdr ' "$STUB_LOG"
  ! grep -q '^zsh' "$STUB_LOG"
}

@test "herdr exits 1: zsh with one line" {
  stub herdr 'exit 1'
  run "$REPO_ROOT/bin/omamac-terminal"
  [ "$output" = "$MSG" ]
  grep -qx 'zsh -l' "$STUB_LOG"
}

@test "no herdr: zsh with one line" {
  run "$REPO_ROOT/bin/omamac-terminal"
  [ "$output" = "$MSG" ]
  grep -qx 'zsh -l' "$STUB_LOG"
}
