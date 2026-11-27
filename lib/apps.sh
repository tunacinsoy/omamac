# shellcheck shell=bash
# shellcheck disable=SC2034 # the tables are read by the scripts that source this file
# The desktop apps omamac can install, one file per app in apps/<id>.
# Sourced after lib/questions.sh, lib/choices.sh and lib/core.sh; needs OMAMAC_CHECKOUT.
# The install steps also use clis_join (lib/clis.sh) and DOCKER_NOTES (lib/docker.sh).
# Each file is read as data, line by line, never sourced.

declare -gA APP_CASK=() APP_BUNDLE=() APP_PASSWORD=() APP_ALLOW=() APP_DEFAULTS=()

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
    APP_DEFAULTS[$id]=''
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      [[ -z $line || $line == \#* ]] && continue
      if [[ ! $line =~ ^(cask|app|password|allow|defaults)=(.+)$ ]]; then
        echo "apps/$id, line $n: not a known key=value line." >&2
        return 1
      fi
      key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
      if [ "$key" = defaults ] && [[ ! $value =~ ^[^\ ]+\ [^\ ]+\ (bool|int|string)\ .+$ ]]; then
        echo "apps/$id, line $n: a defaults line is <domain> <key> <bool|int|string> <value>." >&2
        return 1
      fi
      case $key in
        cask) APP_CASK[$id]=$value ;;
        app) APP_BUNDLE[$id]=$value ;;
        password) APP_PASSWORD[$id]=$value ;;
        allow) APP_ALLOW[$id]+="${APP_ALLOW[$id]:+$'\n'}$value" ;;
        defaults) APP_DEFAULTS[$id]+="${APP_DEFAULTS[$id]:+$'\n'}$value" ;;
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

APPS_KEYS=(apps_browsers apps_communication apps_media apps_screen_recording apps_storage apps_developer apps_ai apps_productivity)

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

# The apps the user let Homebrew take over, for this run only. apps_install adopts them.
APPS_ADOPT=()

# apps_ask_adopt <id>…: offer each hand-installed app to Homebrew. Yes puts the
# id in APPS_ADOPT; no drops the pick. An installer-package app isn't asked:
# Homebrew could only take it over by installing it again, so it's dropped.
# Not run in $(…): it asks. Returns non-zero if Homebrew can't list.
apps_ask_adopt() {
  local id label state
  for id in "$@"; do
    state=$(core_cask_state "${APP_CASK[$id]}") || return
    [ "$state" = hand ] || continue
    label=$(apps_label "$id") || return
    if [ "${APP_PASSWORD[$id]}" = yes ]; then
      ui_info "$label is already installed, not through Homebrew. Homebrew can only take it over by installing it again, so omamac leaves it."
      apps_drop "$id"
      continue
    fi
    ui_info "$label is already installed, but not through Homebrew. Homebrew can take it over, so it's updated and managed like your other apps."
    if ask_yes "Let Homebrew take over $label?"; then
      APPS_ADOPT+=("$id")
    else
      ui_info "omamac leaves $label as it is and drops it from your picks."
      apps_drop "$id"
    fi
  done
}

# apps_allow <id>…: the permission lines of those apps, one per line, for the summaries.
apps_allow() {
  local id
  for id in "$@"; do [ -z "${APP_ALLOW[$id]}" ] || printf '%s\n' "${APP_ALLOW[$id]}"; done
}

# apps_running <id>: succeeds when the app's program runs. ps, not pgrep: on
# macOS 27 pgrep misses some apps (see theme_signal).
apps_running() {
  # shellcheck disable=SC2009 # pgrep misses some apps on macOS 27
  ps -axo comm= 2>/dev/null | grep -qF "/${APP_BUNDLE[$1]}/Contents/MacOS/"
}

# apps_defaults <id>: write the app's defaults lines (`domain key type value`),
# just before omamac installs or adopts it, so a failed write installs nothing
# and the next run tries both again; never otherwise, so the user's own later
# change stays. A running app (one being adopted) is quit first, so it can't
# write over the values, and opened again after. Returns non-zero on the first
# failed write.
apps_defaults() {
  local line domain key type value running=0 i bundle=${APP_BUNDLE[$1]} log=${OMAMAC_LOG:-/dev/null}
  [ -n "${APP_DEFAULTS[$1]}" ] || return 0
  OMAMAC_STEP="setting up $(apps_label "$1")"
  if apps_running "$1"; then
    running=1
    osascript -e "quit app \"${bundle%.app}\"" >> "$log" 2>&1 || true
    for i in {1..20}; do apps_running "$1" || break; sleep 0.5; done
  fi
  while IFS= read -r line; do
    read -r domain key type value <<< "$line"
    defaults write "$domain" "$key" "-$type" "$value" > /dev/null || return
  done <<< "${APP_DEFAULTS[$1]}"
  [ "$running" -eq 0 ] || open -g -a "$OMAMAC_APPLICATIONS/$bundle" >> "$log" 2>&1 || true
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

# apps_install [<id>…]: the chosen apps, or the given ids. Each missing app
# without password=yes gets its own Homebrew call, so a failure names the app.
# A hand-installed app in APPS_ADOPT is handed to Homebrew, which leaves the app in place.
apps_install() {
  local ids=("$@") id label cask state brew="$OMAMAC_BREW_PREFIX/bin/brew"
  [ "$#" -gt 0 ] || mapfile -t ids < <(apps_chosen)
  [ "${#ids[@]}" -gt 0 ] || return 0
  for id in "${ids[@]}"; do
    label=$(apps_label "$id") || return
    cask=${APP_CASK[$id]}
    OMAMAC_STEP="installing $label"
    state=$(core_cask_state "$cask") || return
    case $state in
      missing)
        # The password step installs these in the open; never under a spinner.
        [ "${APP_PASSWORD[$id]}" != yes ] || continue
        # A plain install of a cask Homebrew lists does nothing; reinstall puts the app back.
        if core_cask_listed "$cask"; then
          apps_defaults "$id" || return
          ui_run "Reinstalling $label" "$brew" reinstall --cask "$cask" || return
        else
          apps_defaults "$id" || return
          ui_run "Installing $label" "$brew" install --cask "$cask" || return
        fi
        ;;
      hand)
        # Only an app the user said yes to at the questions; one that turned up later gets the line.
        if [[ " ${APPS_ADOPT[*]} " == *" $id "* ]]; then
          apps_defaults "$id" || return
          OMAMAC_STEP="handing $label to Homebrew"
          ui_run "Handing $label to Homebrew" "$brew" install --cask --adopt "$cask" || return
        else
          # A password app can't be adopted (Homebrew would install it again), so no command for it.
          if [ "${APP_PASSWORD[$id]}" = yes ]; then
            ui_info "$label is already installed, not through Homebrew. omamac won't update it."
          else
            ui_info "$label is already installed, not through Homebrew. omamac won't update it. To let Homebrew take it over: brew install --cask --adopt $cask"
          fi
        fi
        ;;
    esac
  done
  # Only for the whole run; doctor's Reinstall of one app names it already.
  [ "$#" -gt 0 ] || ui_ok "Your apps are installed"
}
