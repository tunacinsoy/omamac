# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM before the first run (test/vm.sh), in zsh with -eux and no
# Homebrew yet. It saves the Dock's items and the macOS settings omamac may
# change, to compare with after every pick is uninstalled.
dock_urls() {
  { defaults read com.apple.dock "$1" 2>/dev/null || true; } |
    sed -n 's/^ *"_CFURLString" = "\{0,1\}\([^"]*\)"\{0,1\};$/\1/p'
}
dock_urls persistent-apps > ~/dock-before-apps
dock_urls persistent-others > ~/dock-before-others
# An empty list means the Dock hasn't written its plist yet.
[[ -s ~/dock-before-apps ]]
# dread <domain> <key>: defaults read; a currentHost:<domain> is that domain
# for this Mac only, as lib/settings.sh names it.
dread() {
  if [[ $1 == currentHost:* ]]; then defaults -currentHost read "${1#currentHost:}" "$2"; else defaults read "$1" "$2"; fi
}
# The keys test/fingerprint.sh lists, and the widget and trackpad keys;
# "absent" is a value too.
while read -r domain key; do
  value=$(dread "$domain" "$key" 2>/dev/null) || value=absent
  print -r -- "$domain $key $value"
done > ~/settings-before <<'KEYS'
com.apple.dock mru-spaces
NSGlobalDomain AppleSpacesSwitchOnActivate
com.apple.universalaccess reduceMotion
com.apple.Accessibility ReduceMotionEnabled
com.apple.WindowManager EnableTiledWindowMargins
com.apple.WindowManager StandardHideWidgets
com.apple.WindowManager StageManagerHideWidgets
com.apple.dock show-recents
com.apple.dock autohide
com.apple.AppleMultitouchTrackpad Clicking
com.apple.AppleMultitouchTrackpad Dragging
com.apple.AppleMultitouchTrackpad DragLock
com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag
com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking
com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging
com.apple.driver.AppleBluetoothMultitouch.trackpad DragLock
com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag
currentHost:NSGlobalDomain com.apple.mouse.tapBehavior
KEYS
# The Ctrl 1–6 shortcuts' entries, nested in one dictionary, so saved apart.
defaults export com.apple.symbolichotkeys - > ~/hotkeys.plist
for id in 118 119 120 121 122 123; do
  plutil -extract "AppleSymbolicHotKeys.$id" xml1 -o - ~/hotkeys.plist 2>/dev/null || print absent
done > ~/hotkeys-before
