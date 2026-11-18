# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
rec=~/.local/state/omamac/macos-settings.tsv
# The five keys hold the wanted values.
[[ $(defaults read com.apple.dock mru-spaces) == 0 ]]
[[ $(defaults read NSGlobalDomain AppleSpacesSwitchOnActivate) == 1 ]]
[[ $(defaults read com.apple.universalaccess reduceMotion) == 1 ]]
[[ $(defaults read com.apple.Accessibility ReduceMotionEnabled) == 1 ]]
[[ $(defaults read com.apple.WindowManager EnableTiledWindowMargins) == 1 ]]
# One record line per key omamac changed.
[[ $(wc -l < $rec | tr -d ' ') == 5 ]]
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
# The four keys the clean Mac lacked are gone; Reduce motion is back to 0.
if defaults read com.apple.dock mru-spaces; then exit 1; fi
if defaults read NSGlobalDomain AppleSpacesSwitchOnActivate; then exit 1; fi
if defaults read com.apple.universalaccess reduceMotion; then exit 1; fi
if defaults read com.apple.WindowManager EnableTiledWindowMargins; then exit 1; fi
[[ $(defaults read com.apple.Accessibility ReduceMotionEnabled) == 0 ]]
[[ ! -e $rec ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'desktops=no$'\n'* ]]
[[ $'\n'$choices$'\n' == *$'\n'window_margins=no$'\n'* ]]
# Uninstalling again changes nothing and asks nothing.
before=$(fp)
omamac uninstall desktops
omamac uninstall window-margins
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
