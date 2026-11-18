# shellcheck shell=bash
# The core tools every omamac Mac gets. Sourced after lib/paths.sh and lib/ui.sh.

# jq: herdr's key bindings need it.
CORE_FORMULAS=(starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq)

# Casks, and the app each one puts in /Applications.
CORE_CASKS=(ghostty)
declare -A CORE_CASK_APP=([ghostty]=Ghostty.app)

# core_where <installed|missing> <formula>…: the given formulas in that state,
# one per line, in the given order. One brew list for all of them: each call
# takes about a second. Returns non-zero if Homebrew can't list.
core_where() {
  local want=$1 list formula
  local -A have=()
  shift
  list=$("$OMAMAC_BREW_PREFIX/bin/brew" list --formula -1) || return
  while IFS= read -r formula; do
    [ -z "$formula" ] || have[$formula]=1
  done <<< "$list"
  for formula in "$@"; do
    if [ -n "${have[$formula]:-}" ]; then
      [ "$want" != installed ] || echo "$formula"
    else
      [ "$want" != missing ] || echo "$formula"
    fi
  done
}

# core_missing: the core formulas Homebrew doesn't have, one per line.
core_missing() { core_where missing "${CORE_FORMULAS[@]}"; }

# core_cask_state <cask>: brew (Homebrew has it and the app is there), hand
# (the app is in Applications but Homebrew doesn't know it) or missing (no app;
# Homebrew may still list the cask). Returns non-zero if Homebrew can't list.
core_cask_state() {
  local cask=$1 list line listed=0
  local app=$OMAMAC_APPLICATIONS/${CORE_CASK_APP[$cask]}
  list=$("$OMAMAC_BREW_PREFIX/bin/brew" list --cask -1) || return
  while IFS= read -r line; do
    if [ "$line" = "$cask" ]; then listed=1; fi
  done <<< "$list"
  if [ ! -e "$app" ]; then echo missing; elif [ "$listed" -eq 1 ]; then echo brew; else echo hand; fi
}

# core_cask_listed <cask>: succeeds when Homebrew lists the cask.
core_cask_listed() {
  "$OMAMAC_BREW_PREFIX/bin/brew" list --cask "$1" > /dev/null 2>&1
}

# core_install: one brew install for what is missing. A formula already there is left alone.
# A cask already in Applications by hand is used as it is.
core_install() {
  local list missing=() names cask state
  # Not mapfile < <(…): that would hide a failed brew list and install nothing.
  list=$(core_missing) || return
  [ -z "$list" ] || mapfile -t missing <<< "$list"
  if [ "${#missing[@]}" -gt 0 ]; then
    names=$(IFS=,; echo "${missing[*]}")
    ui_run "Installing ${names//,/, }" "$OMAMAC_BREW_PREFIX/bin/brew" install "${missing[@]}" || return
  fi
  # Its own step: a cask can ask macOS for permission, so it is shown alone.
  for cask in "${CORE_CASKS[@]}"; do
    state=$(core_cask_state "$cask") || return
    case $state in
      missing)
        # A plain install of a cask Homebrew lists does nothing; reinstall puts the app back.
        if core_cask_listed "$cask"; then
          ui_run "Reinstalling Ghostty" "$OMAMAC_BREW_PREFIX/bin/brew" reinstall --cask "$cask" || return
        else
          ui_run "Installing Ghostty" "$OMAMAC_BREW_PREFIX/bin/brew" install --cask "$cask" || return
        fi
        ;;
      hand) ui_info "Ghostty is already installed, not through Homebrew. omamac won't update it." ;;
    esac
  done
  ui_ok "Core tools are installed"
}
