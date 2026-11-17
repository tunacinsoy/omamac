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
zsh -ic 'az version'
zsh -ic 'aws --version'
zsh -ic 'gcloud version'
zsh -ic 'gh --version'
zsh -ic 'terraform version'
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
