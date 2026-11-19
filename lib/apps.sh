# shellcheck shell=bash
# shellcheck disable=SC2034 # the tables are read by the scripts that source this file
# The desktop apps omamac can install, one file per app in apps/<id>.
# Sourced after lib/questions.sh, lib/choices.sh and lib/core.sh; needs OMAMAC_CHECKOUT.
# The install steps also use clis_join (lib/clis.sh) and DOCKER_NOTES (lib/docker.sh).
# Each file is read as data, line by line, never sourced.

declare -gA APP_CASK=() APP_BUNDLE=() APP_PASSWORD=() APP_ALLOW=()

# apps_load: fill the tables from $OMAMAC_CHECKOUT/apps. On a bad file or
# line, says which and returns 1.
apps_load() {
  local file id line key value n
  for file in "$OMAMAC_CHECKOUT"/apps/*; do
    [ -f "$file" ] || continue
    id=${file##*/}
    n=0
    APP_ALLOW[$id]=''
    APP_PASSWORD[$id]=''
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      [[ -z $line || $line == \#* ]] && continue
      if [[ ! $line =~ ^(cask|app|password|allow)=(.+)$ ]]; then
        echo "apps/$id, line $n: not a known key=value line." >&2
        return 1
      fi
      key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
      case $key in
        cask) APP_CASK[$id]=$value ;;
        app) APP_BUNDLE[$id]=$value ;;
        password) APP_PASSWORD[$id]=$value ;;
        allow) APP_ALLOW[$id]+="${APP_ALLOW[$id]:+$'\n'}$value" ;;
      esac
    done < "$file"
    if [ -z "${APP_CASK[$id]:-}" ] || [ -z "${APP_BUNDLE[$id]:-}" ]; then
      echo "apps/$id: needs a cask and an app line." >&2
      return 1
    fi
    CASK_APP[${APP_CASK[$id]}]=${APP_BUNDLE[$id]}
  done
}
apps_load || return 1

APPS_KEYS=(apps_browsers apps_communication apps_media apps_screen_recording apps_storage apps_developer apps_productivity)

# apps_ids: every app id, in question order.
apps_ids() {
  local key
  for key in "${APPS_KEYS[@]}"; do question_values "$key"; done
  echo wispr-flow
}

# apps_key <id>: the question that holds the id.
apps_key() {
  local key
  [ "$1" != wispr-flow ] || { echo wispr_flow; return; }
  for key in "${APPS_KEYS[@]}"; do
    if question_has "$key" "$1"; then echo "$key"; return; fi
  done
  return 1
}

# apps_label <id>: the name shown to the user.
apps_label() {
  local key
  [ "$1" != wispr-flow ] || { echo "${QUESTION_TITLE[wispr_flow]}"; return; }
  key=$(apps_key "$1") || return
  question_label "$key" "$1"
}

# apps_chosen: the picked ids, in question order.
apps_chosen() {
  local key id
  local -a words
  for key in "${APPS_KEYS[@]}"; do
    read -ra words <<< "${CHOICES[$key]:-}"
    for id in "${words[@]}"; do echo "$id"; done
  done
  [ "${CHOICES[wispr_flow]:-}" != yes ] || echo wispr-flow
}

# apps_drop <id>: forget the pick, change nothing else.
apps_drop() {
  if [ "$1" = wispr-flow ]; then CHOICES[wispr_flow]=no; else choices_drop "$(apps_key "$1")" "$1"; fi
}

# apps_allow <id>…: the permission lines of those apps, one per line, for the summaries.
apps_allow() {
  local id
  for id in "$@"; do [ -z "${APP_ALLOW[$id]}" ] || printf '%s\n' "${APP_ALLOW[$id]}"; done
}

# Docker Desktop's cask shares the password step, though it isn't a catalog app.
apps_step_cask() { if [ "$1" = docker-desktop ]; then echo docker-desktop; else echo "${APP_CASK[$1]}"; fi; }

# apps_step_labels <id>…: their names, joined with clis_join.
apps_step_labels() {
  local id labels=()
  for id in "$@"; do
    if [ "$id" = docker-desktop ]; then
      labels+=("$(question_label docker docker-desktop)")
    else
      labels+=("$(apps_label "$id")")
    fi
  done
  clis_join "${labels[@]}"
}

# apps_password_say <id>…: the line before a Homebrew call that asks for the password.
apps_password_say() { ui_info "Homebrew asks for your password for: $(apps_step_labels "$@")."; }

# apps_password_pending [<id>…]: the ids the password step would install now,
# one per line: the chosen apps with password=yes, then Docker Desktop when
# chosen, each only when its app is missing. With ids, only those.
# Returns non-zero if Homebrew can't list.
apps_password_pending() {
  local ids=("$@") id state
  if [ "$#" -eq 0 ]; then
    while IFS= read -r id; do
      [ "${APP_PASSWORD[$id]}" != yes ] || ids+=("$id")
    done < <(apps_chosen)
    [ "${CHOICES[docker]:-none}" != docker-desktop ] || ids+=(docker-desktop)
  fi
  for id in "${ids[@]}"; do
    state=$(core_cask_state "$(apps_step_cask "$id")") || return
    [ "$state" != missing ] || echo "$id"
  done
}

# apps_password_ahead: before "Install?", say whom the password step asks for.
# The line never holds the text "Install?": test/vm.exp answers its first sighting.
apps_password_ahead() {
  local list ids=()
  list=$(apps_password_pending) || return
  [ -n "$list" ] || return 0
  mapfile -t ids <<< "$list"
  ui_info "Homebrew asks for your password once more, after you confirm, for: $(apps_step_labels "${ids[@]}")."
}

# apps_install_password [<id>…]: the password step. Homebrew resets sudo once
# per command and asks itself, so the casks that need it share one install
# call, early, with no spinner to hide the prompt. A cask Homebrew lists whose
# app is gone needs reinstall, a second call. || return on each step: doctor's
# Reinstall runs this with errexit off.
apps_install_password() {
  local list ids=() id install=() reinstall=() icasks=() rcasks=() cask brew="$OMAMAC_BREW_PREFIX/bin/brew"
  list=$(apps_password_pending "$@") || return
  [ -n "$list" ] || return 0
  mapfile -t ids <<< "$list"
  for id in "${ids[@]}"; do
    cask=$(apps_step_cask "$id")
    if core_cask_listed "$cask"; then
      reinstall+=("$id") rcasks+=("$cask")
    else
      install+=("$id") icasks+=("$cask")
    fi
  done
  OMAMAC_STEP="installing $(apps_step_labels "${ids[@]}")"
  apps_password_say "${ids[@]}"
  if [ "${#install[@]}" -gt 0 ]; then
    ui_run_open "Installing $(apps_step_labels "${install[@]}")" \
      "$brew" install --cask "${icasks[@]}" || return
  fi
  if [ "${#reinstall[@]}" -gt 0 ]; then
    ui_run_open "Reinstalling $(apps_step_labels "${reinstall[@]}")" \
      "$brew" reinstall --cask "${rcasks[@]}" || return
  fi
  if [[ " ${ids[*]} " == *" docker-desktop "* ]]; then
    DOCKER_NOTES+=("Open Docker Desktop once to finish its setup.")
  fi
}

# apps_install [<id>…]: the chosen apps without password=yes, or the given
# ids, one Homebrew call each, so a failure names the app.
apps_install() {
  local ids=("$@") id label cask state brew="$OMAMAC_BREW_PREFIX/bin/brew"
  if [ "$#" -eq 0 ]; then
    while IFS= read -r id; do
      [ "${APP_PASSWORD[$id]}" = yes ] || ids+=("$id")
    done < <(apps_chosen)
  fi
  for id in "${ids[@]}"; do
    label=$(apps_label "$id") || return
    cask=${APP_CASK[$id]}
    OMAMAC_STEP="installing $label"
    state=$(core_cask_state "$cask") || return
    case $state in
      missing)
        # A plain install of a cask Homebrew lists does nothing; reinstall puts the app back.
        if core_cask_listed "$cask"; then
          ui_run "Reinstalling $label" "$brew" reinstall --cask "$cask" || return
        else
          ui_run "Installing $label" "$brew" install --cask "$cask" || return
        fi
        ;;
      hand) ui_info "$label is already installed, not through Homebrew. omamac won't update it." ;;
    esac
  done
}
