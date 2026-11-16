#!/bin/bash
# test/fingerprint.sh: runs in a test VM and prints what a second run of the
# one-liner must not change. test/vm.sh records it before and after that run
# and diffs the two. omamac's logs are left out: every run adds one.
set -euo pipefail

head=$(git -C ~/.local/share/omamac rev-parse HEAD)
{
  /opt/homebrew/bin/brew list --versions | sed 's/^/brew: /'
  shasum -a 256 ~/.zprofile ~/.zshrc
  find ~/.config/omamac -type f -exec shasum -a 256 {} +
  echo "checkout: $head"
} | sort
