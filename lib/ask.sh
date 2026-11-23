# shellcheck shell=bash
# shellcheck disable=SC2004 # CHOICES is associative (lib/choices.sh), so $key is needed
# Asking the first-run questions, the summary, "Install?" and omamac's other
# prompts. Sourced after lib/ui.sh, lib/questions.sh and lib/choices.sh. Every
# prompt reads the terminal, and each exit status is caught where it happens,
# so a "no" or a Ctrl-C never reaches the caller's ERR trap.

# gum exits 130 on Ctrl-C. Homebrew and omamac may already be in place, hence "else".
ask_stopped() {
  ui_fail "Stopped. Nothing else was changed."
  exit 130
}

# ask_has_tty: the terminal can be opened. Not [ -r ]: /dev/tty is readable by
# everyone even when there is no terminal, but opening it then fails.
ask_has_tty() { { : < "$OMAMAC_TTY"; } 2>/dev/null; }

# A missing terminal would make every yes/no prompt fail with exit 1, which
# reads as "no". boot.sh checks it too; this keeps ask.sh safe on its own.
ask_need_tty() {
  ask_has_tty && return 0
  ui_fail "omamac needs a terminal to ask its questions. Run it from Terminal."
  exit 1
}

# ask_broken <what>: gum failed some other way. Under omamac <command>
# (bin/omamac sets OMAMAC_CMD), that command is what to run again.
ask_broken() {
  if [ -n "${OMAMAC_CMD:-}" ]; then
    ui_fail "omamac couldn't ask about $1. Run omamac $OMAMAC_CMD again."
  else
    ui_fail "omamac couldn't ask about $1. Run the one-liner again."
  fi
  exit 1
}

# ask_choose_stopped <status>: a pick list's Esc or Ctrl-C stops the run.
# gum 2.0.2 exits 1 on Esc at gum choose, which would otherwise read as
# "couldn't ask", a fault. A real gum failure that exits 1 also reads as
# Stopped; gum gives no way to tell them apart, and that is accepted.
# Yes/no prompts differ: there exit 1 is no, and Esc is no.
ask_choose_stopped() {
  case $1 in
    1 | 130) ask_stopped ;;
  esac
}

# ask_one <key> [<value>…]: ask one question and set CHOICES[key]. With values,
# only those options are offered (in table order), and CHOICES[key] is the picks.
ask_one() {
  local key=$1 status=0 out normal option options=() kept=() limit=()
  local -A only=()
  shift
  [ -z "${QUESTION_HELP[$key]:-}" ] || ui_info "${QUESTION_HELP[$key]}"
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
  if [ "$#" -gt 0 ]; then
    for option in "$@"; do only[$option]=1; done
    for option in "${options[@]}"; do [ -z "${only[${option##*:}]:-}" ] || kept+=("$option"); done
    options=("${kept[@]}")
  fi
  [ "${QUESTION_KIND[$key]}" = single ] || limit=(--no-limit)
  out=$("$UI_GUM" choose "${limit[@]}" --header "${QUESTION_TEXT[$key]}" --label-delimiter=: \
    "${options[@]}" < "$OMAMAC_TTY") || status=$?
  ask_choose_stopped "$status"
  [ "$status" -eq 0 ] || ask_broken "${QUESTION_TITLE[$key]}"
  # gum prints one value per line; the file holds them space-separated.
  normal=$(choices_normalise "$key" "$(paste -sd' ' - <<< "$out")") || ask_broken "${QUESTION_TITLE[$key]}"
  CHOICES[$key]=$normal
}

# ask_missing: ask every question that has no saved answer, in table order.
ask_missing() {
  local key keys intro=0
  mapfile -t keys < <(choices_missing)
  [ "${#keys[@]}" -eq 0 ] || ask_need_tty
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
  local key value v i joined lines=() words=() labels=()
  for key in "${QUESTION_KEYS[@]}"; do
    value=${CHOICES[$key]:-}
    if [ -z "$value" ]; then
      lines+=("${QUESTION_TITLE[$key]}: none")
      continue
    fi
    labels=()
    read -ra words <<< "$value"
    for v in "${words[@]}"; do labels+=("$(question_label "$key" "$v")"); done
    # A line longer than 74 characters goes on, indented, so the box fits an
    # 80-column terminal (a border and two spaces of padding on each side).
    joined="${QUESTION_TITLE[$key]}:"
    for i in "${!labels[@]}"; do
      v=${labels[$i]}
      [ "$i" -eq $((${#labels[@]} - 1)) ] || v+=,
      if [ $((${#joined} + 1 + ${#v})) -gt 74 ]; then
        lines+=("$joined")
        joined="  $v"
      else
        joined+=" $v"
      fi
    done
    lines+=("$joined")
  done
  ui_box "${lines[@]}"
}

# ask_yes <text>: 0 on yes, 1 on no. Enter alone is no.
ask_yes() {
  local status=0
  ask_need_tty
  "$UI_GUM" confirm --default=false "$1" < "$OMAMAC_TTY" || status=$?
  case $status in
    0 | 1) return "$status" ;;
    130) ask_stopped ;;
    *) ask_broken "$1" ;;
  esac
}

# ask_choose <header> <Label:value>…: one pick; sets ASK_PICKED to its value.
# Not printed for $(…): there, ask_stopped would leave only the subshell, not the script.
ask_choose() {
  local header=$1 status=0 out
  shift
  ask_need_tty
  out=$("$UI_GUM" choose --header "$header" --label-delimiter=: "$@" < "$OMAMAC_TTY") || status=$?
  ask_choose_stopped "$status"
  [ "$status" -eq 0 ] || ask_broken "$header"
  # shellcheck disable=SC2034 # read by the caller
  ASK_PICKED=$out
}
