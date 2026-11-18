#!/bin/bash
# test/fingerprint.sh: runs in a test VM and prints what a second run of the
# one-liner must not change. test/vm.sh records it before and after that run
# and diffs the two. omamac's logs are left out: every run adds one.
set -euo pipefail

head=$(git -C ~/.local/share/omamac rev-parse HEAD)
ghostty_support=~/Library/Application\ Support/com.mitchellh.ghostty
{
  # Lists casks too.
  /opt/homebrew/bin/brew list --versions | sed 's/^/brew: /'
  /opt/homebrew/bin/brew tap | sed 's/^/tap: /'
  # Each guard keeps a missing tool, file or folder from failing the run.
  [ ! -x /opt/homebrew/bin/mise ] || (cd ~ && /opt/homebrew/bin/mise ls --installed) | sed 's/^/mise: /'
  for d in ~/.config/nvim ~/.config/mise/conf.d ~/.config/btop; do
    [ ! -d "$d" ] || find "$d" -type f -exec shasum -a 256 {} +
  done
  # Ghostty's own config files, where omamac adds its one line.
  for f in ~/.config/ghostty/config ~/.config/ghostty/config.ghostty \
    "$ghostty_support/config" "$ghostty_support/config.ghostty"; do
    [ ! -f "$f" ] || shasum -a 256 "$f"
  done
  shasum -a 256 ~/.zprofile ~/.zshrc
  find ~/.config/omamac -type f -exec shasum -a 256 {} +
  # Saved answers and anything else omamac records, but not its logs.
  find ~/.local/state/omamac -path ~/.local/state/omamac/logs -prune -o -type f -exec shasum -a 256 {} +
  # The macOS settings omamac may change. "absent" is a value too: uninstall
  # puts an unset key back to unset.
  while read -r domain key; do
    value=$(defaults read "$domain" "$key" 2>/dev/null) || value=absent
    echo "defaults: $domain $key $value"
  done <<'KEYS'
com.apple.dock mru-spaces
NSGlobalDomain AppleSpacesSwitchOnActivate
com.apple.universalaccess reduceMotion
com.apple.Accessibility ReduceMotionEnabled
com.apple.WindowManager EnableTiledWindowMargins
KEYS
  echo "checkout: $head"
} | sort
