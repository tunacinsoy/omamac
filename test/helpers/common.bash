# Shared bats helpers. Load with `load helpers/common`.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
HELPERS_DIR="$REPO_ROOT/test/helpers"
BASH5=/opt/homebrew/bin/bash

# Give each test its own HOME, stub dir, stub log and fake Homebrew prefix.
setup_sandbox() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_DIR="$BATS_TEST_TMPDIR/stubs"
  export STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
  export OMAMAC_TEST_BREW_PREFIX="$BATS_TEST_TMPDIR/opt/homebrew"
  export REPO_ROOT BASH5 HELPERS_DIR
  mkdir -p "$HOME" "$STUB_DIR"
  : > "$STUB_LOG"
  ln -sf "$HELPERS_DIR/fake-gum" "$STUB_DIR/gum"
  export PATH="$STUB_DIR:$PATH"
  [ -x "$BASH5" ] || { echo "missing $BASH5" >&2; return 1; }
  # shellcheck disable=SC2016 # the single quotes are meant: bash 5 expands it
  [ "$("$BASH5" -c 'echo "${BASH_VERSINFO[0]}"')" -ge 5 ] || { echo "$BASH5 is older than 5" >&2; return 1; }
}

# stub <name> [<bash body>]: a command that logs "<name> <args>" then runs the body.
# A real #!/bin/bash script (not a function) so it survives exec and bash 3.2 callers.
stub() {
  local name="$1" body="${2:-exit 0}"
  {
    printf '#!/bin/bash\n'
    # shellcheck disable=SC2016 # $* and $STUB_LOG must expand when the stub runs
    printf 'echo "%s $*" >> "$STUB_LOG"\n' "$name"
    printf '%s\n' "$body"
  } > "$STUB_DIR/$name"
  chmod +x "$STUB_DIR/$name"
}

stub_calls() { cat "$STUB_LOG"; }

install_fake_brew() {
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/bin"
  cp "$HELPERS_DIR/fake-brew" "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
  chmod +x "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
}

# A Mac that passes every boot.sh preflight check. Tests change one fact with T_* variables.
stub_healthy_mac() {
  stub id 'case "$1" in -u) echo "${T_UID:-501}";; -un) echo tester;; -Gn) echo "${T_GROUPS:-staff admin}";; esac'
  stub sysctl 'case "$2" in hw.optional.arm64) echo "${T_ARM64:-1}";; sysctl.proc_translated) echo "${T_TRANSLATED:-0}";; esac'
  stub sw_vers 'echo "${T_MACOS:-27.1}"'
  stub dscl 'echo "UserShell: ${T_SHELL:-/bin/zsh}"'
  : > "$BATS_TEST_TMPDIR/tty"
  export OMAMAC_TEST_TTY="$BATS_TEST_TMPDIR/tty"
  export OMAMAC_TEST_USR_LOCAL_BREW="$BATS_TEST_TMPDIR/usr/local/bin/brew"
}
