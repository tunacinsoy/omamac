# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by install.sh's ERR trap
# The steps the one-liner and omamac update share. Sourced after lib/core.sh,
# lib/neovim.sh, lib/herdr.sh and lib/languages.sh; sets the caller's OMAMAC_STEP so a failure names its step.

# apply_put <tmp> <dest>: move tmp into place only if different, so a second
# run leaves dest (and its mtime) alone. tmp should sit in dest's folder, so
# the mv is one rename.
apply_put() {
  mkdir -p "$(dirname "$2")"
  if cmp -s "$1" "$2"; then
    rm -f "$1"
  else
    mv "$1" "$2"
  fi
}

# apply_zsh_file: omamac's zsh file is config/zshrc from the checkout.
apply_zsh_file() {
  ui_step "omamac's zsh file"
  mkdir -p "$OMAMAC_CONFIG_DIR"
  local tmp
  tmp=$(mktemp "$OMAMAC_CONFIG_DIR/zshrc.XXXXXX")
  cp "$OMAMAC_CHECKOUT/config/zshrc" "$tmp"
  apply_put "$tmp" "$OMAMAC_ZSH_FILE"
  ui_ok "omamac's zsh file is in place"
}

apply_all() {
  OMAMAC_STEP="writing $OMAMAC_ZSH_FILE"
  apply_zsh_file
  OMAMAC_STEP="writing $OMAMAC_HERDR_FILE"
  herdr_config_apply
  OMAMAC_STEP='writing ~/.config/mise/conf.d/omamac.toml'
  languages_write_dropin
  OMAMAC_STEP='installing the core tools'
  core_install
  OMAMAC_STEP='setting up neovim'
  neovim_setup
  OMAMAC_STEP='installing your languages'
  languages_install
}
