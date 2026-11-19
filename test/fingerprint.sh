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
  # Homebrew services (colima runs as one): registered or not, never the
  # status, which is the service's own (colima's moves from started to error
  # in a VM by itself). The first line is a header, or "No services available
  # to control."; status none means not registered.
  /opt/homebrew/bin/brew services list |
    awk 'NR > 1 && NF >= 2 { print "service: " $1 " " ($2 == "none" ? "not registered" : "registered") }'
  # Docker's folder (plugin links, colima's config.json), the login services'
  # plists, and Docker Desktop's links: a hash per file, the target per link.
  for d in ~/.docker ~/Library/LaunchAgents /usr/local/bin /usr/local/cli-plugins; do
    if [ -d "$d" ]; then
      find "$d" -type f -exec shasum -a 256 {} +
      find "$d" -type l -exec stat -f '%N -> %Y' {} +
    fi
  done
  # The apps in Applications (installed or adopted).
  for a in /Applications/*; do echo "application: ${a##*/}"; done
  # The Dock's items, numbered so sort keeps their order. Only the URLs: the
  # Dock rewrites its own bookmarks and ids by itself.
  for k in persistent-apps persistent-others; do
    { defaults read com.apple.dock "$k" 2>/dev/null || true; } |
      sed -n 's/^ *"_CFURLString" = "\{0,1\}\([^"]*\)"\{0,1\};$/\1/p' |
      awk -v k="$k" '{ printf "dock %s %02d: %s\n", k, NR, $0 }'
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
com.apple.dock show-recents
com.apple.dock autohide
KEYS
  echo "checkout: $head"
} | sort
