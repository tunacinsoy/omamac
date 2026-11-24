# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
dock_urls() {
  { defaults read com.apple.dock "$1" 2>/dev/null || true; } |
    sed -n 's/^ *"_CFURLString" = "\{0,1\}\([^"]*\)"\{0,1\};$/\1/p'
}
# The Dock is exactly Ghostty and VLC; Downloads and the rest are gone.
[[ $(dock_urls persistent-apps) == $'file:///Applications/Ghostty.app/\nfile:///Applications/VLC.app/' ]]
[[ -z $(dock_urls persistent-others) ]]
[[ $(defaults read com.apple.dock show-recents) == 0 ]]
[[ $(defaults read com.apple.dock autohide) == 1 ]]
# Updating again changes nothing.
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
# Uninstalling an app takes its tile out.
omamac uninstall vlc
[[ $(dock_urls persistent-apps) == "file:///Applications/Ghostty.app/" ]]
[[ $(< ~/.local/state/omamac/dock-added) == Ghostty.app ]]
# Turning the cleanup off puts the Dock from before back.
omamac configure dock off
[[ $(dock_urls persistent-apps) == "$(< ~/dock-before-apps)" ]]
[[ $(dock_urls persistent-others) == "$(< ~/dock-before-others)" ]]
# Turning auto-hide off takes the setting away (it was unset before).
omamac configure dock-autohide off
if defaults read com.apple.dock autohide; then
  exit 1
fi
omamac doctor
