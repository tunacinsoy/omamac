# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
rec=~/.local/state/omamac/macos-settings.tsv
# hotkey <id> <field>: one field of a Ctrl 1–6 shortcut.
hotkey() { defaults export com.apple.symbolichotkeys - | plutil -extract "AppleSymbolicHotKeys.$1.$2" raw -; }
# dread <domain> <key>: defaults read; a currentHost:<domain> is that domain
# for this Mac only, as lib/settings.sh names it.
dread() {
  if [[ $1 == currentHost:* ]]; then defaults -currentHost read "${1#currentHost:}" "$2"; else defaults read "$1" "$2"; fi
}
# The trackpad keys of Tap to click and tap to drag, "domain key value".
trackpad='com.apple.AppleMultitouchTrackpad Clicking 1
com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking 1
currentHost:NSGlobalDomain com.apple.mouse.tapBehavior 1
com.apple.AppleMultitouchTrackpad Dragging 1
com.apple.AppleMultitouchTrackpad DragLock 0
com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag 0
com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging 1
com.apple.driver.AppleBluetoothMultitouch.trackpad DragLock 0
com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag 0'
# Each trackpad key's value before the first run, from the record ("absent"
# or "<type> <value>"), saved before configure off drops the lines.
print -r -- "$trackpad" | while read -r d k _; do
  print -r -- "$d $k $(awk -F'\t' -v d="$d" -v k="$k" '$1 == d && $2 == k { $1 = $2 = ""; sub(/^  /, ""); print; f = 1 } END { if (!f) print "unchanged" }' $rec)"
done > ~/trackpad-before
# The trackpad keys hold the wanted values.
print -r -- "$trackpad" | while read -r d k v; do [[ $(dread "$d" "$k") == "$v" ]]; done
# The seven keys hold the wanted values.
[[ $(defaults read com.apple.dock mru-spaces) == 0 ]]
[[ $(defaults read NSGlobalDomain AppleSpacesSwitchOnActivate) == 1 ]]
[[ $(defaults read com.apple.universalaccess reduceMotion) == 1 ]]
[[ $(defaults read com.apple.Accessibility ReduceMotionEnabled) == 1 ]]
[[ $(defaults read com.apple.WindowManager EnableTiledWindowMargins) == 1 ]]
[[ $(defaults read com.apple.WindowManager StandardHideWidgets) == 1 ]]
[[ $(defaults read com.apple.WindowManager StageManagerHideWidgets) == 1 ]]
# Ctrl 1 to Ctrl 6 are on, each with its key code.
for pair in 118:18 119:19 120:20 121:21 122:23 123:22; do
  [[ $(hotkey ${pair%:*} enabled) == true ]]
  [[ $(hotkey ${pair%:*} value.parameters.1) == "${pair#*:}" ]]
  [[ $(hotkey ${pair%:*} value.parameters.2) == 262144 ]]
done
# One record line per key omamac changed. A new Mac may already have the
# shortcuts' entries (off), so they are left out of the count.
[[ $(grep -v AppleSymbolicHotKeys $rec | grep -vc -e Multitouch -e tapBehavior) == 7 ]]
# Updating again changes nothing.
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac configure desktops off
omamac configure window-margins off
omamac configure desktop-widgets off
omamac configure tap-to-click off
omamac configure tap-to-drag off
# The four keys the clean Mac lacked are gone; Reduce motion is back to 0.
if defaults read com.apple.dock mru-spaces; then exit 1; fi
if defaults read NSGlobalDomain AppleSpacesSwitchOnActivate; then exit 1; fi
if defaults read com.apple.universalaccess reduceMotion; then exit 1; fi
if defaults read com.apple.WindowManager EnableTiledWindowMargins; then exit 1; fi
[[ $(defaults read com.apple.Accessibility ReduceMotionEnabled) == 0 ]]
# Widgets show again (each key gone or back to its earlier value).
[[ $(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null || echo absent) != 1 ]]
[[ $(defaults read com.apple.WindowManager StageManagerHideWidgets 2>/dev/null || echo absent) != 1 ]]
# No shortcut is on any more (each is gone or back to off).
for id in 118 119 120 121 122 123; do
  [[ $(hotkey $id enabled 2>/dev/null || echo absent) != true ]]
done
[[ ! -e $rec ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'desktops=no$'\n'* ]]
[[ $'\n'$choices$'\n' == *$'\n'window_margins=no$'\n'* ]]
[[ $'\n'$choices$'\n' == *$'\n'desktop_widgets=no$'\n'* ]]
[[ $'\n'$choices$'\n' == *$'\n'tap_to_click=no$'\n'* ]]
[[ $'\n'$choices$'\n' == *$'\n'tap_to_drag=no$'\n'* ]]
# Each trackpad key omamac changed is back: gone if it was unset, else its
# earlier value (a boolean reads as 1 or 0).
while read -r d k t v; do
  case $t in
    unchanged) ;;
    absent) if dread "$d" "$k"; then exit 1; fi ;;
    boolean)
      want=0
      if [[ $v == true ]]; then want=1; fi
      [[ $(dread "$d" "$k") == "$want" ]]
      ;;
    *) [[ $(dread "$d" "$k") == "$v" ]] ;;
  esac
done < ~/trackpad-before
# configure turns a setting back on, then off, with no question.
omamac configure window-margins on
[[ $(defaults read com.apple.WindowManager EnableTiledWindowMargins) == 1 ]]
grep -q EnableTiledWindowMargins $rec
omamac configure window-margins off
if defaults read com.apple.WindowManager EnableTiledWindowMargins; then exit 1; fi
[[ ! -e $rec ]]
# Turning them off again changes nothing and asks nothing.
before=$(fp)
omamac configure desktops off
omamac configure window-margins off
omamac configure desktop-widgets off
omamac configure tap-to-click off
omamac configure tap-to-drag off
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
