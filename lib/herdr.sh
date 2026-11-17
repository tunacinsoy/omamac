# shellcheck shell=bash
# herdr's config. Sourced after lib/paths.sh and lib/ui.sh, before lib/apply.sh
# (it uses apply_put).
# herdr writes its settings-screen choices into this file, so omamac keeps a
# copy of what it wrote to tell its own file from one herdr or the user changed.

# herdr_render <out>: the template with the helper's absolute path filled in.
herdr_render() {
  local s
  s=$(<"$OMAMAC_CHECKOUT/config/herdr.toml")
  # Not sed: a path may hold & or /. The quoted replacement keeps bash 5.2 from reading & too.
  printf '%s\n' "${s//@OMAMAC_HELPER@/"$OMAMAC_HERDR_HELPER"}" > "$1"
}

# herdr_changed <rendered>: omamac's file is neither what omamac last wrote nor
# what it would write now. Matching the new render covers a run stopped
# between writing the file and its copy.
herdr_changed() {
  [ -e "$OMAMAC_HERDR_FILE" ] &&
    ! cmp -s "$OMAMAC_HERDR_FILE" "$OMAMAC_HERDR_WRITTEN" &&
    ! cmp -s "$OMAMAC_HERDR_FILE" "$1"
}

# herdr_user_config: herdr reads the user's own config, not omamac's.
# A file holding only "onboarding = false" is one herdr wrote itself, not the user's.
herdr_user_config() {
  local f=$OMAMAC_HERDR_USER_FILE
  [ -L "$f" ] || { [ -e "$f" ] && [ "$(<"$f")" != 'onboarding = false' ]; } ||
    { [ -n "${HERDR_CONFIG_PATH+set}" ] && [ "$HERDR_CONFIG_PATH" != "$OMAMAC_HERDR_FILE" ]; }
}

herdr_config_apply() {
  local tmp changed=no
  ui_step "herdr's config"
  mkdir -p "$OMAMAC_CONFIG_DIR" "$OMAMAC_STATE_DIR"
  tmp=$(mktemp "$OMAMAC_CONFIG_DIR/herdr.toml.XXXXXX")
  herdr_render "$tmp"
  if herdr_changed "$tmp"; then
    rm -f "$tmp"
    changed=yes
  else
    # The file first, then the copy: a stop between them leaves the file
    # equal to the new render, which herdr_changed doesn't count as a change.
    apply_put "$tmp" "$OMAMAC_HERDR_FILE"
    tmp=$(mktemp "$OMAMAC_STATE_DIR/herdr.toml.XXXXXX")
    cp "$OMAMAC_HERDR_FILE" "$tmp"
    apply_put "$tmp" "$OMAMAC_HERDR_WRITTEN"
  fi
  # One line only: the undo advice is no use to someone whose own config is in use.
  if herdr_user_config; then
    ui_info "Your own herdr config is kept."
  elif [ "$changed" = yes ]; then
    ui_info "herdr's config was changed in herdr, so omamac leaves it. To use omamac's again: delete ~/.config/omamac/herdr.toml, then run omamac update."
  else
    ui_ok "herdr's config is in place"
  fi
}
