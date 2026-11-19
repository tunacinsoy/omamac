# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM before the first run (test/vm.sh), in zsh with -eux and no
# Homebrew yet. It saves the Dock's items, to compare with after the uninstall.
dock_urls() {
  { defaults read com.apple.dock "$1" 2>/dev/null || true; } |
    sed -n 's/^ *"_CFURLString" = "\{0,1\}\([^"]*\)"\{0,1\};$/\1/p'
}
dock_urls persistent-apps > ~/dock-before-apps
dock_urls persistent-others > ~/dock-before-others
# An empty list means the Dock hasn't written its plist yet.
[[ -s ~/dock-before-apps ]]
