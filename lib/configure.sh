# shellcheck shell=bash
# shellcheck disable=SC2034 # OMAMAC_STEP is read by bin/omamac's ERR trap, CONFIGURE_SAVED by omamac_failed
# shellcheck disable=SC2004 # CHOICES is associative (lib/choices.sh), so $key is needed
# omamac configure: turn one of the seven macOS settings on or off. Sourced
# after lib/ask.sh, lib/log.sh, lib/settings.sh, lib/dock.sh and lib/add.sh.

# configure_key <name>: the answer a setting name stands for (its key with
# dashes: dock-autohide is dock_autohide). Returns 1 for any other name.
configure_key() {
  local key
  for key in "${SETTINGS_ANSWERS[@]}"; do
    [ "${key//_/-}" != "$1" ] || { echo "$key"; return 0; }
  done
  return 1
}

# configure_names: the setting names, in table order, joined for a sentence.
configure_names() {
  local key names=()
  for key in "${SETTINGS_ANSWERS[@]}"; do names+=("${key//_/-}"); done
  clis_join "${names[@]}"
}

# configure_refuse <name>: install and uninstall take no settings. When name
# is one (or install's old macos section), say where it lives now and exit 2.
configure_refuse() {
  if [ "$1" = macos ]; then
    ui_fail "The macOS settings moved: run omamac configure."
    exit 2
  fi
  configure_key "$1" > /dev/null || return 0
  ui_fail "$1 is a macOS setting: run omamac configure $1."
  exit 2
}

# configure_state <key>: on when the answer is yes; no answer counts as off.
configure_state() { if [ "${CHOICES[$1]:-}" = yes ]; then echo on; else echo off; fi; }

# configure_does <key>: what turning the setting on does, for its box.
configure_does() {
  case $1 in
    desktops) echo "desktops keep their order, switching to an app goes to its desktop, Ctrl 1–6 jump to desktops 1 to 6, and Reduce motion turns on" ;;
    window_margins) echo "tiled windows get margins between them" ;;
    desktop_widgets) echo "widgets leave the desktop and Stage Manager" ;;
    dock) echo "Apple's apps and Downloads leave the Dock (not your Mac), the apps omamac installs take their place, and suggested and recent apps turn off" ;;
    dock_autohide) echo "the Dock hides when you're not using it" ;;
    tap_to_click) echo "a tap on the trackpad clicks" ;;
    three_finger_drag) echo "three fingers on the trackpad drag, and swiping between desktops and to Mission Control moves to four fingers" ;;
  esac
}

# configure_undoes <key>: what turning the setting off puts back, for its box.
configure_undoes() {
  case $1 in
    dock) echo "your Dock as it was before omamac cleaned it; changes you made to it since are undone" ;;
    *) settings_what "$1" ;;
  esac
}

# configure_box <key> <on|off>: what the change does, before its question.
configure_box() {
  local title=${QUESTION_TITLE[$1]} what label=Changes
  if [ "$2" = on ]; then what=$(configure_does "$1"); else what=$(configure_undoes "$1") label="Puts back"; fi
  if ui_term; then
    ui_titled warn "Turns $2" "Setting"$'\t'"$title" "$label"$'\t'"$what"
  else
    ui_box "$title: $what."
  fi
}

# configure_done <title> <on|off>: the result, one row.
configure_done() {
  if ui_term; then ui_row ok "$1" "$2"; else ui_ok "$1 is $2"; fi
}

# configure_save_no <key>: a setting with no saved answer (a question added
# after the first run) gets its no, so update stops naming it.
configure_save_no() {
  [ -z "${CHOICES[$1]+set}" ] || return 0
  CHOICES[$1]=no
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
}

# configure_on <key>: save yes first, as install does, so a failure is
# finished by omamac update; then set only that setting.
configure_on() {
  local key=$1 title=${QUESTION_TITLE[$1]}
  CHOICES[$key]=yes
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  CONFIGURE_SAVED=1
  log_start
  OMAMAC_STEP="turning on $title"
  settings_apply "$key"
  configure_done "$title" on
}

# configure_off <key>: put the earlier values back (and the Dock, for dock),
# then save no last, so a failure leaves it yes for a rerun to finish.
configure_off() {
  local key=$1 title=${QUESTION_TITLE[$1]}
  log_start
  if [ "$key" = dock ]; then dock_restore || return; fi
  settings_uninstall "$key"
  CHOICES[$key]=no
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  configure_done "$title" off
}

# configure_run [<setting> [on|off]]: CHOICES is loaded (bin/omamac did that,
# and checked the words). With no setting, ask which; with no on or off, show
# what changes and ask; with one, ask nothing.
configure_run() {
  local name=${1:-} want=${2:-} key state title options=()
  OMAMAC_STEP='checking your settings'
  if [ -z "$name" ]; then
    for key in "${SETTINGS_ANSWERS[@]}"; do
      options+=("${QUESTION_TITLE[$key]} ($(configure_state "$key")):${key//_/-}")
    done
    ask_choose "What do you want to change?" "${options[@]}"
    name=$ASK_PICKED
  fi
  if ! key=$(configure_key "$name"); then
    if add_id_key "$name" > /dev/null; then
      ui_fail "$name isn't a setting: run omamac install $name or omamac uninstall $name."
    else
      ui_fail "omamac doesn't know '$name'. Settings: $(configure_names)."
    fi
    exit 2
  fi
  title=${QUESTION_TITLE[$key]}
  state=$(configure_state "$key")
  if [ -z "$want" ]; then
    if [ "$state" = on ]; then want=off; else want=on; fi
    configure_box "$key" "$want"
    if ! ask_yes "Turn $want $title?"; then
      configure_save_no "$key"
      ui_info "Nothing changed."
      exit 0
    fi
  elif [ "$want" = "$state" ]; then
    configure_save_no "$key"
    ui_info "$title is already $want."
    exit 0
  fi
  # A failure from here names this exact change, not the menu.
  OMAMAC_CMD="configure ${key//_/-} $want"
  if [ "$want" = on ]; then configure_on "$key"; else configure_off "$key"; fi
}
