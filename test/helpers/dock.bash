# shellcheck shell=bash
# Dock helpers for bats. Load with `load helpers/dock`. They work on the plist
# fake-defaults exports and imports: $T_DEFAULTS_DIR/com.apple.dock.plist.

# dock_tile <tile-type> <url> [<bundle-id>]: one tile as plist XML.
dock_tile() {
  local id=''
  [ -z "${3:-}" ] || id="<key>bundle-identifier</key><string>$3</string>"
  printf '<dict><key>tile-type</key><string>%s</string><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>15</integer></dict>%s</dict></dict>' "$1" "$2" "$id"
}

# dock_seed <apps-url>… -- <others-url>…: a new Dock plist. An apps argument
# `url|bundle-id` sets the bundle id too; `spacer` is a tile with neither. An
# array is there only when it gets a tile.
dock_seed() {
  local f="$T_DEFAULTS_DIR/com.apple.dock.plist" arr=persistent-apps arg xml
  mkdir -p "$T_DEFAULTS_DIR"
  plutil -create xml1 "$f"
  for arg in "$@"; do
    if [ "$arg" = -- ]; then arr=persistent-others; continue; fi
    plutil -extract "$arr" raw "$f" > /dev/null 2>&1 || plutil -insert "$arr" -array "$f"
    case $arg in
      spacer) xml='<dict><key>tile-type</key><string>spacer-tile</string><key>tile-data</key><dict/></dict>' ;;
      *'|'*) xml=$(dock_tile file-tile "${arg%%|*}" "${arg#*|}") ;;
      *) [ "$arr" = persistent-apps ] && xml=$(dock_tile file-tile "$arg") || xml=$(dock_tile directory-tile "$arg") ;;
    esac
    plutil -insert "$arr" -xml "$xml" -append "$f"
  done
}

# dock_urls <array>: each tile's URL in order, `spacer` for a tile without one.
dock_urls() {
  local f="$T_DEFAULTS_DIR/com.apple.dock.plist" n i
  n=$(plutil -extract "$1" raw "$f" 2> /dev/null) || return 0
  for ((i = 0; i < n; i++)); do
    plutil -extract "$1.$i.tile-data.file-data._CFURLString" raw "$f" 2> /dev/null || echo spacer
  done
}
