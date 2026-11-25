# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap; SETTINGS_REFUSED by install_summary
# The macOS settings behind the yes/no answers `desktops`, `window_margins`,
# `desktop_widgets`, `dock`, `dock_autohide`, `tap_to_click` and
# `three_finger_drag`.
# Sourced after lib/ui.sh, lib/questions.sh and lib/choices.sh, before lib/dock.sh
# (settings_apply calls its dock_apply) and lib/apply.sh.
# Each key is "domain key type value"; the type is the word `defaults read-type`
# gives (boolean or integer). A domain written currentHost:<domain> is that
# domain for this Mac only (`defaults -currentHost`), where System Settings
# keeps part of Tap to click.
# The Ctrl 1–6 shortcuts are entries of one nested dictionary, so their key is
# a plutil key path, read and written through an exported copy as lib/dock.sh
# does the Dock. Type `hotkey` is the shortcut on, its value the key code (1 to
# 6 are 18, 19, 20, 21, 23, 22). Any other entry reads as `json` and its plutil
# JSON, so uninstall puts it back exactly.

# The seven answers, in table order; omamac configure turns each on or off.
SETTINGS_ANSWERS=(desktops window_margins desktop_widgets dock dock_autohide tap_to_click three_finger_drag)

SETTINGS_KEYS_desktops=(
  "com.apple.dock mru-spaces boolean false"
  "NSGlobalDomain AppleSpacesSwitchOnActivate boolean true"
  "com.apple.universalaccess reduceMotion boolean true"
  "com.apple.Accessibility ReduceMotionEnabled integer 1"
  "com.apple.symbolichotkeys AppleSymbolicHotKeys.118 hotkey 18"
  "com.apple.symbolichotkeys AppleSymbolicHotKeys.119 hotkey 19"
  "com.apple.symbolichotkeys AppleSymbolicHotKeys.120 hotkey 20"
  "com.apple.symbolichotkeys AppleSymbolicHotKeys.121 hotkey 21"
  "com.apple.symbolichotkeys AppleSymbolicHotKeys.122 hotkey 23"
  "com.apple.symbolichotkeys AppleSymbolicHotKeys.123 hotkey 22"
)
SETTINGS_KEYS_window_margins=(
  "com.apple.WindowManager EnableTiledWindowMargins boolean true"
)
SETTINGS_KEYS_desktop_widgets=(
  "com.apple.WindowManager StandardHideWidgets boolean true"
  "com.apple.WindowManager StageManagerHideWidgets boolean true"
)
SETTINGS_KEYS_dock=(
  "com.apple.dock show-recents boolean false"
)
SETTINGS_KEYS_dock_autohide=(
  "com.apple.dock autohide boolean true"
)
# The built-in trackpad, a Bluetooth one, and this Mac's mouse setting: the
# three keys System Settings writes.
SETTINGS_KEYS_tap_to_click=(
  "com.apple.AppleMultitouchTrackpad Clicking boolean true"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking boolean true"
  "currentHost:NSGlobalDomain com.apple.mouse.tapBehavior integer 1"
)
# What System Settings writes for three-finger drag, on both trackpads: tap
# to drag goes off (dragging is one choice), and the three-finger swipes
# between desktops and to Mission Control move to four fingers.
SETTINGS_KEYS_three_finger_drag=(
  "com.apple.AppleMultitouchTrackpad Dragging boolean false"
  "com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag boolean true"
  "com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture integer 0"
  "com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture integer 0"
  "com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture integer 2"
  "com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture integer 2"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging boolean false"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag boolean true"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture integer 0"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture integer 0"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture integer 2"
  "com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture integer 2"
)
SETTINGS_REFUSED=0
SETTINGS_DOCK=0
SETTINGS_ACTIVATE=0
SETTINGS_UNMET=()
SETTINGS_PUT_BACK=' '

# settings_keys <answer-key>: that answer's lines.
settings_keys() {
  local -n _keys="SETTINGS_KEYS_$1"
  printf '%s\n' "${_keys[@]}"
}

# settings_defaults <command> <domain> <arg>…: defaults, with -currentHost
# for a currentHost: domain.
settings_defaults() {
  local cmd=$1 d=$2
  shift 2
  case $d in
    currentHost:*) defaults -currentHost "$cmd" "${d#currentHost:}" "$@" ;;
    *) defaults "$cmd" "$d" "$@" ;;
  esac
}

# settings_read <domain> <key>: "<type> <value>" or "absent". Returns 3 when
# the domain refuses to be read, 1 on any other error.
settings_read() {
  local out type
  [ "$1" != com.apple.symbolichotkeys ] || { settings_hotkey_read "$1" "$2"; return; }
  if ! out=$(settings_defaults read "$1" "$2" 2>&1); then
    case $out in
      *'Could not write domain'*) return 3 ;;
      *'does not exist'* | *'Could not find key'* | *'not found'*) echo absent ;;
      *) echo "$out" >&2; return 1 ;;
    esac
    return 0
  fi
  type=$(settings_defaults read-type "$1" "$2") || return 1
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
  case $3 in
    hotkey) settings_hotkey_put "$1" "$2" "$(settings_hotkey_json "$4")"; return ;;
    json) settings_hotkey_put "$1" "$2" "$4"; return ;;
  esac
  [ "$3" != boolean ] || flag=-bool
  if ! out=$(settings_defaults write "$1" "$2" "$flag" "$4" 2>&1); then
    case $out in
      *'Could not write domain'*) return 3 ;;
      *) echo "$out" >&2; return 1 ;;
    esac
  fi
}

# settings_hotkey_json <key code>: a shortcut that is on: Ctrl (262144) and
# the key, with no character (65535).
settings_hotkey_json() {
  echo '{"enabled":true,"value":{"parameters":[65535,'"$1"',262144],"type":"standard"}}'
}

# settings_hotkey_get <copy> <domain> <key path>: settings_read for one
# entry, on a temp file the caller removes.
settings_hotkey_get() {
  local f=$1 xml json code
  defaults export "$2" "$f" || return 1
  xml=$(plutil -extract "$3" xml1 -o - "$f" 2> /dev/null) || { echo absent; return 0; }
  json=$(plutil -extract "$3" json -o - "$f") || return 1
  # On only when the entry is exactly what omamac writes, compared as XML:
  # plutil's JSON has no fixed key order. Writing it over the copy is safe,
  # the copy is never imported.
  code=$(plutil -extract "$3.value.parameters.1" raw "$f" 2> /dev/null) || code=x
  if plutil -replace "$3" -json "$(settings_hotkey_json "$code")" "$f" 2> /dev/null &&
    [ "$(plutil -extract "$3" xml1 -o - "$f")" = "$xml" ]; then
    echo "hotkey $code"
  else
    echo "json $json"
  fi
}

settings_hotkey_read() {
  local copy rc=0
  copy=$(mktemp) || return 1
  settings_hotkey_get "$copy" "$1" "$2" || rc=$?
  rm -f -- "$copy"
  return "$rc"
}

# settings_hotkey_set <copy> <domain> <key path> <json>: one import. An
# empty JSON removes the entry; one already gone counts as done.
settings_hotkey_set() {
  local f=$1 parent=${3%.*}
  defaults export "$2" "$f" || return 1
  if [ -z "$4" ]; then
    plutil -extract "$3" raw "$f" > /dev/null 2>&1 || return 0
    plutil -remove "$3" "$f" || return 1
  else
    plutil -extract "$parent" raw "$f" > /dev/null 2>&1 || plutil -insert "$parent" -dictionary "$f" || return 1
    plutil -replace "$3" -json "$4" "$f" || return 1
  fi
  defaults import "$2" "$f"
}

settings_hotkey_put() {
  local copy rc=0
  copy=$(mktemp) || return 1
  settings_hotkey_set "$copy" "$@" || rc=$?
  rm -f -- "$copy"
  return "$rc"
}

# settings_label <key>: the name shown to the user.
settings_label() {
  case $1 in
    reduceMotion | ReduceMotionEnabled) echo "Reduce motion" ;;
    AppleSymbolicHotKeys.*) echo "Ctrl 1–6" ;;
    mru-spaces) echo "Spaces order" ;;
    AppleSpacesSwitchOnActivate) echo "Switching to an app's desktop" ;;
    EnableTiledWindowMargins) echo "Window margins" ;;
    StandardHideWidgets | StageManagerHideWidgets) echo "Desktop widgets" ;;
    show-recents) echo "Suggested and recent apps" ;;
    autohide) echo "Dock auto-hide" ;;
    Clicking | com.apple.mouse.tapBehavior) echo "Tap to click" ;;
    Dragging | TrackpadThreeFingerDrag | Trackpad*SwipeGesture) echo "Three-finger drag" ;;
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
  local label
  if settings_recorded "$1" "$2"; then
    # Once per label per run (Reduce motion is two keys, Tap to click three).
    label=$(settings_label "$2")
    case $SETTINGS_PUT_BACK in *"|$label|"*) return 0 ;; esac
    SETTINGS_PUT_BACK+="|$label| "
    ui_info "Put back: $label"
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
  settings_changed "$d"
  # No record line, no change: uninstall could not put the value back.
  settings_note "$d" "$k" "$cur" || { settings_restore "$d" "$k" "$cur"; return 1; }
}

# settings_changed <domain>: note what reloads once the keys are written.
settings_changed() {
  case $1 in
    com.apple.dock | NSGlobalDomain) SETTINGS_DOCK=1 ;;
    # The shortcuts and the trackpad: read again through activateSettings.
    com.apple.symbolichotkeys | com.apple.AppleMultitouchTrackpad | com.apple.driver.AppleBluetoothMultitouch.trackpad | currentHost:NSGlobalDomain) SETTINGS_ACTIVATE=1 ;;
  esac
}

# settings_restore <domain> <key> <before>: undo one write. A key that is
# already gone counts as done. Returns 3 when the domain is protected, 1 on
# any other error.
settings_restore() {
  local t v out
  if [ "$3" = absent ] && [ "$1" = com.apple.symbolichotkeys ]; then
    settings_hotkey_put "$1" "$2" ''
  elif [ "$3" = absent ]; then
    if ! out=$(settings_defaults delete "$1" "$2" 2>&1); then
      case $out in
        *'Could not write domain'*) return 3 ;;
        *'does not exist'* | *'Could not find key'* | *'not found'*) ;;
        *) echo "$out" >&2; return 1 ;;
      esac
    fi
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
        settings_restore "$d" "$k" "${cur[$j]}" || return 1
      done
      return "$rc"
    fi
    written[i]=1
  done
  for i in "${!written[@]}"; do
    read -r d k _ <<< "${lines[$i]}"
    if ! settings_note "$d" "$k" "${cur[$i]}"; then
      # No record line, no change: put every key of the unit back.
      for j in "${!written[@]}"; do
        read -r d k _ <<< "${lines[$j]}"
        settings_restore "$d" "$k" "${cur[$j]}" || true
      done
      return 1
    fi
  done
}

# settings_apply [<answer>…]: set the answers that are yes; with none named,
# all seven. A full run says a ✓ row per answer; omamac configure, which names
# one, says its own.
settings_apply() {
  local answer line d k t v rc unit=() answers=("$@")
  SETTINGS_REFUSED=0
  SETTINGS_DOCK=0
  SETTINGS_ACTIVATE=0
  SETTINGS_PUT_BACK=' '
  [ "${#answers[@]}" -gt 0 ] || answers=("${SETTINGS_ANSWERS[@]}")
  for answer in "${answers[@]}"; do
    [ "${CHOICES[$answer]:-}" = yes ] || continue
    unit=()
    while IFS= read -r line; do
      read -r d k t v <<< "$line"
      case $d in
        com.apple.universalaccess | com.apple.Accessibility) unit+=("$line"); continue ;;
      esac
      settings_one "$d" "$k" "$t" "$v" || { settings_reload; return 1; }
    done < <(settings_keys "$answer")
    if [ "${#unit[@]}" -gt 0 ]; then
      rc=0
      settings_unit "${unit[@]}" || rc=$?
      if [ "$rc" -eq 3 ]; then
        # A protected domain is not a failure.
        SETTINGS_REFUSED=1
        ui_info "Turn on Reduce motion: search for Reduce motion in System Settings."
      elif [ "$rc" -ne 0 ]; then
        settings_reload
        return 1
      fi
    fi
    if [ "$answer" = dock ]; then dock_apply || { settings_reload; return 1; }; fi
    [ "$#" -gt 0 ] || ui_ok "${QUESTION_TITLE[$answer]}"
  done
  settings_reload
}

# settings_reload: make what was written take effect, once per run.
settings_reload() {
  settings_activate
  settings_dock_restart
}

settings_activate() {
  [ "$SETTINGS_ACTIVATE" -eq 1 ] || return 0
  # Without this, macOS reads the shortcuts and Tap to click only at the next
  # login. It is a private tool, so its absence or failure is only logged.
  if [ -x "$OMAMAC_ACTIVATE_SETTINGS" ]; then
    "$OMAMAC_ACTIVATE_SETTINGS" -u >> "${OMAMAC_LOG:-/dev/null}" 2>&1 || echo "settings: activateSettings -u failed" >> "${OMAMAC_LOG:-/dev/null}"
  else
    echo "settings: no $OMAMAC_ACTIVATE_SETTINGS; the shortcuts and Tap to click work after the next login" >> "${OMAMAC_LOG:-/dev/null}"
  fi
}

settings_dock_restart() {
  [ "$SETTINGS_DOCK" -eq 1 ] || return 0
  local step=$OMAMAC_STEP
  OMAMAC_STEP='restarting the Dock'
  # The Dock is not running in a session without a desktop; nothing to restart.
  killall Dock 2>> "${OMAMAC_LOG:-/dev/null}" || true
  # Keep the failed step's name for the caller's ERR trap.
  OMAMAC_STEP=$step
}

# settings_what <answer-key>: what uninstall puts back, for its box.
settings_what() {
  case $1 in
    desktops) echo "your earlier Spaces, app-switching, Ctrl 1–6 and Reduce motion settings" ;;
    desktop_widgets) echo "your earlier desktop-widget settings" ;;
    dock_autohide) echo "your earlier Dock auto-hide setting" ;;
    tap_to_click) echo "your earlier Tap to click setting" ;;
    three_finger_drag) echo "your earlier dragging and three-finger swipe settings" ;;
    *) echo "your earlier window-margin setting" ;;
  esac
}

# settings_before <domain> <key>: the recorded value, "absent" or "<type> <value>".
# Returns 1 when the key is not recorded.
settings_before() {
  local d k rest
  [ -f "$OMAMAC_SETTINGS_RECORD" ] || return 1
  while IFS=$'\t' read -r d k rest; do
    if [ "$d $k" = "$1 $2" ]; then
      echo "${rest//$'\t'/ }"
      return 0
    fi
  done < "$OMAMAC_SETTINGS_RECORD"
  return 1
}

# settings_drop <domain> <key>: take the key's line out of the record; the
# record goes with its last line.
settings_drop() {
  local d k rest tmp
  tmp=$(mktemp "$OMAMAC_SETTINGS_RECORD.XXXXXX")
  while IFS=$'\t' read -r d k rest; do
    [ "$d $k" = "$1 $2" ] || printf '%s\t%s\t%s\n' "$d" "$k" "$rest" >> "$tmp"
  done < "$OMAMAC_SETTINGS_RECORD"
  if [ -s "$tmp" ]; then mv -- "$tmp" "$OMAMAC_SETTINGS_RECORD"; else rm -f -- "$tmp" "$OMAMAC_SETTINGS_RECORD"; fi
}

# settings_uninstall <answer-key>: put each recorded key of that answer back,
# dropping its line right after, so a failure halfway leaves the rest recorded
# and a rerun finishes. A protected domain is not a failure: its lines are
# dropped and the user is told to do it by hand.
settings_uninstall() {
  local d k t v before rc refused=0 unit_recorded=0
  SETTINGS_DOCK=0
  SETTINGS_ACTIVATE=0
  while read -r d k t v; do
    before=$(settings_before "$d" "$k") || continue
    case $d in com.apple.universalaccess | com.apple.Accessibility) unit_recorded=1 ;; esac
    OMAMAC_STEP="putting back $(settings_label "$k")"
    case $d in
      com.apple.universalaccess | com.apple.Accessibility)
        # One unit: once one key is refused, the other is left alone too.
        if [ "$refused" -eq 1 ]; then settings_drop "$d" "$k"; continue; fi ;;
    esac
    rc=0
    settings_restore "$d" "$k" "$before" || rc=$?
    if [ "$rc" -eq 3 ]; then
      refused=1
      ui_info "Turn off Reduce motion: search for Reduce motion in System Settings."
    elif [ "$rc" -ne 0 ]; then
      settings_reload
      return 1
    else
      settings_changed "$d"
    fi
    settings_drop "$d" "$k"
  done < <(settings_keys "$1")
  settings_reload
  if [ "$1" = desktops ] && [ "$unit_recorded" -eq 0 ]; then
    ui_info "omamac didn't change Reduce motion; if you turned it on yourself, search for Reduce motion in System Settings."
  fi
}

# settings_check <answer-key>: sets SETTINGS_UNMET to the names of the keys that
# no longer hold the wanted value, and SETTINGS_REFUSED to 1 when a protected
# domain can't be read (that key is left out). Not run in a subshell.
settings_check() {
  local d k t v cur rc label
  SETTINGS_UNMET=()
  SETTINGS_REFUSED=0
  while read -r d k t v; do
    rc=0
    cur=$(settings_read "$d" "$k" 2>/dev/null) || rc=$?
    if [ "$rc" -eq 3 ]; then
      SETTINGS_REFUSED=1
      continue
    fi
    [ "$rc" -ne 0 ] || [ "$cur" != "$t $v" ] || continue
    label=$(settings_label "$k")
    case " ${SETTINGS_UNMET[*]:-} " in *" $label "*) ;; *) SETTINGS_UNMET+=("$label") ;; esac
  done < <(settings_keys "$1")
}
