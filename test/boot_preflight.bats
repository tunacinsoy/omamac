#!/usr/bin/env bats
# boot.sh preflight: banner and the checks that run before anything changes.

bats_require_minimum_version 1.5.0
load helpers/common

setup() {
  setup_sandbox
  stub_healthy_mac
  # Commands that must never run during preflight.
  stub sudo
  stub curl
  stub brew
  stub git
}

run_boot() { run --separate-stderr /bin/bash -c 'cat "$REPO_ROOT/boot.sh" | /bin/bash'; }

# The failure was stopped before anything changed.
assert_stopped() {
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"omamac: "* ]]
  [[ "$stderr" == *"$1"* ]]
  ! stub_calls | grep -Eq '^(sudo|curl|brew|git)( |$)'
}

@test "a healthy Mac passes preflight" {
  run_boot
  # The stubs can't install Homebrew, so the run ends later; what matters is
  # that every check passed and the password step began.
  [[ "$stderr" != *"needs a terminal"* && "$stderr" != *"Run this as your normal user"* ]]
  stub_calls | grep -qx 'sudo -v'
}

@test "banner says what will happen and how to stop" {
  run_boot
  [[ "$output" == *"Ctrl-C"* ]]
}

@test "root is refused" {
  T_UID=0 run_boot
  assert_stopped "Run this as your normal user, not as root."
}

@test "Intel is refused" {
  T_ARM64=0 run_boot
  assert_stopped "omamac needs a Mac with Apple Silicon."
}

@test "Rosetta is refused" {
  T_TRANSLATED=1 run_boot
  assert_stopped "Terminal is running under Rosetta."
}

@test "macOS 26 is refused" {
  T_MACOS=26.4 run_boot
  assert_stopped "omamac needs macOS 27 or later. This Mac has 26.4."
}

@test "a non-admin user is refused" {
  T_GROUPS=staff run_boot
  assert_stopped "omamac needs an administrator account."
}

@test "Homebrew in /usr/local is refused" {
  mkdir -p "$(dirname "$OMAMAC_TEST_USR_LOCAL_BREW")"
  : > "$OMAMAC_TEST_USR_LOCAL_BREW"
  run_boot
  assert_stopped "https://docs.brew.sh/Installation"
}

@test "a login shell other than zsh is refused" {
  T_SHELL=/bin/bash run_boot
  assert_stopped "chsh -s /bin/zsh"
}

@test "no terminal is refused" {
  export OMAMAC_TEST_TTY="$BATS_TEST_TMPDIR/nonexistent"
  run_boot
  assert_stopped "omamac needs a terminal to ask for your password."
}
