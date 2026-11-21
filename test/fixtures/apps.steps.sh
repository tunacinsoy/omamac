# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
# The apps are in Applications, Homebrew lists their casks, and VS Code's link
# points into the app. No app's binary runs: it would wait on macOS's first-open check.
for app in VLC.app Cap.app zoom.us.app 'Visual Studio Code.app' Claude.app ChatGPT.app 'GitHub Copilot.app' Antigravity.app 'Wispr Flow.app'; do
  [[ -d /Applications/$app ]]
done
casks=$(brew list --cask -1)
for c in vlc cap zoom visual-studio-code claude chatgpt github-copilot-app antigravity wispr-flow; do
  [[ $'\n'$casks$'\n' == *$'\n'$c$'\n'* ]]
done
code=$(brew --prefix)/bin/code
[[ -L $code && $(readlink "$code") == /Applications/Visual\ Studio\ Code.app/* ]]
# Updating again changes nothing.
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
# A yes to the data question takes VLC's settings too.
defaults write org.videolan.vlc omamac-test -bool true
[[ -f ~/Library/Preferences/org.videolan.vlc.plist ]]
omamac uninstall vlc
[[ ! -e /Applications/VLC.app ]]
[[ ! -e ~/Library/Preferences/org.videolan.vlc.plist ]]
casks=$(brew list --cask -1)
[[ $'\n'$casks$'\n' != *$'\n'vlc$'\n'* ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'apps_media=$'\n'* ]]
# Zoom's uninstall needs the password; Homebrew asks (the fixture's one).
omamac uninstall zoom
[[ ! -e /Applications/zoom.us.app ]]
casks=$(brew list --cask -1)
[[ $'\n'$casks$'\n' != *$'\n'zoom$'\n'* ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'apps_communication=$'\n'* ]]
# Uninstalling again changes nothing and asks nothing.
before=$(fp)
omamac uninstall vlc
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
