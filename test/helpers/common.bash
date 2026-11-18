# Shared bats helpers. Load with `load helpers/common`.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
HELPERS_DIR="$REPO_ROOT/test/helpers"
BASH5=/opt/homebrew/bin/bash

# Give each test its own HOME, stub dir, stub log and fake Homebrew prefix.
setup_sandbox() {
  export HOME="$BATS_TEST_TMPDIR/home"
  # herdr reads this; a developer's own value must not reach the tests.
  unset HERDR_CONFIG_PATH
  export STUB_DIR="$BATS_TEST_TMPDIR/stubs"
  export STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
  export OMAMAC_TEST_BREW_PREFIX="$BATS_TEST_TMPDIR/opt/homebrew"
  export REPO_ROOT BASH5 HELPERS_DIR
  # Tests never see the real /Applications.
  export OMAMAC_TEST_APPLICATIONS="$BATS_TEST_TMPDIR/Applications"
  mkdir -p "$HOME" "$STUB_DIR" "$OMAMAC_TEST_APPLICATIONS"
  lazyvim_fixture
  : > "$STUB_LOG"
  ln -sf "$HELPERS_DIR/fake-gum" "$STUB_DIR/gum"
  # No test touches the real defaults or the real Dock.
  export T_DEFAULTS_DIR="$BATS_TEST_TMPDIR/defaults"
  mkdir -p "$T_DEFAULTS_DIR"
  ln -sf "$HELPERS_DIR/fake-defaults" "$STUB_DIR/defaults"
  stub killall
  # The terminal prompts read. fake-gum checks for this first line.
  echo fake-tty > "$BATS_TEST_TMPDIR/tty"
  export OMAMAC_TEST_TTY="$BATS_TEST_TMPDIR/tty"
  export PATH="$STUB_DIR:$PATH"
  [ -x "$BASH5" ] || { echo "missing $BASH5" >&2; return 1; }
  # shellcheck disable=SC2016 # the single quotes are meant: bash 5 expands it
  [ "$("$BASH5" -c 'echo "${BASH_VERSINFO[0]}"')" -ge 5 ] || { echo "$BASH5 is older than 5" >&2; return 1; }
}

# A tiny local LazyVim starter, so tests run offline. file:// makes --depth work.
lazyvim_fixture() {
  local repo="$BATS_TEST_TMPDIR/lazyvim-starter"
  mkdir -p "$repo/lua/config"
  echo 'require("config.lazy")' > "$repo/init.lua"
  echo '-- lazy' > "$repo/lua/config/lazy.lua"
  git -C "$repo" init -q
  git -C "$repo" add -A
  git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m fixture
  export OMAMAC_TEST_LAZYVIM_URL="file://$repo"
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

# gum_answers <line>…: fake-gum's answers, one per prompt, in order. A
# choose answer is its values separated by spaces ('' for none); a confirm
# answer is yes or no; "exit <n>" makes that prompt exit with n.
gum_answers() {
  export T_GUM_ANSWERS="$BATS_TEST_TMPDIR/gum-answers"
  rm -f "$T_GUM_ANSWERS.pos"
  if [ $# -eq 0 ]; then : > "$T_GUM_ANSWERS"; else printf '%s\n' "$@" > "$T_GUM_ANSWERS"; fi
}

# unopenable_tty <path>: a file that reads as readable but can't be opened,
# like /dev/tty with no terminal. A unix socket, as a folder opens fine on
# macOS. Bound from its folder: a socket path can't pass 104 characters.
unopenable_tty() {
  rm -f "$1"
  (cd "$(dirname "$1")" && perl -MSocket -e \
    'socket(my $s, PF_UNIX, SOCK_STREAM, 0) or die "$!"; bind($s, pack_sockaddr_un($ARGV[0])) or die "$!"' \
    "$(basename "$1")")
}

# shellcheck disable=SC2034 # used by the .bats files
# The 16 answers bats uses for a fresh run, in table order.
FRESH_ANSWERS=(tokyo-night "firefox brave" "" "" cap "" "" "" no yes no no yes "node python" gh none)

install_fake_brew() {
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/bin"
  cp "$HELPERS_DIR/fake-brew" "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
  chmod +x "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
}

# A Mac that passes every boot.sh preflight check. Tests change one fact with T_* variables.
# shellcheck disable=SC2016 # stub bodies expand when the stub runs, not here
stub_healthy_mac() {
  stub id 'case "$1" in -u) echo "${T_UID:-501}";; -un) echo tester;; -Gn) echo "${T_GROUPS:-staff admin}";; esac'
  stub sysctl 'case "$2" in hw.optional.arm64) echo "${T_ARM64:-1}";; sysctl.proc_translated) echo "${T_TRANSLATED:-0}";; esac'
  stub sw_vers 'echo "${T_MACOS:-27.1}"'
  stub dscl 'echo "UserShell: ${T_SHELL:-/bin/zsh}"'
  export OMAMAC_TEST_USR_LOCAL_BREW="$BATS_TEST_TMPDIR/usr/local/bin/brew"
}
