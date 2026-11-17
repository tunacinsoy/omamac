# shellcheck shell=bash
# The core tools every omamac Mac gets. Sourced after lib/paths.sh and lib/ui.sh.

# jq: herdr's key bindings need it.
CORE_FORMULAS=(starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq)

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

# core_install: one brew install for what is missing. A formula already there is left alone.
core_install() {
  local list missing=() names
  # Not mapfile < <(…): that would hide a failed brew list and install nothing.
  list=$(core_missing) || return
  [ -z "$list" ] || mapfile -t missing <<< "$list"
  if [ "${#missing[@]}" -gt 0 ]; then
    names=$(IFS=,; echo "${missing[*]}")
    ui_run "Installing ${names//,/, }" "$OMAMAC_BREW_PREFIX/bin/brew" install "${missing[@]}" || return
  fi
  ui_ok "Core tools are installed"
}
