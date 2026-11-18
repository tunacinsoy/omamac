# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap; SETTINGS_REFUSED by install_summary
# The macOS settings behind the yes/no answers `desktops` and `window_margins`.
# Sourced after lib/ui.sh, lib/questions.sh and lib/choices.sh, before lib/apply.sh.
# Each key is "domain key type value"; the type is the word `defaults read-type`
# gives (boolean or integer).

SETTINGS_KEYS_desktops=(
  "com.apple.dock mru-spaces boolean false"
  "NSGlobalDomain AppleSpacesSwitchOnActivate boolean true"
  "com.apple.universalaccess reduceMotion boolean true"
  "com.apple.Accessibility ReduceMotionEnabled integer 1"
)
SETTINGS_KEYS_window_margins=(
  "com.apple.WindowManager EnableTiledWindowMargins boolean true"
)
SETTINGS_REFUSED=0
SETTINGS_DOCK=0

# settings_keys <answer-key>: that answer's lines.
settings_keys() {
  local -n _keys="SETTINGS_KEYS_$1"
  printf '%s\n' "${_keys[@]}"
}

# settings_read <domain> <key>: "<type> <value>" or "absent". Returns 3 when
# the domain refuses to be read, 1 on any other error.
settings_read() {
  local out type
  if ! out=$(defaults read "$1" "$2" 2>&1); then
    case $out in
      *'Could not write domain'*) return 3 ;;
      *'does not exist'* | *'Could not find key'* | *'not found'*) echo absent ;;
      *) echo "$out" >&2; return 1 ;;
    esac
    return 0
  fi
  type=$(defaults read-type "$1" "$2") || return 1
  case $type in
    *boolean) [ "$out" = 1 ] && echo "boolean true" || echo "boolean false" ;;
    *integer) echo "integer $out" ;;
    *) echo "settings: $1 $2 has type '$type'" >&2; return 1 ;;
  esac
}

# settings_write <domain> <key> <type> <value>: returns 3 when the domain is
# protected, 1 on any other error.
settings_write() {
  local out flag=-int
  [ "$3" != boolean ] || flag=-bool
  if ! out=$(defaults write "$1" "$2" "$flag" "$4" 2>&1); then
    case $out in
      *'Could not write domain'*) return 3 ;;
      *) echo "$out" >&2; return 1 ;;
    esac
  fi
}

# settings_label <key>: the name shown to the user.
settings_label() {
  case $1 in
    reduceMotion | ReduceMotionEnabled) echo "Reduce motion" ;;
    *) echo "$1" ;;
  esac
}

settings_recorded() {
  local d k
  [ -f "$OMAMAC_SETTINGS_RECORD" ] || return 1
  while IFS=$'\t' read -r d k _; do
    [ "$d $k" != "$1 $2" ] || return 0
  done < "$OMAMAC_SETTINGS_RECORD"
  return 1
}

# settings_note <domain> <key> <before>: after a successful write, tell the
# user it was put back, or record the value from before omamac. The record
# gets a line only after the first successful write and is never rewritten,
# so uninstall can put that first value back.
settings_note() {
  if settings_recorded "$1" "$2"; then
    ui_info "Put back: $(settings_label "$2")"
  else
    mkdir -p "$OMAMAC_STATE_DIR"
    printf '%s\t%s\t%s\n' "$1" "$2" "${3// /$'\t'}" >> "$OMAMAC_SETTINGS_RECORD"
  fi
}

# settings_one <domain> <key> <type> <value>: make the key the wanted value.
# Returns 3 when the domain is protected.
settings_one() {
  local d=$1 k=$2 t=$3 v=$4 cur rc=0
  OMAMAC_STEP="setting $k in $d"
  cur=$(settings_read "$d" "$k") || rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  [ "$cur" != "$t $v" ] || return 0
  settings_write "$d" "$k" "$t" "$v" || return $?
  case $d in com.apple.dock | NSGlobalDomain) SETTINGS_DOCK=1 ;; esac
  settings_note "$d" "$k" "$cur"
}

# settings_restore <domain> <key> <before>: undo one write.
settings_restore() {
  local t v
  if [ "$3" = absent ]; then
    defaults delete "$1" "$2"
  else
    read -r t v <<< "$3"
    settings_write "$1" "$2" "$t" "$v"
  fi
}

# settings_unit <line>...: keys that only work together (Reduce motion). If
# any is refused, none stays changed and none is recorded. Returns 3 then.
settings_unit() {
  local lines=("$@") i j rc=0 d k t v
  local cur=() written=()
  OMAMAC_STEP='setting Reduce motion'
  for i in "${!lines[@]}"; do
    read -r d k t v <<< "${lines[$i]}"
    cur[i]=$(settings_read "$d" "$k") || return $?
  done
  for i in "${!lines[@]}"; do
    read -r d k t v <<< "${lines[$i]}"
    [ "${cur[$i]}" != "$t $v" ] || continue
    rc=0
    settings_write "$d" "$k" "$t" "$v" || rc=$?
    if [ "$rc" -ne 0 ]; then
      for j in "${!written[@]}"; do
        read -r d k _ <<< "${lines[$j]}"
        settings_restore "$d" "$k" "${cur[$j]}"
      done
      return "$rc"
    fi
    written[i]=1
  done
  for i in "${!written[@]}"; do
    read -r d k _ <<< "${lines[$i]}"
    settings_note "$d" "$k" "${cur[$i]}"
  done
}

settings_apply() {
  local answer line d k t v rc unit=()
  SETTINGS_REFUSED=0
  SETTINGS_DOCK=0
  for answer in desktops window_margins; do
    [ "${CHOICES[$answer]:-}" = yes ] || continue
    unit=()
    while IFS= read -r line; do
      read -r d k t v <<< "$line"
      case $d in
        com.apple.universalaccess | com.apple.Accessibility) unit+=("$line"); continue ;;
      esac
      settings_one "$d" "$k" "$t" "$v" || return 1
    done < <(settings_keys "$answer")
    if [ "${#unit[@]}" -gt 0 ]; then
      rc=0
      settings_unit "${unit[@]}" || rc=$?
      if [ "$rc" -eq 3 ]; then
        # A protected domain is not a failure.
        SETTINGS_REFUSED=1
        ui_info "Turn on Reduce motion: search for Reduce motion in System Settings."
      elif [ "$rc" -ne 0 ]; then
        return 1
      fi
    fi
    ui_ok "${QUESTION_TITLE[$answer]}"
  done
  if [ "$SETTINGS_DOCK" -eq 1 ]; then
    OMAMAC_STEP='restarting the Dock'
    # The Dock is not running in a session without a desktop; nothing to restart.
    killall Dock || true
  fi
}
