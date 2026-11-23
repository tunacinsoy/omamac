# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap
# The theme files in ~/.config/omamac. Sourced after lib/herdr.sh, lib/ghostty.sh
# and lib/neovim.sh, before lib/apply.sh (it uses apply_put). Needs lib/vscode.sh, lib/clis.sh and lib/choices.sh:
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
  "$@" "$tmp" || { rm -f "$tmp"; return 1; }
  apply_put "$tmp" "$dest"
}

# theme_starship_user_config / theme_btop_user_config: starship or btop reads the
# user's own config, not omamac's. Used by theme_apply and doctor.
theme_starship_user_config() {
  [ -e "$OMAMAC_STARSHIP_USER_FILE" ] || [ -L "$OMAMAC_STARSHIP_USER_FILE" ] ||
    { [ -n "${STARSHIP_CONFIG+set}" ] && [ "$STARSHIP_CONFIG" != "$OMAMAC_STARSHIP_FILE" ]; }
}
theme_btop_user_config() {
  [ -e "$OMAMAC_BTOP_USER_FILE" ] || [ -L "$OMAMAC_BTOP_USER_FILE" ]
}

# theme_btop_conf <id> <out>
theme_btop_conf() { printf 'color_theme = "%s"\n' "$1" > "$2"; }

# theme_reaches: what the theme reaches, joined with commas and "and": every
# tool whose own config the user didn't keep instead. VS Code counts once it is
# installed; on a first run it is said later, by its own step.
theme_reaches() {
  local to=(Ghostty) last
  herdr_user_config || to+=(herdr)
  theme_btop_user_config || to+=(btop)
  theme_starship_user_config || to+=("the prompt")
  [ -e "$OMAMAC_NVIM_MARKER" ] || { [ ! -e "$OMAMAC_NVIM_DIR" ] && [ ! -L "$OMAMAC_NVIM_DIR" ]; } && to+=(neovim)
  if [ -x "$(vscode_code)" ] && ! vscode_user_theme; then to+=("VS Code"); fi
  last=${to[-1]}
  unset 'to[-1]'
  if [ "${#to[@]}" -eq 0 ]; then echo "$last"; else echo "$(clis_join "${to[@]}") and $last"; fi
}

# theme_apply: the six theme files, from CHOICES[theme].
theme_apply() {
  local id=${CHOICES[theme]:-} f
  OMAMAC_STEP="checking the theme"
  ui_step "Theme files"
  [ -d "$OMAMAC_CHECKOUT/themes/${id:?no theme is chosen}" ] || { ui_fail "Unknown theme: $id"; return 1; }
  theme_put "$OMAMAC_GHOSTTY_FILE" ghostty_render
  theme_put "$OMAMAC_HERDR_FILE" herdr_render
  theme_put "$OMAMAC_STARSHIP_FILE" cp "$OMAMAC_CHECKOUT/themes/$id/starship.toml"
  theme_put "$OMAMAC_BTOP_FILE" theme_btop_conf "$id"
  theme_put "$OMAMAC_BTOP_THEMES/$id.theme" cp "$OMAMAC_CHECKOUT/themes/$id/btop.theme"
  OMAMAC_STEP="removing the old btop themes in $OMAMAC_BTOP_THEMES"
  for f in "$OMAMAC_BTOP_THEMES"/*.theme; do
    [ "$f" = "$OMAMAC_BTOP_THEMES/$id.theme" ] || rm -f "$f"
  done
  theme_put "$OMAMAC_NEOVIM_THEME_FILE" cp "$OMAMAC_CHECKOUT/themes/$id/neovim.lua"
  # The marker is only omamac's to write when omamac made the folder (it also upgrades Phase 3's).
  if [ -e "$OMAMAC_NVIM_MARKER" ]; then
    OMAMAC_STEP="writing $OMAMAC_NVIM_MARKER"
    neovim_marker_write
  fi
  herdr_user_config && ui_info "Your own herdr config is kept."
  theme_starship_user_config && ui_info "Your own starship config is kept, so the theme doesn't reach the prompt."
  theme_btop_user_config && ui_info "Your own btop config is kept, so the theme doesn't reach btop."
  if [ ! -e "$OMAMAC_NVIM_MARKER" ] && { [ -e "$OMAMAC_NVIM_DIR" ] || [ -L "$OMAMAC_NVIM_DIR" ]; }; then
    ui_info "Your own neovim config is kept, so the theme doesn't reach neovim."
  fi
  ui_ok "Theme: $(question_label theme "$id"), in $(theme_reaches)"
}

# theme_signal <name>: send SIGUSR2 (reload your config) to every process whose
# program is called <name>. Not pkill: on macOS 27, pgrep and pkill don't see
# Ghostty or herdr, though ps does, so `pkill -x ghostty` signalled nothing.
theme_signal() {
  local pid comm
  while read -r pid comm; do
    [ "${comm##*/}" != "$1" ] || kill -USR2 "$pid" >> "$OMAMAC_LOG" 2>&1 || true
  done < <(ps -axo pid=,comm= 2>> "$OMAMAC_LOG")
}

# theme_reload: tell what is running to read its new files. Each is a no-op when
# it isn't running, so a failure is ignored; any output goes to the log.
theme_reload() {
  OMAMAC_STEP="reloading what is running"
  theme_signal ghostty
  herdr server reload-config >> "$OMAMAC_LOG" 2>&1 || true
  theme_signal btop
}

# theme_run [<id>]: CHOICES is loaded. Save the theme first, then always apply it,
# even when it is the current one: that finishes a switch that failed halfway.
theme_run() {
  local id=${1:-} options
  OMAMAC_STEP='choosing the theme'
  if [ "$#" -eq 0 ]; then
    ask_need_tty
    mapfile -t options <<< "${QUESTION_OPTIONS[theme]}"
    ask_choose "Which theme?" "${options[@]}"
    id=$ASK_PICKED
  elif ! question_has theme "$id"; then
    ui_fail "omamac doesn't know the theme '$id'. It knows: $(question_values theme | paste -sd' ' -)."
    exit 2
  fi
  log_start
  CHOICES[theme]=$id
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  theme_apply
  theme_reload
  vscode_theme_install
  local later='neovim the next time it opens'
  [ ! -x "$(vscode_code)" ] || later='neovim and VS Code the next time they open'
  ui_ok "What's running shows it now; $later."
}
