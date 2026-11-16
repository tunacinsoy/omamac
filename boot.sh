#!/bin/bash
# omamac's one-liner target: curl -fsSL .../boot.sh | bash
# Runs under macOS's /bin/bash 3.2, so no bash 4+ features. No sourced-vs-executed
# guard: BASH_SOURCE is empty when piped and `set -u` would abort.
set -euo pipefail

# These repeat lib/paths.sh on purpose: boot.sh arrives alone through the pipe
# and can't source lib/. The OMAMAC_TEST_* variables are test seams.
# shellcheck disable=SC2034 # used by the Homebrew step
BOOT_BREW_INSTALLER_URL=${OMAMAC_TEST_BREW_INSTALLER_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}
# shellcheck disable=SC2034 # used by the checkout step
BOOT_REPO_URL=${OMAMAC_TEST_REPO_URL:-https://github.com/tunacinsoy/omamac}
BOOT_BREW_PREFIX=${OMAMAC_TEST_BREW_PREFIX:-/opt/homebrew}
BOOT_USR_LOCAL_BREW=${OMAMAC_TEST_USR_LOCAL_BREW:-/usr/local/bin/brew}
BOOT_TTY=${OMAMAC_TEST_TTY:-/dev/tty}

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

  shell=$(dscl . -read "/Users/$USER" UserShell | sed -n 's/^UserShell: //p')
  case "$shell" in
    */zsh) ;;
    *) boot_die "Your login shell is ${shell:-unknown}, not zsh. Run: chsh -s /bin/zsh, open a new terminal, and run this again." ;;
  esac

  # Stdin is the script, so the password prompt needs the terminal.
  { : < "$BOOT_TTY"; } 2>/dev/null || boot_die "omamac needs a terminal to ask for your password."
}

boot_main() {
  boot_banner
  boot_preflight
}

boot_main
