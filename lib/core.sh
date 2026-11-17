# shellcheck shell=bash
# The core tools every omamac Mac gets. Sourced after lib/paths.sh and lib/ui.sh.

CORE_FORMULAS=(starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli)

# core_missing: the core formulas Homebrew doesn't have, one per line.
core_missing() {
  local formula
  for formula in "${CORE_FORMULAS[@]}"; do
    "$OMAMAC_BREW_PREFIX/bin/brew" list --formula "$formula" >/dev/null 2>&1 || echo "$formula"
  done
}

# core_install: one brew install for what is missing. A formula already there is left alone.
core_install() {
  local missing names
  # Read every name first, as question_has does: no early exit mid-pipe.
  mapfile -t missing < <(core_missing)
  if [ "${#missing[@]}" -gt 0 ]; then
    names=$(IFS=,; echo "${missing[*]}")
    ui_run "Installing ${names//,/, }" "$OMAMAC_BREW_PREFIX/bin/brew" install "${missing[@]}" || return
  fi
  ui_ok "Core tools are installed"
}
