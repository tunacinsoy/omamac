#!/usr/bin/env bats
# boot.sh after preflight: log, password, Homebrew, bash and gum, checkout, restart.

bats_require_minimum_version 1.5.0
load helpers/common

setup() {
  setup_sandbox
  stub_healthy_mac
  # shellcheck disable=SC2016 # the stub expands $1 itself
  stub sudo 'if [ "$1" = -v ] && [ -n "${T_SUDO_FAIL:-}" ]; then exit 1; fi'
  # The "installer" puts the fake brew in place, like Homebrew's would.
  stub curl 'if [ -n "${T_CURL_FAIL:-}" ]; then exit 6; fi
echo "mkdir -p \"\$OMAMAC_TEST_BREW_PREFIX/bin\"; cp \"\$HELPERS_DIR/fake-brew\" \"\$OMAMAC_TEST_BREW_PREFIX/bin/brew\""'
  # Logs, then runs the real git. Like a fresh Mac, it fails until Homebrew's installer has run.
  stub git '[ -x "$OMAMAC_TEST_BREW_PREFIX/bin/brew" ] || { echo "git ran before Homebrew" >&2; exit 1; }
[ -z "${T_GIT_BROKEN:-}" ] || exit 1
exec /usr/bin/git "$@"'

  export RAN="$BATS_TEST_TMPDIR/ran"
  export REMOTE="$BATS_TEST_TMPDIR/remote.git"
  export HOME_CHECKOUT="$HOME/.local/share/omamac"
  git_real() { /usr/bin/git -c user.name=t -c user.email=t@t "$@"; }
  git_real init -q --bare -b main "$REMOTE"
  git_real clone -q "$REMOTE" "$BATS_TEST_TMPDIR/work" 2>/dev/null
  local b
  for b in main feature; do
    git_real -C "$BATS_TEST_TMPDIR/work" checkout -q -B "$b"
    printf '#!/bin/bash\necho ran-%s > "%s"\n' "$b" "$RAN" > "$BATS_TEST_TMPDIR/work/install.sh"
    git_real -C "$BATS_TEST_TMPDIR/work" add install.sh
    git_real -C "$BATS_TEST_TMPDIR/work" commit -q -m "install $b"
    git_real -C "$BATS_TEST_TMPDIR/work" push -q origin "$b"
  done
  export OMAMAC_TEST_REPO_URL="$REMOTE"
  export OMAMAC_TEST_BREW_INSTALLER_URL=https://example.test/install.sh
}

run_boot() { run /bin/bash -c 'cat "$REPO_ROOT/boot.sh" | /bin/bash'; }

# Line number of the first stub call matching a pattern; fails if none.
call_line() { stub_calls | grep -n -m1 -E "$1" | cut -d: -f1 | grep .; }

@test "fresh Mac: everything in order" {
  run_boot
  [ "$status" -eq 0 ]
  local a b c d e
  a=$(call_line '^sudo -v$')
  b=$(call_line '^curl .*https://example.test/install.sh')
  c=$(call_line '^brew install bash$')
  d=$(call_line '^brew install gum$')
  e=$(call_line '^git clone ')
  [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && [ "$c" -lt "$d" ] && [ "$d" -lt "$e" ]
  [ "$(cat "$RAN")" = ran-main ]
  [ "$(ls "$HOME/.local/state/omamac/logs" | wc -l)" -eq 1 ]
}

@test "no git before Homebrew" {
  # The git stub fails if brew is missing; a clean run proves it wasn't called early.
  run_boot
  [ "$status" -eq 0 ]
  [[ "$output" != *"git ran before Homebrew"* ]]
}

@test "re-run: no installer, no installs, fast-forward" {
  run_boot
  [ "$status" -eq 0 ]
  git_real -C "$BATS_TEST_TMPDIR/work" checkout -q main
  : > "$BATS_TEST_TMPDIR/work/new.txt"
  git_real -C "$BATS_TEST_TMPDIR/work" add new.txt
  git_real -C "$BATS_TEST_TMPDIR/work" commit -q -m new
  git_real -C "$BATS_TEST_TMPDIR/work" push -q origin main
  : > "$STUB_LOG"
  run_boot
  [ "$status" -eq 0 ]
  run ! grep -Eq '^(curl|brew install)' "$STUB_LOG"
  [ -e "$HOME_CHECKOUT/new.txt" ]
}

@test "OMAMAC_REF picks the branch" {
  OMAMAC_REF=feature run_boot
  [ "$status" -eq 0 ]
  [ "$(cat "$RAN")" = ran-feature ]
}

@test "OMAMAC_REF can switch an existing checkout" {
  run_boot
  OMAMAC_REF=feature run_boot
  [ "$status" -eq 0 ]
  [ "$(cat "$RAN")" = ran-feature ]
}

@test "unknown ref stops untouched" {
  OMAMAC_REF=nope run_boot
  [ "$status" -eq 1 ]
  [[ "$output" == *"nope"* && "$output" == *"isn't on GitHub"* ]]
  [ ! -e "$HOME_CHECKOUT" ]
  [ ! -e "$RAN" ]
}

@test "empty checkout folder is treated as missing" {
  mkdir -p "$HOME_CHECKOUT"
  run_boot
  [ "$status" -eq 0 ]
  [ "$(cat "$RAN")" = ran-main ]
}

@test "foreign git checkout stops untouched" {
  git_real init -q "$HOME_CHECKOUT"
  git_real -C "$HOME_CHECKOUT" remote add origin https://example.test/other.git
  run_boot
  [ "$status" -eq 1 ]
  [[ "$output" == *"$HOME_CHECKOUT"* ]]
  [ ! -e "$RAN" ]
  [ "$(git_real -C "$HOME_CHECKOUT" remote get-url origin)" = https://example.test/other.git ]
}

@test "non-empty folder that isn't a checkout stops untouched" {
  mkdir -p "$HOME_CHECKOUT"
  echo mine > "$HOME_CHECKOUT/notes.txt"
  run_boot
  [ "$status" -eq 1 ]
  [[ "$output" == *"$HOME_CHECKOUT"* ]]
  [ "$(ls -A "$HOME_CHECKOUT")" = notes.txt ]
  [ ! -e "$RAN" ]
}

@test "wrong password stops before anything" {
  T_SUDO_FAIL=1 run_boot
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac needs your admin password"* ]]
  run ! grep -q '^curl' "$STUB_LOG"
}

@test "no network: omamac's help, not curl's" {
  T_CURL_FAIL=1 run_boot
  [ "$status" -eq 1 ]
  [[ "$output" == *"couldn't reach"* && "$output" == *"githubstatus.com"* ]]
}

@test "Command Line Tools missing after Homebrew stops" {
  T_GIT_BROKEN=1 run_boot
  [ "$status" -eq 1 ]
  [[ "$output" == *"Apple's Command Line Tools didn't install."* ]]
}

@test "keeps only the newest 10 logs" {
  local dir="$HOME/.local/state/omamac/logs" i
  mkdir -p "$dir"
  for i in $(seq 1 12); do : > "$dir/$(printf '20200101T0000%02dZ' "$i").log"; done
  run_boot
  [ "$status" -eq 0 ]
  [ "$(ls "$dir" | wc -l)" -eq 10 ]
  [ ! -e "$dir/20200101T000001Z.log" ]
}

@test "sudo keep-alive ends with the run" {
  run_boot
  [ "$status" -eq 0 ]
  local i
  for i in $(seq 1 20); do
    pgrep -f "$STUB_DIR/sudo -n true" > /dev/null || return 0
    sleep 0.5
  done
  echo "keep-alive still running" >&2
  return 1
}
