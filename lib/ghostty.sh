# shellcheck shell=bash
# Ghostty opens into herdr. Sourced after lib/paths.sh and lib/ui.sh, before
# lib/apply.sh (lib/theme.sh writes the file). ghostty_line_file and
# ghostty_line_add also need lib/lines.sh (install.sh and doctor have it;
# update.sh doesn't call them).
# omamac's file is rewritten each run; the user's own Ghostty config only gets one include line.

# ghostty_render <out>: the template with the launcher's absolute path filled in,
# then the chosen theme's colours. Needs CHOICES[theme].
ghostty_render() {
  local s
  s=$(<"$OMAMAC_CHECKOUT/config/ghostty.conf")
  # Not sed: a path may hold & or /. The quoted replacement keeps bash 5.2 from reading & too.
  printf '%s\n' "${s//@OMAMAC_TERMINAL@/"$OMAMAC_TERMINAL"}" > "$1"
  cat "$OMAMAC_CHECKOUT/themes/${CHOICES[theme]}/ghostty.conf" >> "$1"
}

# ghostty_user_files: Ghostty's four user files, in load order (a later one wins).
ghostty_user_files() {
  local d
  for d in "$HOME/.config/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty"; do
    printf '%s\n' "$d/config" "$d/config.ghostty"
  done
}

# ghostty_line_file: the file that holds the include line; else the last file
# that exists (it loads last, so the line wins there); else a new config.ghostty.
ghostty_line_file() {
  local f last=''
  while IFS= read -r f; do
    if lines_has "$f" "$OMAMAC_GHOSTTY_LINE"; then
      printf '%s\n' "$f"
      return 0
    fi
    [ -e "$f" ] && last=$f
  done < <(ghostty_user_files)
  printf '%s\n' "${last:-$HOME/.config/ghostty/config.ghostty}"
}

ghostty_line_add() {
  lines_add "$(ghostty_line_file)" "$OMAMAC_GHOSTTY_LINE"
}
