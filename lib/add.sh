# shellcheck shell=bash
# shellcheck disable=SC2034 # OMAMAC_STEP is read by bin/omamac's ERR trap
# shellcheck disable=SC2004 # CHOICES is associative (lib/choices.sh), so $key is needed
# omamac install: add apps, languages, CLIs and more to the saved
# answers, then apply. Sourced after lib/ask.sh, lib/log.sh, lib/apps.sh and lib/apply.sh.
# update.sh sources it with no lib/ask.sh, for add_command only.

# The questions omamac install asks again, with only their unpicked options.
ADD_KEYS=("${APPS_KEYS[@]}" wispr_flow languages cloud_clis coding_agents desktops window_margins desktop_widgets dock dock_autohide docker)
ADD_SECTIONS=(apps languages cloud-clis coding-agents docker macos)

# add_section <name>: the questions of one section of omamac install, one per line.
# Returns 1 when the name isn't a section.
add_section() {
  case $1 in
    apps) printf '%s\n' "${APPS_KEYS[@]}" wispr_flow ;;
    languages) echo languages ;;
    cloud-clis) echo cloud_clis ;;
    coding-agents) echo coding_agents ;;
    docker) echo docker ;;
    macos) printf '%s\n' desktops window_margins desktop_widgets dock dock_autohide ;;
    *) return 1 ;;
  esac
}

# add_command <key>: the command that asks that question: a yes/no question
# by its own name, any other by its section, the theme by omamac theme.
# Returns 1 for a key neither asks.
add_command() {
  local section keys=()
  [ "$1" != theme ] || { echo "omamac theme"; return 0; }
  [[ " ${ADD_KEYS[*]} " == *" $1 "* ]] || return 1
  [ "${QUESTION_KIND[$1]}" != yesno ] || { echo "omamac install ${1//_/-}"; return 0; }
  for section in "${ADD_SECTIONS[@]}"; do
    mapfile -t keys < <(add_section "$section")
    [[ " ${keys[*]} " != *" $1 "* ]] || { echo "omamac install $section"; return 0; }
  done
  return 1
}

# add_id_key <id>: the question an id answers, the same ids omamac uninstall
# takes: a yes/no question's id is its key with dashes (dock-autohide), any
# other question's are its values. Returns 1 for an unknown id.
add_id_key() {
  local key
  for key in "${ADD_KEYS[@]}"; do
    if [ "${QUESTION_KIND[$key]}" = yesno ]; then
      [ "${key//_/-}" != "$1" ] || { echo "$key"; return 0; }
    elif [ "$1" != none ] && question_has "$key" "$1"; then
      echo "$key"
      return 0
    fi
  done
  return 1
}

# add_targets <name>…: sort what omamac install was given into ADD_ASK (the
# questions of the sections named) and ADD_IDS (key and id, one per line). An
# unknown name stops the run before anything is asked.
add_targets() {
  local name key keys=()
  ADD_ASK=() ADD_IDS=()
  for name in "$@"; do
    if mapfile -t keys < <(add_section "$name") && [ "${#keys[@]}" -gt 0 ]; then
      ADD_ASK+=("${keys[@]}")
    elif key=$(add_id_key "$name"); then
      ADD_IDS+=("$key $name")
    else
      ui_fail "omamac doesn't know '$name'. Name a section ($(clis_join "${ADD_SECTIONS[@]}")) or what to install, such as $(clis_join go docker-desktop vscode)."
      exit 2
    fi
  done
  # Asked in the table's order, each once.
  mapfile -t keys < <(printf '%s\n' "${ADD_ASK[@]}")
  ADD_ASK=()
  for key in "${ADD_KEYS[@]}"; do
    [[ " ${keys[*]} " != *" $key "* ]] || ADD_ASK+=("$key")
  done
}

# add_pick_ids: turn ADD_IDS into picks, as if their questions had been
# answered: an id already picked is said and skipped, a hand-installed app is
# offered to Homebrew. Writes into add_run's picks.
add_pick_ids() {
  local line key id had=() label
  for line in "${ADD_IDS[@]}"; do
    key=${line%% *} id=${line#* }
    case ${QUESTION_KIND[$key]} in
      yesno)
        label=${QUESTION_TITLE[$key]}
        if [ "${CHOICES[$key]:-}" = yes ] || [ "${picks[$key]:-}" = yes ]; then
          ui_info "$label is already on."
          continue
        fi
        CHOICES[$key]=yes
        [ "$key" != wispr_flow ] || apps_ask_adopt wispr-flow
        [ "${CHOICES[$key]}" != yes ] || picks[$key]=yes
        CHOICES[$key]=no
        ;;
      single)
        label=$(question_label "$key" "$id")
        if [ "${CHOICES[$key]:-none}" = "$id" ]; then
          ui_info "$label is already installed."
          continue
        fi
        if [ "${CHOICES[$key]:-none}" != none ] || { [ -n "${picks[$key]:-}" ] && [ "${picks[$key]}" != "$id" ]; }; then
          ui_fail "${QUESTION_TITLE[$key]} is already $(question_label "$key" "${picks[$key]:-${CHOICES[$key]}}"). To switch, uninstall it first: omamac uninstall ${picks[$key]:-${CHOICES[$key]}}."
          exit 2
        fi
        picks[$key]=$id
        ;;
      *)
        label=$(question_label "$key" "$id")
        read -ra had <<< "${CHOICES[$key]:-}"
        if [[ " ${had[*]} ${picks[$key]:-} " == *" $id "* ]]; then
          ui_info "$label is already installed."
          continue
        fi
        # apps_ask_adopt reads and drops from CHOICES; put the saved answer back.
        CHOICES[$key]=$id
        if [[ $key == apps_* ]]; then apps_ask_adopt "$id"; fi
        [ -z "${CHOICES[$key]}" ] || picks[$key]="${picks[$key]:+${picks[$key]} }$id"
        CHOICES[$key]=${had[*]}
        ;;
    esac
  done
}

# add_save_unanswered: when some question had no answer at add_run's start,
# save the answers without the picks: a question asked now has its no (or
# none), every other answer is the saved one.
add_save_unanswered() {
  local key
  [ -n "$unanswered" ] || return 0
  CHOICES=()
  for key in "${!declined[@]}"; do CHOICES[$key]=${declined[$key]}; done
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
}

# add_run [<section or id>…]: CHOICES is loaded (bin/omamac did that). Ask
# every question, only the sections named, or nothing for the ids named; show
# the additions, and save and apply them only after "Install?" is yes, so a no
# changes nothing.
add_run() {
  local key v had=() new=() left=() lines=() labels=() names=() apps=() allow=() joined asked=''
  local -A picks=() declined=()
  local ask=("${ADD_KEYS[@]}") unanswered
  # update names a question added after the first run, and sends the user here.
  # A no, or a no at Install?, is still its answer, so it is saved, or update
  # would name the question again every time.
  unanswered=$(choices_missing)
  if [ "$#" -gt 0 ]; then
    add_targets "$@"
    ask=(${ADD_ASK[@]+"${ADD_ASK[@]}"})
  fi
  OMAMAC_STEP='asking the questions'
  for key in ${ask[@]+"${ask[@]}"}; do
    if [ "${QUESTION_KIND[$key]}" = yesno ]; then
      [ "${CHOICES[$key]:-}" != yes ] || continue
      [ -n "$asked" ] || ask_need_tty
      asked=1
      ask_one "$key"
      # A hand-installed Wispr Flow is offered to Homebrew; a no sets the answer to no.
      if [ "$key" = wispr_flow ] && [ "${CHOICES[$key]}" = yes ]; then apps_ask_adopt wispr-flow; fi
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
    if [[ $key == apps_* ]]; then
      # A hand-installed pick is offered to Homebrew; a no drops it from CHOICES.
      read -ra new <<< "${CHOICES[$key]}"
      if [ "${#new[@]}" -gt 0 ]; then apps_ask_adopt "${new[@]}"; fi
    fi
    picks[$key]=${CHOICES[$key]}
    CHOICES[$key]=${had[*]}
  done
  if [ "$#" -gt 0 ] && [ "${#ADD_IDS[@]}" -gt 0 ]; then
    [ -n "$asked" ] || ask_need_tty
    asked=1
    add_pick_ids
  fi
  if [ -z "$asked" ]; then
    ui_info "You've picked everything omamac offers here."
    exit 0
  fi
  # The answers without the picks, which the loop below merges into CHOICES.
  for key in "${!CHOICES[@]}"; do declined[$key]=${CHOICES[$key]}; done
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
    add_save_unanswered
    ui_info "Nothing picked, so nothing changed."
    exit 0
  fi
  ui_box "${lines[@]}"
  apps_password_ahead
  if ! ask_yes "Install?"; then
    add_save_unanswered
    ui_info "Stopped. Nothing else was changed."
    exit 0
  fi
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  # bin/omamac's ERR trap: from here, a failure is finished by omamac update.
  ADD_SAVED=1
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
  read -ra had <<< "${picks[languages]:-}"
  for v in ${had[@]+"${had[@]}"}; do lines+=("$(question_label languages "$v"): ${LANGUAGE_COMMANDS[$v]}"); done
  # mise sets the PATH before each prompt, and zsh looks up a command it hasn't
  # seen, so a shell already open (herdr keeps them) needs no restart.
  ui_box "${lines[@]}" "Log: $OMAMAC_LOG" "They work in every shell; one already open needs one Enter first."
}
