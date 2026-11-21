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
# Not az version: its first run waits for macOS's first-open confirmation, which nobody can click in the VM.
/opt/homebrew/bin/brew list --cask azure-cli >/dev/null
[[ -x /opt/homebrew/bin/az ]]
aws --version
gcloud version
gh --version
terraform version
# Every coding agent's command is Homebrew's. None runs: a cask's binary may
# wait on macOS's first-open check, and each wants a sign-in.
for cmd in claude codex copilot agy opencode; do [[ -x /opt/homebrew/bin/$cmd ]]; done
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
# One coding agent of each kind: codex is a cask, opencode a formula.
omamac uninstall codex
[[ ! -e /opt/homebrew/bin/codex ]]
if /opt/homebrew/bin/brew list --cask codex >/dev/null 2>&1; then exit 1; fi
omamac uninstall opencode
[[ ! -e /opt/homebrew/bin/opencode ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'"coding_agents=claude-code copilot-cli antigravity-cli"$'\n'* ]]
omamac doctor
