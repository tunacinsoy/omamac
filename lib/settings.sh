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

# settings_one <domain> <key> <type> <value>: make the key the wanted value.
# Returns 3 when the domain is protected. The record gets a line only after
# the first successful write, and is never rewritten: it holds the value from
# before omamac, so uninstall can put that back.
settings_one() {
  local d=$1 k=$2 t=$3 v=$4 cur rc=0 recorded=0
  OMAMAC_STEP="setting $k in $d"
  cur=$(settings_read "$d" "$k") || rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  [ "$cur" != "$t $v" ] || return 0
  ! settings_recorded "$d" "$k" || recorded=1
  settings_write "$d" "$k" "$t" "$v" || return $?
  case $d in com.apple.dock | NSGlobalDomain) SETTINGS_DOCK=1 ;; esac
  if [ "$recorded" -eq 1 ]; then
    ui_info "Put back: $(settings_label "$k")"
  else
    mkdir -p "$OMAMAC_STATE_DIR"
    printf '%s\t%s\t%s\n' "$d" "$k" "${cur// /$'\t'}" >> "$OMAMAC_SETTINGS_RECORD"
  fi
}

settings_apply() {
  local answer line d k t v rc skip
  SETTINGS_REFUSED=0
  SETTINGS_DOCK=0
  for answer in desktops window_margins; do
    [ "${CHOICES[$answer]:-}" = yes ] || continue
    skip=0
    while IFS= read -r line; do
      read -r d k t v <<< "$line"
      [ "$skip" -eq 0 ] || [ "$(settings_label "$k")" != "Reduce motion" ] || continue
      rc=0
      settings_one "$d" "$k" "$t" "$v" || rc=$?
      [ "$rc" -eq 0 ] && continue
      # Reduce motion is one unit; a protected domain is not a failure.
      if [ "$rc" -eq 3 ] && [ "$(settings_label "$k")" = "Reduce motion" ]; then
        skip=1
        SETTINGS_REFUSED=1
        ui_info "Turn on Reduce motion: search for Reduce motion in System Settings."
        continue
      fi
      return 1
    done < <(settings_keys "$answer")
    ui_ok "${QUESTION_TITLE[$answer]}"
  done
  if [ "$SETTINGS_DOCK" -eq 1 ]; then
    OMAMAC_STEP='restarting the Dock'
    # The Dock is not running in a session without a desktop; nothing to restart.
    killall Dock || true
  fi
}
