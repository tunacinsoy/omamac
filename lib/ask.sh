# shellcheck shell=bash
# shellcheck disable=SC2004 # CHOICES is associative (lib/choices.sh), so $key is needed
# Asking the first-run questions, the summary and "Install?". Sourced after
# lib/ui.sh, lib/questions.sh and lib/choices.sh. Every prompt reads the
# terminal, and each exit status is caught where it happens, so a "no" or a
# Ctrl-C never reaches the caller's ERR trap.

# gum exits 130 on Ctrl-C.
ask_stopped() {
  ui_fail "Stopped. Nothing was changed."
  exit 130
}

# ask_broken <what>: gum failed some other way.
ask_broken() {
  ui_fail "omamac couldn't ask about $1. Run the one-liner again."
  exit 1
}

# ask_one <key>: ask one question and set CHOICES[key].
ask_one() {
  local key=$1 status=0 out normal options=() limit=()
  if [ "${QUESTION_KIND[$key]}" = yesno ]; then
    "$UI_GUM" confirm --default=false "${QUESTION_TEXT[$key]}" < "$OMAMAC_TTY" || status=$?
    case $status in
      0) CHOICES[$key]=yes ;;
      1) CHOICES[$key]=no ;;
      130) ask_stopped ;;
      *) ask_broken "${QUESTION_TITLE[$key]}" ;;
    esac
    return 0
  fi
  mapfile -t options <<< "${QUESTION_OPTIONS[$key]}"
  [ "${QUESTION_KIND[$key]}" = single ] || limit=(--no-limit)
  out=$("$UI_GUM" choose "${limit[@]}" --header "${QUESTION_TEXT[$key]}" --label-delimiter=: \
    "${options[@]}" < "$OMAMAC_TTY") || status=$?
  [ "$status" -ne 130 ] || ask_stopped
  [ "$status" -eq 0 ] || ask_broken "${QUESTION_TITLE[$key]}"
  # gum prints one value per line; the file holds them space-separated.
  normal=$(choices_normalise "$key" "$(paste -sd' ' - <<< "$out")") || ask_broken "${QUESTION_TITLE[$key]}"
  CHOICES[$key]=$normal
}

# ask_missing: ask every question that has no saved answer, in table order.
ask_missing() {
  local key keys intro=0
  mapfile -t keys < <(choices_missing)
  for key in "${keys[@]}"; do
    if [[ $key == apps_* ]] && [ "$intro" -eq 0 ]; then
      ui_info "Desktop apps, installed with Homebrew. Pick any, or none."
      intro=1
    fi
    ask_one "$key"
  done
}

# ask_summary: one line per answer, labels as the questions showed them.
ask_summary() {
  local key value v joined lines=() words=() labels=()
  for key in "${QUESTION_KEYS[@]}"; do
    value=${CHOICES[$key]:-}
    if [ -z "$value" ]; then
      lines+=("${QUESTION_TITLE[$key]}: none")
      continue
    fi
    labels=()
    read -ra words <<< "$value"
    for v in "${words[@]}"; do labels+=("$(question_label "$key" "$v")"); done
    printf -v joined '%s, ' "${labels[@]}"
    lines+=("${QUESTION_TITLE[$key]}: ${joined%, }")
  done
  ui_box "${lines[@]}"
}

# ask_install: 0 on yes, 1 on no. Enter alone is no.
ask_install() {
  local status=0
  "$UI_GUM" confirm --default=false "Install?" < "$OMAMAC_TTY" || status=$?
  case $status in
    0 | 1) return "$status" ;;
    130) ask_stopped ;;
    *) ask_broken "Install?" ;;
  esac
}
