# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap; SETTINGS_DOCK by settings_dock_restart
# The Dock cleanup behind the `dock` answer: Apple's apps and Downloads leave
# the Dock once, and omamac's apps join it. Sourced after lib/core.sh,
# lib/apps.sh and lib/settings.sh.
# One export to a copy, plutil edits, one import: the Dock is written once.
# The copy is read with `plutil -extract … raw`, never as JSON: the Dock's
# plist holds data and dates.

# The apps Apple puts in /Applications on a new Mac.
DOCK_APPLE_IDS=' com.apple.iWork.Keynote com.apple.iWork.Numbers com.apple.iWork.Pages com.apple.iMovieApp com.apple.garageband10 '

# dock_url <path>: the URL the Dock keeps for a file.
dock_url() { echo "file://${1// /%20}/"; }

# dock_apps: omamac's app file names in Dock order, only those in Applications.
dock_apps() {
  local app id
  local -a apps=("${CASK_APP[ghostty]}")
  while IFS= read -r id; do apps+=("${APP_BUNDLE[$id]}"); done < <(apps_chosen)
  [ "${CHOICES[docker]:-}" != docker-desktop ] || apps+=("${CASK_APP[docker-desktop]}")
  for app in "${apps[@]}"; do
    if [ -e "$OMAMAC_APPLICATIONS/$app" ]; then echo "$app"; fi
  done
}

# dock_get <file> <keypath>: the value; an array gives its count. Returns 1
# when the key is missing.
dock_get() { plutil -extract "$2" raw "$1" 2> /dev/null; }

# dock_apple <file> <index>: succeeds when that persistent-apps tile is Apple's.
# A tile with neither key (a spacer) is the user's.
dock_apple() {
  local url id
  url=$(dock_get "$1" "persistent-apps.$2.tile-data.file-data._CFURLString") || url=''
  id=$(dock_get "$1" "persistent-apps.$2.tile-data.bundle-identifier") || id=''
  [[ $url == file:///System/* ]] || [[ -n $id && $DOCK_APPLE_IDS == *" $id "* ]]
}

# dock_clean <file>: remove Apple's tiles and the Downloads tile, highest
# index first so the others keep theirs.
dock_clean() {
  local f=$1 n i downloads
  downloads=$(dock_url "$HOME/Downloads")
  n=$(dock_get "$f" persistent-apps) || n=0
  for ((i = n - 1; i >= 0; i--)); do
    if dock_apple "$f" "$i"; then plutil -remove "persistent-apps.$i" "$f" || return 1; fi
  done
  n=$(dock_get "$f" persistent-others) || n=0
  for ((i = n - 1; i >= 0; i--)); do
    if [ "$(dock_get "$f" "persistent-others.$i.tile-data.file-data._CFURLString")" = "$downloads" ]; then
      plutil -remove "persistent-others.$i" "$f" || return 1
    fi
  done
}

# dock_add <file> <app>…: append each app not already in the Dock (by URL).
# Prints how many were appended.
dock_add() {
  local f=$1 n i url app added=0
  local -A there=()
  shift
  if n=$(dock_get "$f" persistent-apps); then
    for ((i = 0; i < n; i++)); do
      url=$(dock_get "$f" "persistent-apps.$i.tile-data.file-data._CFURLString") || continue
      there[$url]=1
    done
  else
    plutil -insert persistent-apps -array "$f" || return 1
  fi
  for app in "$@"; do
    url=$(dock_url "$OMAMAC_APPLICATIONS/$app")
    [ -z "${there[$url]:-}" ] || continue
    # Only the type and the URL: the Dock fills in the rest.
    plutil -insert persistent-apps -xml "<dict><key>tile-type</key><string>file-tile</string><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$url</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>" -append "$f" || return 1
    added=$((added + 1))
  done
  echo "$added"
}

# dock_change <file> <fresh> <app>…: clean the copy when fresh (0 or 1), add
# the apps, and import it when anything may have changed.
dock_change() {
  local f=$1 fresh=$2 added
  shift 2
  if [ "$fresh" -eq 1 ]; then dock_clean "$f" || return 1; fi
  added=$(dock_add "$f" "$@") || return 1
  [ "$fresh" -eq 1 ] || [ "$added" -gt 0 ] || return 0
  defaults import com.apple.dock "$f" || return 1
  SETTINGS_DOCK=1
}

# dock_edit <copy>: the Dock step, on a temp file the caller removes. Each
# command is checked: errexit is off in a function called with ||.
dock_edit() {
  local copy=$1 app tmp fresh=0
  local -a todo=()
  local -A listed=()
  if [ -f "$OMAMAC_DOCK_ADDED" ]; then
    while IFS= read -r app; do listed[$app]=1; done < "$OMAMAC_DOCK_ADDED"
  fi
  # An app listed once is never added again, so a tile the user removed stays gone.
  while IFS= read -r app; do
    [ -n "${listed[$app]:-}" ] || todo+=("$app")
  done < <(dock_apps)
  [ -f "$OMAMAC_DOCK_RECORD" ] || fresh=1
  [ "$fresh" -eq 1 ] || [ "${#todo[@]}" -gt 0 ] || return 0
  defaults export com.apple.dock "$copy" || return 1
  if [ "$fresh" -eq 1 ]; then
    mkdir -p "$OMAMAC_STATE_DIR" || return 1
    # Written once, before any change, so uninstall can put this Dock back.
    # Temp file then mv, so the record is never half-written; the mv stays
    # before the import, or a cleaned Dock could be saved as the "before" Dock.
    tmp=$(mktemp "$OMAMAC_DOCK_RECORD.XXXXXX") || return 1
    if ! { cp -- "$copy" "$tmp" && mv -- "$tmp" "$OMAMAC_DOCK_RECORD"; }; then
      rm -f -- "$tmp"
      return 1
    fi
  fi
  if ! dock_change "$copy" "$fresh" "${todo[@]}"; then
    # No change made: the next run starts over.
    if [ "$fresh" -eq 1 ]; then rm -f -- "$OMAMAC_DOCK_RECORD"; fi
    return 1
  fi
  # Apps already in the Dock are listed too (the user pinned them first).
  [ "${#todo[@]}" -eq 0 ] || printf '%s\n' "${todo[@]}" >> "$OMAMAC_DOCK_ADDED"
}

# dock_apply: clean the Dock on the first run with dock=yes, then add omamac's
# apps that are new. Sets SETTINGS_DOCK=1 when it imports.
dock_apply() {
  [ "${CHOICES[dock]:-}" = yes ] || return 0
  local copy rc=0
  OMAMAC_STEP='cleaning up the Dock'
  copy=$(mktemp) || return 1
  dock_edit "$copy" || rc=$?
  rm -f -- "$copy"
  return "$rc"
}

# dock_put_back <copy>: the Dock with the record's two arrays, imported. A key
# the record lacks is removed.
dock_put_back() {
  local f=$1 key xml
  # A damaged record reads as no arrays, which would empty the Dock.
  if ! plutil -lint -s "$OMAMAC_DOCK_RECORD" > /dev/null 2>&1; then
    ui_fail "omamac's saved Dock (~/.local/state/omamac/dock-before.plist) is damaged, so your Dock was left as it is."
    ui_fail "Fix: delete that file, then run omamac uninstall dock again."
    return 1
  fi
  defaults export com.apple.dock "$f" || return 1
  for key in persistent-apps persistent-others; do
    if dock_get "$f" "$key" > /dev/null; then plutil -remove "$key" "$f" || return 1; fi
    dock_get "$OMAMAC_DOCK_RECORD" "$key" > /dev/null || continue
    xml=$(plutil -extract "$key" xml1 -o - "$OMAMAC_DOCK_RECORD") || return 1
    plutil -insert "$key" -xml "$xml" "$f" || return 1
  done
  defaults import com.apple.dock "$f"
}

# dock_restore: put the Dock back as the record has it and restart it, then
# forget the record and dock-added. No record: only a stale dock-added goes.
dock_restore() {
  # A stale list would make a later fresh cleanup skip apps.
  [ -f "$OMAMAC_DOCK_RECORD" ] || { rm -f -- "$OMAMAC_DOCK_ADDED"; return 0; }
  local copy rc=0
  OMAMAC_STEP='putting the Dock back'
  copy=$(mktemp) || return 1
  dock_put_back "$copy" || rc=$?
  rm -f -- "$copy"
  [ "$rc" -eq 0 ] || return "$rc"
  SETTINGS_DOCK=1
  # Here, not later: settings_uninstall starts with SETTINGS_DOCK=0.
  settings_dock_restart
  rm -f -- "$OMAMAC_DOCK_RECORD" "$OMAMAC_DOCK_ADDED"
}

# dock_take_out <copy> <app>: remove every tile of the app, import when one
# went, then drop its dock-added line.
dock_take_out() {
  local f=$1 app=$2 url n i removed=0 line tmp
  url=$(dock_url "$OMAMAC_APPLICATIONS/$app")
  defaults export com.apple.dock "$f" || return 1
  n=$(dock_get "$f" persistent-apps) || n=0
  for ((i = n - 1; i >= 0; i--)); do
    if [ "$(dock_get "$f" "persistent-apps.$i.tile-data.file-data._CFURLString")" = "$url" ]; then
      plutil -remove "persistent-apps.$i" "$f" || return 1
      removed=1
    fi
  done
  if [ "$removed" -eq 1 ]; then
    defaults import com.apple.dock "$f" || return 1
    SETTINGS_DOCK=1
    settings_dock_restart
  fi
  [ -f "$OMAMAC_DOCK_ADDED" ] || return 0
  tmp=$(mktemp "$OMAMAC_DOCK_ADDED.XXXXXX") || return 1
  while IFS= read -r line; do
    [ "$line" = "$app" ] || echo "$line" >> "$tmp"
  done < "$OMAMAC_DOCK_ADDED"
  mv -- "$tmp" "$OMAMAC_DOCK_ADDED"
}

# dock_remove_app <file name> <label>: take an uninstalled app out of the Dock
# when omamac cleans it.
dock_remove_app() {
  [ "${CHOICES[dock]:-}" = yes ] || return 0
  local copy rc=0
  OMAMAC_STEP="taking $2 out of the Dock"
  copy=$(mktemp) || return 1
  dock_take_out "$copy" "$1" || rc=$?
  rm -f -- "$copy"
  return "$rc"
}
