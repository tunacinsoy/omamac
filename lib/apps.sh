# shellcheck shell=bash
# shellcheck disable=SC2034 # the tables are read by the scripts that source this file
# The desktop apps omamac can install, one file per app in apps/<id>.
# Sourced after lib/questions.sh, lib/choices.sh and lib/core.sh; needs OMAMAC_CHECKOUT.
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
