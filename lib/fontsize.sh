# shellcheck shell=bash disable=SC2034 # ASK_SELECTED and OMAMAC_STEP are read elsewhere
# omamac font-size: Ghostty's font size, picked from a list or named. Sourced
# after lib/ghostty.sh, lib/theme.sh and lib/ask.sh. The size lives in its own
# file, not choices.env, so the first run and update never ask about it.

# Label:value, in the picker's order. The hints say where a size suits.
FONT_SIZE_OPTIONS=(
  10:10 "11  more on screen:11" 12:12 13:13 "14  laptop:14" 15:15
  "16  external monitor:16" 17:17 "18  monitor further away:18" 19:19
  "20  presenting or sharing your screen:20" Default:default
)

# font_size_save <10…20|default>: write the size file, or remove it for default.
font_size_save() {
  OMAMAC_STEP="saving the font size"
  if [ "$1" = default ]; then
    rm -f "$OMAMAC_FONT_SIZE_FILE"
    return 0
  fi
  local tmp
  mkdir -p "$(dirname "$OMAMAC_FONT_SIZE_FILE")"
  tmp=$(mktemp "$OMAMAC_FONT_SIZE_FILE.XXXXXX")
  printf '%s\n' "$1" > "$tmp"
  mv "$tmp" "$OMAMAC_FONT_SIZE_FILE"
}

# font_size_run [<size>]: CHOICES is loaded (ghostty_render needs the theme).
# No size: the picker, on the current size. Then save, rewrite omamac's
# Ghostty file, reload Ghostty and say the size in one line.
font_size_run() {
  local size=${1-} option current shown
  OMAMAC_STEP='choosing the font size'
  if [ "$#" -eq 0 ]; then
    ask_need_tty
    current=$(ghostty_font_size)
    ASK_SELECTED=Default
    for option in "${FONT_SIZE_OPTIONS[@]}"; do
      [ "${option##*:}" != "$current" ] || ASK_SELECTED=${option%:*}
    done
    ask_choose "Which size?" "${FONT_SIZE_OPTIONS[@]}"
    ASK_SELECTED=''
    size=$ASK_PICKED
  else
    local ok=''
    for option in "${FONT_SIZE_OPTIONS[@]}"; do
      [ "${option##*:}" != "$size" ] || ok=1
    done
    if [ -z "$ok" ]; then
      ui_fail "Font sizes are 10 to 20, or default."
      exit 2
    fi
  fi
  log_start
  font_size_save "$size"
  theme_put "$OMAMAC_GHOSTTY_FILE" ghostty_render
  OMAMAC_STEP="reloading Ghostty"
  theme_signal ghostty
  shown=$size
  [ "$size" != default ] || shown=Default
  if ui_term; then ui_row ok "Font size" "$shown"; else ui_ok "Font size: $shown"; fi
}
