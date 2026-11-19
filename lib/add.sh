# shellcheck shell=bash
# shellcheck disable=SC2034 # OMAMAC_STEP is read by bin/omamac's ERR trap
# shellcheck disable=SC2004 # CHOICES is associative (lib/choices.sh), so $key is needed
# omamac install: add apps, languages, cloud CLIs and more to the saved
# answers, then apply. Sourced after lib/ask.sh, lib/log.sh, lib/apps.sh and lib/apply.sh.

# The questions omamac install asks again, with only their unpicked options.
ADD_KEYS=("${APPS_KEYS[@]}" wispr_flow languages cloud_clis desktops window_margins docker)

# add_run: CHOICES is loaded (bin/omamac did that). Ask, show the additions,
# and save and apply them only after "Install?" is yes, so a no changes nothing.
add_run() {
  local key v had=() left=() lines=() labels=() names=() apps=() allow=() joined asked=''
  local -A picks=()
  OMAMAC_STEP='asking the questions'
  for key in "${ADD_KEYS[@]}"; do
    if [ "${QUESTION_KIND[$key]}" = yesno ]; then
      [ "${CHOICES[$key]:-}" != yes ] || continue
      [ -n "$asked" ] || ask_need_tty
      asked=1
      ask_one "$key"
      # A yes is applied only after "Install?"; put the saved answer back.
      [ "${CHOICES[$key]}" != yes ] || picks[$key]=yes
      CHOICES[$key]=no
      continue
    fi
    if [ "${QUESTION_KIND[$key]}" = single ]; then
      # Asked only while the answer is none, with every option; "none" is first
      # in the list, so Enter alone adds nothing.
      [ "${CHOICES[$key]:-none}" = none ] || continue
      [ -n "$asked" ] || ask_need_tty
      asked=1
      ask_one "$key"
      # A pick is applied only after "Install?"; put the saved answer back.
      [ "${CHOICES[$key]}" = none ] || picks[$key]=${CHOICES[$key]}
      CHOICES[$key]=none
      continue
    fi
    read -ra had <<< "${CHOICES[$key]:-}"
    left=()
    while IFS= read -r v; do
      [[ " ${had[*]} " == *" $v "* ]] || left+=("$v")
    done < <(question_values "$key")
    [ "${#left[@]}" -gt 0 ] || continue
    [ -n "$asked" ] || ask_need_tty
    asked=1
    # ask_one sets CHOICES[key] to the new picks; put the saved answer back.
    ask_one "$key" "${left[@]}"
    picks[$key]=${CHOICES[$key]}
    CHOICES[$key]=${had[*]}
  done
  if [ -z "$asked" ]; then
    ui_info "You've picked everything omamac offers here."
    exit 0
  fi
  for key in "${ADD_KEYS[@]}"; do
    [ -n "${picks[$key]:-}" ] || continue
    if [ "${QUESTION_KIND[$key]}" = yesno ]; then
      CHOICES[$key]=yes
      [ "$key" != wispr_flow ] || apps+=(wispr-flow)
      names+=("${QUESTION_TITLE[$key]}")
      lines+=("${QUESTION_TITLE[$key]}")
      continue
    fi
    if [ "${QUESTION_KIND[$key]}" = single ]; then
      CHOICES[$key]=${picks[$key]}
      v=$(question_label "$key" "${picks[$key]}")
      names+=("$v")
      lines+=("${QUESTION_TITLE[$key]}: $v")
      continue
    fi
    read -ra had <<< "${picks[$key]}"
    choices_add "$key" "${had[@]}"
    [[ $key != apps_* ]] || apps+=("${had[@]}")
    labels=()
    for v in "${had[@]}"; do labels+=("$(question_label "$key" "$v")"); done
    names+=("${labels[@]}")
    printf -v joined '%s, ' "${labels[@]}"
    lines+=("${QUESTION_TITLE[$key]}: ${joined%, }")
  done
  if [ "${#lines[@]}" -eq 0 ]; then
    ui_info "Nothing picked, so nothing changed."
    exit 0
  fi
  ui_box "${lines[@]}"
  apps_password_ahead
  if ! ask_yes "Install?"; then
    ui_info "Stopped. Nothing else was changed."
    exit 0
  fi
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  log_start
  apply_all
  OMAMAC_STEP='printing the summary'
  lines=()
  if [ "${#names[@]}" -gt 0 ]; then
    printf -v joined '%s, ' "${names[@]}"
    lines=("Installed: ${joined%, }")
  fi
  if [ "${#apps[@]}" -gt 0 ]; then
    lines+=("The first time you open each app, macOS asks you to confirm; click Open.")
    mapfile -t allow < <(apps_allow "${apps[@]}")
    [ "${#allow[@]}" -eq 0 ] || lines+=("${allow[@]}")
  fi
  [ "${#DOCKER_NOTES[@]}" -eq 0 ] || lines+=("${DOCKER_NOTES[@]}")
  ui_box "${lines[@]}" "Log: $OMAMAC_LOG" "Open a new terminal window to use them."
}
