# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by install.sh's ERR trap
# What install.sh does after "Install?" is yes. Sourced after lib/core.sh and
# lib/neovim.sh; sets the caller's OMAMAC_STEP so a failure names its step.

# apply_zsh_file: omamac's zsh file is config/zshrc from the checkout.
apply_zsh_file() {
  ui_step "omamac's zsh file"
  mkdir -p "$OMAMAC_CONFIG_DIR"
  local tmp
  tmp=$(mktemp "$OMAMAC_CONFIG_DIR/zshrc.XXXXXX")
  cp "$OMAMAC_CHECKOUT/config/zshrc" "$tmp"
  # Move into place only if different, so a second run leaves the file (and its mtime) alone.
  if cmp -s "$tmp" "$OMAMAC_ZSH_FILE"; then
    rm -f "$tmp"
  else
    mv "$tmp" "$OMAMAC_ZSH_FILE"
  fi
  ui_ok "omamac's zsh file is in place"
}

apply_all() {
  OMAMAC_STEP="writing $OMAMAC_ZSH_FILE"
  apply_zsh_file
  OMAMAC_STEP='installing the core tools'
  core_install
  OMAMAC_STEP='setting up neovim'
  neovim_setup
}
