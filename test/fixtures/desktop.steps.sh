# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
rec=~/.local/state/omamac/macos-settings.tsv
# hotkey <id> <field>: one field of a Ctrl 1–6 shortcut.
hotkey() { defaults export com.apple.symbolichotkeys - | plutil -extract "AppleSymbolicHotKeys.$1.$2" raw -; }
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
[[ $(grep -vc AppleSymbolicHotKeys $rec) == 7 ]]
# Updating again changes nothing.
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac uninstall desktops
omamac uninstall window-margins
omamac uninstall desktop-widgets
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
# Uninstalling again changes nothing and asks nothing.
before=$(fp)
omamac uninstall desktops
omamac uninstall window-margins
omamac uninstall desktop-widgets
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
