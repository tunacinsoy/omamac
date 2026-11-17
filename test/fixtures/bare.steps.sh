# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
omamac update
before=$(fp)
omamac update
after=$(fp)
[[ $before == "$after" ]]
nvim --headless +qa
[[ $(zsh -ic 'alias ls') == *eza* ]]
omamac doctor
