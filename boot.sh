#!/bin/bash
# omamac's one-liner target: curl -fsSL .../boot.sh | bash
# Runs under macOS's /bin/bash 3.2, so no bash 4+ features. No sourced-vs-executed
# guard: BASH_SOURCE is empty when piped and `set -u` would abort.
set -euo pipefail

# These repeat lib/paths.sh on purpose: boot.sh arrives alone through the pipe
# and can't source lib/. The OMAMAC_TEST_* variables are test seams.
BOOT_BREW_INSTALLER_URL=${OMAMAC_TEST_BREW_INSTALLER_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}
BOOT_REPO_URL=${OMAMAC_TEST_REPO_URL:-https://github.com/tunacinsoy/omamac}
BOOT_BREW_PREFIX=${OMAMAC_TEST_BREW_PREFIX:-/opt/homebrew}
BOOT_USR_LOCAL_BREW=${OMAMAC_TEST_USR_LOCAL_BREW:-/usr/local/bin/brew}
BOOT_TTY=${OMAMAC_TEST_TTY:-/dev/tty}
BOOT_REF=${OMAMAC_REF:-main}
OMAMAC_HOME=${OMAMAC_HOME:-$HOME/.local/share/omamac}

boot_die() {
  echo "omamac: $*" >&2
  exit 1
}

boot_banner() {
  echo "omamac will install Homebrew and a few tools, then the omamac command."
  echo "It asks for your password once."
  echo "Press Ctrl-C to stop."
}

boot_preflight() {
  local version shell

  [ "$(id -u)" -ne 0 ] || boot_die "Run this as your normal user, not as root."

  [ "$(sysctl -in hw.optional.arm64)" = 1 ] || boot_die "omamac needs a Mac with Apple Silicon."
  [ "$(sysctl -in sysctl.proc_translated)" != 1 ] ||
    boot_die "Terminal is running under Rosetta. Quit it, turn off \"Open using Rosetta\" in its Get Info, and run this again."

  version=$(sw_vers -productVersion)
  [ "${version%%.*}" -ge 27 ] || boot_die "omamac needs macOS 27 or later. This Mac has $version."

  case " $(id -Gn) " in
    *" admin "*) ;;
    *) boot_die "omamac needs an administrator account." ;;
  esac

  [ ! -e "$BOOT_USR_LOCAL_BREW" ] ||
    boot_die "Homebrew is installed in /usr/local. omamac needs it in $BOOT_BREW_PREFIX. See https://docs.brew.sh/Installation"

  shell=$(dscl . -read "/Users/$(id -un)" UserShell | sed -n 's/^UserShell: //p')
  case "$shell" in
    */zsh) ;;
    *) boot_die "Your login shell is ${shell:-unknown}, not zsh. Run: chsh -s /bin/zsh, open a new terminal, and run this again." ;;
  esac

  # Stdin is the script, so the password prompt needs the terminal.
  { : < "$BOOT_TTY"; } 2>/dev/null || boot_die "omamac needs a terminal to ask for your password."
}

# One log per run. install.sh appends to the same file through OMAMAC_LOG.
boot_log_start() {
  local dir="$HOME/.local/state/omamac/logs" old
  mkdir -p "$dir"
  OMAMAC_LOG="$dir/$(date -u +%Y%m%dT%H%M%SZ).log"
  : > "$OMAMAC_LOG"
  export OMAMAC_LOG
  # Names sort by time, so everything after the newest 10 is old.
  # shellcheck disable=SC2012 # our own names are plain, and ls sorts them
  # shellcheck disable=SC2012 # our own names are plain, and ls sorts them
  ls -1 "$dir" | sort -r | tail -n +11 | while IFS= read -r old; do
    rm -f "$dir/$old"
  done
}

# A step failed and the log has the details.
boot_die_log() {
  echo "omamac: $*" >&2
  tail -n 20 "$OMAMAC_LOG" >&2
  echo "Full log: $OMAMAC_LOG" >&2
  exit 1
}

boot_network_help() {
  boot_die "couldn't reach GitHub. Check that:
  - your Mac is connected to the internet
  - your network isn't blocking github.com
  - GitHub is up: https://www.githubstatus.com
Then run this again."
}

boot_sudo() {
  # sudo reads the password from the terminal itself, never from the pipe.
  sudo -v || boot_die "omamac needs your admin password. Run this again and enter it."
  # Keeps sudo valid until this process ends. install.sh replaces this shell with
  # exec, so $$ stays the same for the whole run. Wakes every 5 s so it stops soon
  # after the run does; sudo -n true is cheap.
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true || exit 0; sleep 5; done ) > /dev/null 2>&1 &
}

boot_homebrew() {
  local script
  if [ ! -x "$BOOT_BREW_PREFIX/bin/brew" ]; then
    echo "Installing Homebrew and Apple's Command Line Tools (this can take 10 minutes)…"
    script=$(curl -fsSL "$BOOT_BREW_INSTALLER_URL" 2>> "$OMAMAC_LOG") || boot_network_help
    NONINTERACTIVE=1 /bin/bash -c "$script" >> "$OMAMAC_LOG" 2>&1 ||
      boot_die_log "Homebrew's installer failed."
    [ -x "$BOOT_BREW_PREFIX/bin/brew" ] || boot_die_log "Homebrew's installer finished but brew is missing."
  fi
  eval "$("$BOOT_BREW_PREFIX/bin/brew" shellenv)"
  # Only now is git safe to call: before this, a fresh Mac's git opens an install dialog.
  git --version > /dev/null 2>&1 || boot_die "Apple's Command Line Tools didn't install. Run: xcode-select --install, then run this again."
}

boot_formulas() {
  local f
  for f in bash gum; do
    "$BOOT_BREW_PREFIX/bin/brew" list --formula "$f" > /dev/null 2>&1 && continue
    echo "Installing ${f}…"
    "$BOOT_BREW_PREFIX/bin/brew" install "$f" >> "$OMAMAC_LOG" 2>&1 ||
      boot_die_log "Homebrew couldn't install $f."
  done
}

# Stops unless the ref exists on GitHub; ls-remote exits 2 for "no such ref".
boot_check_ref() {
  local rc=0
  git ls-remote --exit-code --heads "$BOOT_REPO_URL" "$BOOT_REF" >> "$OMAMAC_LOG" 2>&1 || rc=$?
  case "$rc" in
    0) ;;
    2) boot_die "'$BOOT_REF' isn't on GitHub ($BOOT_REPO_URL). Nothing was changed." ;;
    *) boot_network_help ;;
  esac
}

boot_checkout() {
  if [ -d "$OMAMAC_HOME" ] && [ -n "$(ls -A "$OMAMAC_HOME")" ]; then
    [ -d "$OMAMAC_HOME/.git" ] ||
      boot_die "$OMAMAC_HOME exists and isn't an omamac checkout. Move it away and run this again. Nothing was changed."
    [ "$(git -C "$OMAMAC_HOME" remote get-url origin 2>/dev/null)" = "$BOOT_REPO_URL" ] ||
      boot_die "$OMAMAC_HOME is a git checkout of something other than $BOOT_REPO_URL. Move it away and run this again. Nothing was changed."
    boot_check_ref
    git -C "$OMAMAC_HOME" fetch origin "+refs/heads/$BOOT_REF:refs/remotes/origin/$BOOT_REF" >> "$OMAMAC_LOG" 2>&1 ||
      boot_network_help
    { git -C "$OMAMAC_HOME" switch "$BOOT_REF" &&
      git -C "$OMAMAC_HOME" merge --ff-only "origin/$BOOT_REF"; } >> "$OMAMAC_LOG" 2>&1 ||
      boot_die_log "Couldn't update $OMAMAC_HOME to '$BOOT_REF' (local changes or a diverged history?)."
  else
    boot_check_ref
    mkdir -p "$(dirname "$OMAMAC_HOME")"
    git clone --branch "$BOOT_REF" "$BOOT_REPO_URL" "$OMAMAC_HOME" >> "$OMAMAC_LOG" 2>&1 ||
      boot_network_help
  fi
}

boot_main() {
  boot_banner
  boot_preflight
  boot_log_start
  boot_sudo
  boot_homebrew
  boot_formulas
  boot_checkout
  exec "$BOOT_BREW_PREFIX/bin/bash" "$OMAMAC_HOME/install.sh"
}

boot_main
