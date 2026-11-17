# shellcheck shell=bash
# shellcheck disable=SC2088 # the ~ in messages is shown to the user, not expanded
# omamac doctor. Sourced. Read-only: it only looks and reports.

# doctor_report <ok|fail|info> <what> [<why>] [<fix>]. Returns 1 for fail so callers can count it.
doctor_report() {
  local kind=$1 what=$2 why=${3:-} fix=${4:-}
  case "$kind" in
    ok) ui_ok "$what" ;;
    fail)
      ui_fail "$what — $why. Fix: $fix"
      return 1
      ;;
    info) ui_info "$what — $why" ;;
  esac
}

doctor_check_homebrew() {
  local what=Homebrew
  if [ -e "$OMAMAC_USR_LOCAL_BREW" ]; then
    doctor_report fail "$what" "Homebrew is also at /usr/local, which mixes two installs" \
      "see https://docs.brew.sh/Installation"
  elif [ ! -x "$OMAMAC_BREW_PREFIX/bin/brew" ]; then
    doctor_report fail "$what" "Homebrew is missing, and omamac installs everything with it" \
      "Run the one-liner"
  else
    doctor_report ok "$what"
  fi
}

doctor_check_bash() {
  local what="bash 5" major
  # shellcheck disable=SC2016 # the inner bash expands it
  major=$("$OMAMAC_BREW_PREFIX/bin/bash" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null) || major=0
  if [ "${major:-0}" -ge 5 ]; then
    doctor_report ok "$what"
  else
    doctor_report fail "$what" "omamac's scripts need bash 5, and macOS ships 3.2" "brew install bash"
  fi
}

doctor_check_gum() {
  if "$OMAMAC_BREW_PREFIX/bin/brew" list --formula gum >/dev/null 2>&1; then
    doctor_report ok gum
  else
    doctor_report fail gum "omamac draws its output with gum" "brew install gum"
  fi
}

# Sets DOCTOR_HAS_CHECKOUT so the clean check knows whether it can run.
doctor_check_checkout() {
  local what=Checkout origin=""
  DOCTOR_HAS_CHECKOUT=0
  if [ -e "$OMAMAC_HOME/.git" ]; then
    origin=$(git -C "$OMAMAC_HOME" remote get-url origin 2>/dev/null) || origin=""
  fi
  if [ "$origin" = "$OMAMAC_REPO_URL" ]; then
    DOCTOR_HAS_CHECKOUT=1
    doctor_report ok "$what"
  else
    doctor_report fail "$what" "~/.local/share/omamac is not a checkout of omamac" "Run the one-liner"
  fi
}

doctor_check_clean() {
  local what="Checkout is clean" changes
  if [ "$DOCTOR_HAS_CHECKOUT" -ne 1 ]; then
    doctor_report info "$what" "skipped, there is no checkout"
    return 0
  fi
  # No optional locks: a read-only check must not take git's index lock.
  # Untracked files (a .DS_Store) don't block update, so they don't count here either.
  changes=$(GIT_OPTIONAL_LOCKS=0 git -C "$OMAMAC_HOME" status --porcelain --untracked-files=no 2>/dev/null) || changes=unknown
  if [ -z "$changes" ]; then
    doctor_report ok "$what"
  else
    doctor_report fail "$what" "local edits would block omamac update" \
      "git -C ~/.local/share/omamac status, to see them"
  fi
}

# doctor_check_line <what> <file> <fixed string> <why>
doctor_check_line() {
  if lines_has "$2" "$3"; then
    doctor_report ok "$1"
  else
    doctor_report fail "$1" "$4" "Run the one-liner again"
  fi
}

doctor_check_zsh_file() {
  if [ -e "$OMAMAC_ZSH_FILE" ]; then
    doctor_report ok "omamac's zsh file"
  else
    doctor_report fail "omamac's zsh file" "~/.config/omamac/zshrc is missing" "Run the one-liner again"
  fi
}

doctor_check_core() {
  local what="Core tools" missing names
  # Homebrew's own ✗ is reported above; here a failed list only skips the check.
  if ! missing=$(core_missing 2>/dev/null); then
    doctor_report info "$what" "skipped, Homebrew can't list its formulas"
  elif [ -z "$missing" ]; then
    doctor_report ok "$what"
  else
    names=${missing//$'\n'/ }
    doctor_report fail "$what" "$names missing, and omamac's shell and editor need them" \
      "brew install $names"
  fi
}

doctor_check_neovim() {
  local what="neovim config"
  if [ -e "$OMAMAC_NVIM_MARKER" ]; then
    doctor_report ok "$what"
  elif [ -e "$OMAMAC_NVIM_DIR" ] || [ -L "$OMAMAC_NVIM_DIR" ]; then
    doctor_report info "$what" "your own neovim config is kept"
  else
    doctor_report fail "$what" "~/.config/nvim is missing" "Run the one-liner again"
  fi
}

doctor_check_herdr() {
  local what="herdr config" rendered changed=1
  if herdr_user_config; then
    doctor_report info "$what" "your own herdr config is kept, so omamac's key bindings don't reach herdr"
  elif [ ! -e "$OMAMAC_HERDR_FILE" ]; then
    doctor_report fail "$what" "~/.config/omamac/herdr.toml is missing" "omamac update"
  else
    # Read-only: the render goes to the temp dir, not omamac's folders, and is removed.
    rendered=$(mktemp "${TMPDIR:-/tmp}/omamac-doctor.XXXXXX")
    herdr_render "$rendered" && herdr_changed "$rendered" && changed=0
    rm -f "$rendered"
    if [ "$changed" -eq 0 ]; then
      doctor_report info "$what" "changed in herdr, so omamac's updates to it are skipped"
    else
      doctor_report ok "$what"
    fi
  fi
}

doctor_check_choices() {
  local what="Saved answers" message
  if [ ! -e "$OMAMAC_CHOICES_FILE" ]; then
    doctor_report fail "$what" "omamac doesn't know your answers" "Run the one-liner"
  elif ! choices_load "$OMAMAC_CHOICES_FILE" 2>/dev/null; then
    # Load again for the message, "<problem>. Fix: <fix>", split into doctor's why and fix.
    message=$(choices_load "$OMAMAC_CHOICES_FILE" 2>&1) || true
    doctor_report fail "$what" "${message%%. Fix: *}" "${message#*. Fix: }"
  elif [ -n "$(choices_missing)" ]; then
    doctor_report fail "$what" "a question has no answer yet" "Run the one-liner; it asks only that one"
  else
    doctor_report ok "$what"
  fi
}

# Prints one line per check; returns 1 if any is a ✗.
doctor_run() {
  local status=0
  doctor_check_homebrew || status=1
  doctor_check_bash || status=1
  doctor_check_gum || status=1
  doctor_check_checkout || status=1
  doctor_check_clean || status=1
  doctor_check_line "Homebrew line" "$HOME/.zprofile" "brew shellenv" \
    "~/.zprofile does not put Homebrew on PATH" || status=1
  doctor_check_line "omamac line" "$HOME/.zshrc" "$OMAMAC_ZSHRC_LINE" \
    "~/.zshrc does not load omamac's settings" || status=1
  doctor_check_zsh_file || status=1
  doctor_check_core || status=1
  doctor_check_neovim || status=1
  doctor_check_herdr || status=1
  doctor_check_choices || status=1
  return "$status"
}
