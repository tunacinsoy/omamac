# shellcheck shell=bash
# shellcheck disable=SC2034 # OMAMAC_STEP is read by bin/omamac's ERR trap
# shellcheck disable=SC2004 # CHOICES is associative (lib/choices.sh), so $key is needed
# omamac uninstall: remove one language, cloud CLI, coding agent, setting, Docker or app.
# Sourced after lib/ask.sh, lib/log.sh, lib/core.sh, lib/apps.sh,
# lib/languages.sh, lib/clis.sh, lib/docker.sh, lib/appmanagement.sh,
# lib/settings.sh and lib/dock.sh.

# The questions whose picks omamac uninstall can remove.
REMOVE_KEYS=(languages cloud_clis coding_agents)

# remove_setting <name>: put a desktop, window-margin or Dock auto-hide
# setting back. The answer is saved no last, so a failure leaves it yes and
# the rest recorded.
remove_setting() {
  local key=desktops title
  case $1 in
    window-margins) key=window_margins ;;
    dock-autohide) key=dock_autohide ;;
  esac
  title=${QUESTION_TITLE[$key]}
  if [ "${CHOICES[$key]:-}" != yes ]; then
    ui_info "$title isn't set by omamac."
    exit 0
  fi
  ui_box "$title: $(settings_what "$key")"
  if ! ask_yes "Remove $title?"; then
    ui_info "Nothing was removed."
    exit 0
  fi
  log_start
  settings_uninstall "$key"
  CHOICES[$key]=no
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  ui_ok "$title is removed"
}

# remove_dock: put the Dock and show-recents back. The answer is saved no
# last, so a failure leaves it yes for a rerun to finish.
remove_dock() {
  local title=${QUESTION_TITLE[dock]}
  if [ "${CHOICES[dock]:-}" != yes ]; then
    ui_info "$title isn't set by omamac."
    exit 0
  fi
  ui_box "$title: your Dock goes back to how it was before omamac cleaned it. Changes you made to it since are undone."
  ask_yes "Remove $title?" || { ui_info "Nothing was removed."; exit 0; }
  log_start
  dock_restore || return
  settings_uninstall dock
  CHOICES[dock]=no
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  ui_ok "$title is removed"
}

# remove_app_management_ok <app path> <name>: Homebrew replaces the app
# folder, which needs App Management. Checked before any question, so a
# refusal changes nothing; exits 1 with the fix.
remove_app_management_ok() {
  local status=0
  app_management_ok "$1" || status=$?
  case $status in
    0) ;;
    1)
      ui_fail "macOS won't let your terminal change apps, so nothing was removed."
      ui_fail "Fix: System Settings → Privacy & Security → App Management, turn on your terminal, then run omamac uninstall $2 again."
      open "$APP_MANAGEMENT_URL" || true
      exit 1
      ;;
    *) ui_fail "omamac couldn't test write access to $1, so nothing was removed."; exit 1 ;;
  esac
}

# remove_app <id>: a catalog app. Homebrew deletes its settings and data only
# on a yes. The pick is dropped and saved last, so a failure leaves it for
# doctor to report.
remove_app() {
  local id=$1 label cask state listed=0 zap=() what='the app' chosen=()
  label=$(apps_label "$id")
  cask=${APP_CASK[$id]}
  mapfile -t chosen < <(apps_chosen)
  if [[ " ${chosen[*]} " != *" $id "* ]]; then
    ui_info "$label isn't installed by omamac."
    exit 0
  fi
  state=$(core_cask_state "$cask") || return
  if [ "$state" = hand ]; then
    ui_box "$label: installed by hand, so the app stays. omamac only forgets your pick."
    ask_yes "Remove $label?" || { ui_info "Nothing was removed."; exit 0; }
    log_start
  else
    # A trashed app has nothing to write to. An installer-package app is
    # root-owned, so the write test can't reach it; Homebrew removes it with sudo.
    [ "$state" != brew ] || [ "${APP_PASSWORD[$id]}" = yes ] \
      || remove_app_management_ok "$OMAMAC_APPLICATIONS/${APP_BUNDLE[$id]}" "$id"
    # Without the cask Homebrew has no data list to delete, so nothing to ask.
    if core_cask_listed "$cask"; then
      listed=1
      ui_info "On yes, Homebrew also deletes what $label keeps in ~/Library."
      if ask_yes "Also remove $label's settings and data?"; then
        zap=(--zap) what='the app, with its settings and data'
      fi
    fi
    ui_box "$label: $what."
    ask_yes "Remove $label?" || { ui_info "Nothing was removed."; exit 0; }
    log_start
    if [ "$listed" -eq 1 ]; then
      OMAMAC_STEP="removing $label"
      ui_info "Homebrew may ask for your password."
      # In the open: a cask may need sudo, and Homebrew asks for it itself.
      ui_run_open "Removing $label" "$OMAMAC_BREW_PREFIX/bin/brew" uninstall --cask "${zap[@]}" "$cask" || return
    fi
    # A hand-installed app stays, and so does its tile.
    dock_remove_app "${APP_BUNDLE[$id]}" "$label" || return
  fi
  apps_drop "$id"
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  if [ "$state" = hand ]; then ui_ok "$label is removed from your answers"; else ui_ok "$label is removed"; fi
}

# remove_docker <colima|docker-desktop>: take that away. The user's Docker
# data stays unless they say yes to Docker Desktop's data question. The
# answer is saved none last, so a failure leaves it as it was for doctor to report.
remove_docker() {
  local name=$1 state='' zap=() app="$OMAMAC_APPLICATIONS/${CASK_APP[docker-desktop]}"
  local box="Docker Desktop: the app and lazydocker. Your images, containers and volumes stay."
  if [ "${CHOICES[docker]:-none}" != "$name" ]; then
    if [ "$name" = colima ]; then ui_info "colima isn't installed by omamac."
    else ui_info "Docker Desktop isn't installed by omamac."; fi
    exit 0
  fi
  if [ "$name" = colima ]; then
    ui_box "colima: colima, docker, docker-compose, docker-buildx and lazydocker. Your images, containers and volumes stay in ~/.colima."
    ask_yes "Remove colima?" || { ui_info "Nothing was removed."; exit 0; }
    log_start
    docker_uninstall_colima || return
    CHOICES[docker]=none
    OMAMAC_STEP='saving your answers'
    choices_save "$OMAMAC_CHOICES_FILE"
    ui_ok "colima is removed"
    return
  fi
  state=$(core_cask_state docker-desktop) || return
  # A trashed app has nothing to write to.
  [ "$state" != brew ] || remove_app_management_ok "$app" docker-desktop
  # A hand-installed app has no cask, so Homebrew has no data list to delete.
  if core_cask_listed docker-desktop; then
    ui_info "On yes, Homebrew also deletes Docker Desktop's images, containers and volumes, and ~/.docker (Docker's settings and saved logins)."
    if ask_yes "Also remove Docker Desktop's settings and data?"; then
      zap=(--zap)
      box="Docker Desktop: the app and lazydocker, with Docker Desktop's images, containers, volumes and ~/.docker."
    fi
  fi
  ui_box "$box"
  [ "$state" != hand ] || ui_info "Docker Desktop wasn't installed by omamac, so it stays."
  ask_yes "Remove Docker Desktop?" || { ui_info "Nothing was removed."; exit 0; }
  log_start
  docker_uninstall_desktop "${zap[@]}" || return
  if [ "$state" != hand ]; then dock_remove_app "${CASK_APP[docker-desktop]}" "Docker Desktop" || return; fi
  CHOICES[docker]=none
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  ui_ok "Docker Desktop is removed"
}

# remove_refuse_core <name>: stop when name is a core tool. bin/omamac calls it
# before loading the answers, so it works without them too.
remove_refuse_core() {
  local v
  # bash and gum are omamac's own, so they count as core.
  for v in "${CORE_FORMULAS[@]}" "${CORE_CASKS[@]}" bash gum zsh; do
    if [ "$1" = "$v" ]; then
      ui_fail "$1 is part of omamac's core and can't be removed on its own."
      exit 1
    fi
  done
}

# remove_run [<name>]: CHOICES is loaded (bin/omamac did that). Nothing is
# changed before "Remove?" is yes, and the choice is saved last, so a failure
# leaves it saved for doctor to report.
remove_run() {
  local name=${1:-} key='' k v label status tool joined list ids=() options=() tools=() all=() apps=()
  OMAMAC_STEP='checking what to remove'
  if [ "$#" -eq 0 ]; then
    for k in "${REMOVE_KEYS[@]}"; do
      read -ra ids <<< "${CHOICES[$k]:-}"
      for v in "${ids[@]}"; do options+=("$(question_label "$k" "$v"):$v"); done
    done
    [ "${CHOICES[desktops]:-}" != yes ] || options+=("${QUESTION_TITLE[desktops]}:desktops")
    [ "${CHOICES[window_margins]:-}" != yes ] || options+=("${QUESTION_TITLE[window_margins]}:window-margins")
    [ "${CHOICES[dock]:-}" != yes ] || options+=("${QUESTION_TITLE[dock]}:dock")
    [ "${CHOICES[dock_autohide]:-}" != yes ] || options+=("${QUESTION_TITLE[dock_autohide]}:dock-autohide")
    while IFS= read -r v; do options+=("$(apps_label "$v"):$v"); done < <(apps_chosen)
    case ${CHOICES[docker]:-none} in
      colima) options+=("colima:colima") ;;
      docker-desktop) options+=("$(question_label docker docker-desktop):docker-desktop") ;;
    esac
    if [ "${#options[@]}" -eq 0 ]; then
      ui_info "omamac installed nothing you can remove."
      exit 0
    fi
    ask_choose "What should omamac remove?" "Nothing:none" "${options[@]}"
    [ "$ASK_PICKED" != none ] || exit 0
    name=$ASK_PICKED
  fi
  case $name in
    desktops | window-margins | dock-autohide) remove_setting "$name"; return ;;
    dock) remove_dock; return ;;
    colima | docker-desktop) remove_docker "$name"; return ;;
  esac
  mapfile -t apps < <(apps_ids)
  for v in "${apps[@]}"; do
    [ "$name" != "$v" ] || { remove_app "$name"; return; }
  done
  for k in "${REMOVE_KEYS[@]}"; do
    if question_has "$k" "$name"; then key=$k; fi
    mapfile -t ids < <(question_values "$k")
    all+=("${ids[@]}")
  done
  if [ -z "$key" ]; then
    ui_fail "omamac can't remove '$name'. It can remove: $(clis_join "${all[@]}" "${apps[@]}" desktops window-margins colima docker-desktop dock dock-autohide)."
    exit 2
  fi
  label=$(question_label "$key" "$name")
  if [[ " ${CHOICES[$key]:-} " != *" $name "* ]]; then
    ui_info "$label isn't installed by omamac."
    exit 0
  fi
  if [ "$key" = languages ]; then
    read -ra tools <<< "${LANGUAGE_TOOLS[$name]}"
    printf -v joined '%s and ' "${tools[@]}"
    ui_box "$label: mise's ${joined% and }"
  else
    ui_box "$label: $(clis_what "$name")"
  fi
  if ! ask_yes "Remove $label?"; then
    ui_info "Nothing was removed."
    exit 0
  fi
  log_start
  choices_drop "$key" "$name"
  if [ "$key" = languages ]; then
    OMAMAC_STEP='writing ~/.config/mise/conf.d/omamac.toml'
    languages_write_dropin
    OMAMAC_STEP="removing $label"
    # MISE_YES: prune asks before it deletes; "Remove?" was the question.
    (cd "$HOME" && MISE_YES=1 ui_run "Removing $label" "$OMAMAC_BREW_PREFIX/bin/mise" prune --tools "${tools[@]}") || return
    OMAMAC_STEP='checking what mise kept'
    for tool in "${tools[@]}"; do
      status=0
      languages_has "$tool" || status=$?
      [ "$status" -ne 2 ] || return 2
      [ "$status" -ne 0 ] || ui_info "mise kept $tool: another of your mise configs uses it."
    done
  else
    OMAMAC_STEP="removing $label"
    # A CLI removed by hand needs no brew call.
    list=$(clis_where installed "$name") || return
    if [ -n "$list" ]; then
      if [ -n "${CLI_FORMULA[$name]:-}" ]; then
        ui_run "Removing $label" "$OMAMAC_BREW_PREFIX/bin/brew" uninstall "${CLI_FORMULA[$name]}"
      else
        ui_run "Removing $label" "$OMAMAC_BREW_PREFIX/bin/brew" uninstall --cask "${CLI_CASK[$name]}"
      fi
    fi
  fi
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  ui_ok "$label is removed"
}
