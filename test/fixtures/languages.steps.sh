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
# Prompts first: an interactive zsh (zsh -ic) takes the terminal and doesn't
# give it back, so a gum prompt after one can't read the keyboard.
(cd ~ && /opt/homebrew/bin/mise exec go -- go version)
# Uninstall go twice: no mise version and no saved choice is left, and the second run changes nothing.
omamac uninstall go
[[ -z $(cd ~ && /opt/homebrew/bin/mise ls --installed --no-header go) ]]
[[ $(grep '^languages=' ~/.local/state/omamac/choices.env) != *go* ]]
before=$(fp)
omamac uninstall go
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
zsh -ic 'ruby -v'
zsh -ic 'rails -v'
zsh -ic 'node -v'
zsh -ic 'python -V'
zsh -ic 'elixir -v'
zsh -ic 'cargo -V'
zsh -ic 'java -version'
omamac doctor
