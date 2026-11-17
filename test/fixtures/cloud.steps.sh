# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
# Homebrew's bin is already on the PATH here. No zsh -ic: an interactive zsh
# takes the terminal and doesn't give it back, so a later gum prompt fails.
az version
aws --version
gcloud version
gh --version
terraform version
# Uninstall terraform and gcloud, each twice: Homebrew no longer has it, and the second run changes nothing.
omamac uninstall terraform
if /opt/homebrew/bin/brew list --formula hashicorp/tap/terraform >/dev/null 2>&1; then exit 1; fi
before=$(fp)
omamac uninstall terraform
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac uninstall gcloud
if /opt/homebrew/bin/brew list --cask gcloud-cli >/dev/null 2>&1; then exit 1; fi
before=$(fp)
omamac uninstall gcloud
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
