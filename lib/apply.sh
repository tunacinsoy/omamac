# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap
# The steps the one-liner, omamac update and omamac install share. Sourced
# after lib/core.sh, lib/apps.sh, lib/neovim.sh, lib/herdr.sh, lib/ghostty.sh, lib/theme.sh, lib/vscode.sh, lib/languages.sh,
# lib/clis.sh, lib/docker.sh and lib/settings.sh. Each step sets OMAMAC_STEP, which the caller's ERR trap
# (install.sh, update.sh or bin/omamac) reads to name the step that failed.

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

# The terminal look's progress (#46): apply_all's steps are grouped into
# stages, each one row with its count ("3/9 ✓ Core tools  15 installed"). A
# stage this run won't do is left out of the count, so no number is skipped.
# Plain text keeps its own lines and runs none of this.

# apply_has <stage>: this run does that stage.
apply_has() {
  local list
  case $1 in
    password)
      list=$(apps_password_pending) || return 0
      [ -n "$list" ]
      ;;
    docker) [ "${CHOICES[docker]:-none}" != none ] ;;
    languages) [ -n "${CHOICES[languages]:-}" ] ;;
    clis) [ -n "$(clis_chosen)" ] ;;
    apps) [ -n "$(apps_chosen)" ] ;;
    # VS Code may arrive with the apps step.
    vscode) [ -x "$(vscode_code)" ] || [[ " $(apps_chosen | tr '\n' ' ') " == *" vscode "* ]] ;;
    *) return 0 ;;
  esac
}

# apply_stage_count: how many stages apply_all does in this run.
apply_stage_count() {
  local n=4 stage
  for stage in password docker languages clis apps vscode; do
    if apply_has "$stage"; then n=$((n + 1)); fi
  done
  echo "$n"
}

# apply_stage <stage> <name>: in the terminal look, the stage starts when this
# run does it.
apply_stage() {
  if ui_term && apply_has "$1"; then
    # The password step's apps, while they are still to install.
    [ "$1" != password ] || mapfile -t APPLY_PENDING < <(apps_password_pending)
    ui_stage "$2"
  fi
  return 0
}

# apply_stage_done <stage>: its row, with what it covered.
apply_stage_done() {
  [ -n "$UI_STAGE_NAME" ] || return 0
  local ids=() id labels=() answer
  case $1 in
    password) ui_stage_done "$(apps_step_labels "${APPLY_PENDING[@]}")" ;;
    docker) ui_stage_done "$(question_label docker "${CHOICES[docker]}")" ;;
    shell) ui_stage_done "$(question_label theme "${CHOICES[theme]}")" ;;
    core) ui_stage_done "$((${#CORE_FORMULAS[@]} + ${#CORE_CASKS[@]})) installed" ;;
    neovim) if [ -e "$OMAMAC_NVIM_MARKER" ]; then ui_stage_done LazyVim; else ui_stage_done "your own config is kept"; fi ;;
    languages)
      read -ra ids <<< "${CHOICES[languages]}"
      for id in "${ids[@]}"; do labels+=("$(question_label languages "$id")"); done
      ui_stage_done "$(clis_join "${labels[@]}")"
      ;;
    clis)
      mapfile -t ids < <(clis_chosen)
      for id in "${ids[@]}"; do labels+=("$(question_label "$(clis_key "$id")" "$id")"); done
      ui_stage_done "$(clis_join "${labels[@]}")"
      ;;
    # A count, as the apps can be twenty names.
    apps)
      mapfile -t ids < <(apps_chosen)
      ui_stage_done "${#ids[@]} installed"
      ;;
    macos)
      for answer in desktops window_margins desktop_widgets dock dock_autohide; do
        [ "${CHOICES[$answer]:-}" != yes ] || labels+=("${QUESTION_TITLE[$answer]}")
      done
      if [ "${#labels[@]}" -eq 0 ]; then ui_stage_done "nothing chosen"; else ui_stage_done "$(clis_join "${labels[@]}")"; fi
      ;;
    vscode) if vscode_user_theme; then ui_stage_done "your own theme is kept"; else ui_stage_done "$(question_label theme "${CHOICES[theme]}")"; fi ;;
  esac
}

apply_all() {
  # Here, not in a step: the password step adds Docker Desktop's note.
  DOCKER_NOTES=()
  # First: Homebrew may ask for the password (Zoom, Google Drive, Docker
  # Desktop), so ask while the user is still at the keyboard. It needs no
  # earlier step; neither does Docker (colima's service check reads jq from
  # /usr/bin on macOS 27, not Homebrew's).
  OMAMAC_STEP='installing the apps that need your password'
  apply_stage password "Password apps"
  apps_install_password
  apply_stage_done password
  OMAMAC_STEP='installing Docker'
  apply_stage docker Docker
  docker_install
  apply_stage_done docker
  apply_stage shell "Shell and theme"
  OMAMAC_STEP="writing $OMAMAC_ZSH_FILE"
  apply_zsh_file
  theme_apply
  OMAMAC_STEP='writing ~/.config/mise/conf.d/omamac.toml'
  languages_write_dropin
  apply_stage_done shell
  OMAMAC_STEP='installing the core tools'
  apply_stage core "Core tools"
  core_install
  apply_stage_done core
  OMAMAC_STEP='setting up neovim'
  apply_stage neovim neovim
  neovim_setup
  apply_stage_done neovim
  OMAMAC_STEP='installing your languages'
  apply_stage languages Languages
  languages_install
  apply_stage_done languages
  OMAMAC_STEP='installing your cloud CLIs and coding agents'
  apply_stage clis "CLIs and agents"
  clis_install
  apply_stage_done clis
  apply_stage apps Apps
  apps_install
  apply_stage_done apps
  apply_stage macos macOS
  settings_apply
  apply_stage_done macos
  # After the apps: VS Code may be one of them.
  apply_stage vscode "VS Code theme"
  vscode_theme_install
  apply_stage_done vscode
}

