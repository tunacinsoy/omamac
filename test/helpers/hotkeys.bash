# shellcheck shell=bash
# Ctrl 1–6 helpers for bats. Load with `load helpers/hotkeys`. They work on the
# plist fake-defaults exports and imports:
# $T_DEFAULTS_DIR/com.apple.symbolichotkeys.plist.

# The six ids and their key codes, as lib/settings.sh has them.
HOTKEY_IDS=(118 119 120 121 122 123)
# shellcheck disable=SC2034 # used by the .bats files
HOTKEY_CODES=(18 19 20 21 23 22)

hotkey_file() { echo "$T_DEFAULTS_DIR/com.apple.symbolichotkeys.plist"; }

# hotkey_seed <id> <json>: set one entry.
hotkey_seed() {
  local f
  f=$(hotkey_file)
  mkdir -p "$T_DEFAULTS_DIR"
  [ -f "$f" ] || plutil -create xml1 "$f"
  plutil -extract AppleSymbolicHotKeys raw "$f" > /dev/null 2>&1 || plutil -insert AppleSymbolicHotKeys -dictionary "$f"
  plutil -replace "AppleSymbolicHotKeys.$1" -json "$2" "$f"
}

# hotkey_xml <id>: the entry as XML, or "absent".
hotkey_xml() {
  local f
  f=$(hotkey_file)
  [ -f "$f" ] || { echo absent; return 0; }
  plutil -extract "AppleSymbolicHotKeys.$1" xml1 -o - "$f" 2> /dev/null || echo absent
}

# hotkey_on <code>: the XML of a shortcut omamac turned on.
hotkey_on() {
  local f="$BATS_TEST_TMPDIR/hotkey-on.plist"
  plutil -create xml1 "$f"
  plutil -insert k -json '{"enabled":true,"value":{"parameters":[65535,'"$1"',262144],"type":"standard"}}' "$f"
  plutil -extract k xml1 -o - "$f"
}

# hotkey_lines: the record lines of the six shortcuts on a clean Mac.
hotkey_lines() {
  local id
  for id in "${HOTKEY_IDS[@]}"; do printf 'com.apple.symbolichotkeys\tAppleSymbolicHotKeys.%s\tabsent\n' "$id"; done
}
