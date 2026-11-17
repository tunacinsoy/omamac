#!/bin/bash
# test/fingerprint.sh: runs in a test VM and prints what a second run of the
# one-liner must not change. test/vm.sh records it before and after that run
# and diffs the two. omamac's logs are left out: every run adds one.
set -euo pipefail

head=$(git -C ~/.local/share/omamac rev-parse HEAD)
{
  /opt/homebrew/bin/brew list --versions | sed 's/^/brew: /'
  /opt/homebrew/bin/brew tap | sed 's/^/tap: /'
  # Each guard keeps a missing tool or folder from failing the run.
  [ ! -x /opt/homebrew/bin/mise ] || (cd ~ && /opt/homebrew/bin/mise ls --installed) | sed 's/^/mise: /'
  for d in ~/.config/nvim ~/.config/mise/conf.d; do
    [ ! -d "$d" ] || find "$d" -type f -exec shasum -a 256 {} +
  done
  shasum -a 256 ~/.zprofile ~/.zshrc ~/.local/state/omamac/choices.env
  find ~/.config/omamac -type f -exec shasum -a 256 {} +
  echo "checkout: $head"
} | sort
