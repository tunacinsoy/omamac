# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
# The first run handed the VLC from adopt.before.sh to Homebrew: Homebrew lists
# it, it is the same app (same inode), and the pick stays.
casks=$(brew list --cask -1)
[[ $'\n'$casks$'\n' == *$'\n'vlc$'\n'* ]]
[[ $(stat -f %i /Applications/VLC.app) == "$(< ~/vlc-inode)" ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'apps_media=vlc$'\n'* ]]
# Updating again changes nothing.
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
# Homebrew removes the adopted app like one it installed.
omamac uninstall vlc
[[ ! -e /Applications/VLC.app ]]
casks=$(brew list --cask -1)
[[ $'\n'$casks$'\n' != *$'\n'vlc$'\n'* ]]
omamac doctor
