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
out=$(nvim --headless "+Lazy! sync" +qa 2>&1) || { print -r -- "$out"; exit 1; }
if print -r -- "$out" | grep -Eq 'Error detected|E5108'; then print -r -- "$out"; exit 1; fi
[[ $(zsh -ic 'alias ls') == *eza* ]]
omamac doctor
