# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap
# The theme files in ~/.config/omamac. Sourced after lib/herdr.sh, lib/ghostty.sh
# and lib/neovim.sh, before lib/apply.sh (it uses apply_put). Needs lib/choices.sh:
# the theme is CHOICES[theme]. Every file is omamac's, written compare-then-move.

# theme_herdr_name <id>: the theme name herdr knows. herdr follows Ghostty's colours with "terminal".
theme_herdr_name() {
  case $1 in
    rose-pine) echo rose-pine-dawn ;;
    everforest | matte-black | osaka-jade | ristretto) echo terminal ;;
    *) echo "$1" ;;
  esac
}

# theme_put <dest> <cmd> [args...]: run cmd args <tmp>, then move tmp to dest if it differs.
# OMAMAC_STEP names dest, so a failure names the file.
theme_put() {
  local dest=$1 tmp
  shift
  OMAMAC_STEP="writing $dest"
  mkdir -p "$(dirname "$dest")"
  tmp=$(mktemp "$dest.XXXXXX")
  "$@" "$tmp"
  apply_put "$tmp" "$dest"
}

theme_btop_conf() { printf 'color_theme = "%s"\n' "$id" > "$1"; }

# theme_apply: the six theme files, from CHOICES[theme].
theme_apply() {
  local id=${CHOICES[theme]:-} f
  OMAMAC_STEP="checking the theme"
  ui_step "Theme files"
  [ -d "$OMAMAC_CHECKOUT/themes/${id:?no theme is chosen}" ] || { ui_fail "Unknown theme: $id"; return 1; }
  theme_put "$OMAMAC_GHOSTTY_FILE" ghostty_render
  theme_put "$OMAMAC_HERDR_FILE" herdr_render
  theme_put "$OMAMAC_STARSHIP_FILE" cp "$OMAMAC_CHECKOUT/themes/$id/starship.toml"
  theme_put "$OMAMAC_BTOP_FILE" theme_btop_conf
  theme_put "$OMAMAC_BTOP_THEMES/$id.theme" cp "$OMAMAC_CHECKOUT/themes/$id/btop.theme"
  OMAMAC_STEP="removing the old btop themes in $OMAMAC_BTOP_THEMES"
  for f in "$OMAMAC_BTOP_THEMES"/*.theme; do
    [ "$f" = "$OMAMAC_BTOP_THEMES/$id.theme" ] || rm -f "$f"
  done
  theme_put "$OMAMAC_NEOVIM_THEME_FILE" cp "$OMAMAC_CHECKOUT/themes/$id/neovim.lua"
  # The marker is only omamac's to write when omamac made the folder (it also upgrades Phase 3's).
  [ ! -e "$OMAMAC_NVIM_MARKER" ] || neovim_marker_write
  herdr_user_config && ui_info "Your own herdr config is kept."
  ui_ok "Theme files are in place"
}
