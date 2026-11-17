# shellcheck shell=bash
# shellcheck disable=SC2034 # OMAMAC_STEP is read by bin/omamac's ERR trap
# shellcheck disable=SC2004 # CHOICES is associative (lib/choices.sh), so $key is needed
# omamac install: add languages and cloud CLIs to the saved answers, then
# apply. Sourced after lib/ask.sh, lib/log.sh and lib/apply.sh.

# The questions omamac install asks again, with only their unpicked options.
ADD_KEYS=(languages cloud_clis)

# add_run: CHOICES is loaded (bin/omamac did that). Ask, show the additions,
# and save and apply them only after "Install?" is yes, so a no changes nothing.
add_run() {
  local key v had=() left=() lines=() labels=() names=() joined asked=''
  local -A picks=()
  OMAMAC_STEP='asking the questions'
  for key in "${ADD_KEYS[@]}"; do
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
    ui_info "Everything omamac offers here is installed."
    exit 0
  fi
  for key in "${ADD_KEYS[@]}"; do
    [ -n "${picks[$key]:-}" ] || continue
    read -ra had <<< "${picks[$key]}"
    choices_add "$key" "${had[@]}"
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
  if ! ask_yes "Install?"; then
    ui_info "Stopped. Nothing else was changed."
    exit 0
  fi
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  log_start
  apply_all
  OMAMAC_STEP='printing the summary'
  printf -v joined '%s, ' "${names[@]}"
  ui_box "Installed: ${joined%, }" "Log: $OMAMAC_LOG" "Open a new terminal window to use them."
}
