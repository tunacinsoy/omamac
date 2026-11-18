# shellcheck shell=bash
# herdr's config. Sourced after lib/paths.sh and lib/ui.sh, before lib/apply.sh.
# lib/theme.sh writes the file (theme_apply).
# The file is omamac's: each run writes it again, so herdr always follows
# omamac's theme and keys, even after a change in herdr's settings screen.

# herdr_render <out>: the template with the helper's absolute path and the theme filled in.
# Needs lib/theme.sh and CHOICES[theme].
herdr_render() {
  local s
  s=$(<"$OMAMAC_CHECKOUT/config/herdr.toml")
  s=${s//@OMAMAC_HERDR_THEME@/"$(theme_herdr_name "${CHOICES[theme]}")"}
  # Not sed: a path may hold & or /. The quoted replacement keeps bash 5.2 from reading & too.
  printf '%s\n' "${s//@OMAMAC_HELPER@/"$OMAMAC_HERDR_HELPER"}" > "$1"
}

# herdr_user_config: herdr reads the user's own config, not omamac's.
# A file holding only "onboarding = false" is one herdr wrote itself, not the user's.
herdr_user_config() {
  local f=$OMAMAC_HERDR_USER_FILE
  [ -L "$f" ] || { [ -e "$f" ] && [ "$(<"$f")" != 'onboarding = false' ]; } ||
    { [ -n "${HERDR_CONFIG_PATH+set}" ] && [ "$HERDR_CONFIG_PATH" != "$OMAMAC_HERDR_FILE" ]; }
}
