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
[[ $(zsh -ic 'print -r -- $HERDR_CONFIG_PATH') == ~/.config/omamac/herdr.toml ]]
[[ $(zsh -ic 'herdr config check' 2>&1) == "config: ok"* ]]
{ ~/.local/share/omamac/bin/omamac-herdr-mode bogus; [[ $? -eq 2 ]]; } || exit 1
# Stands in for the user's Open click. It must come before anything starts
# Ghostty: a quarantined Ghostty hangs on the Open? dialog.
xattr -dr com.apple.quarantine /Applications/Ghostty.app
G=/Applications/Ghostty.app/Contents/MacOS/ghostty
cfg=$($G +show-config --no-pager)
# Matched in the shell, not with | grep -q: under pipefail an early-exiting
# grep can fail the pipe.
[[ $'\n'$cfg$'\n' == *$'\n'"command = direct:$HOME/.local/share/omamac/bin/omamac-terminal"$'\n'* ]]
[[ $'\n'$cfg$'\n' == *$'\n''macos-option-as-alt = left'$'\n'* ]]
# open -a reaches the logged-in GUI session; Ghostty then starts herdr, which
# starts a detached "herdr server". Wait for it, then read its environment.
open -a Ghostty
pid=
for _ in {1..30}; do
  # Not anchored: the server runs as /opt/homebrew/bin/herdr server.
  pid=$(pgrep -f 'herdr server' | head -n 1) || true
  [[ -n $pid ]] && break
  sleep 1
done
if [[ -z $pid ]]; then
  print -r -- "herdr's server did not start within 30 s of opening Ghostty. herdr processes:"
  pgrep -fl herdr || true
  exit 1
fi
env=$(ps -E -ww -o command= -p "$pid")
[[ $env == *"HERDR_CONFIG_PATH=$HOME/.config/omamac/herdr.toml"* ]] ||
  { print -r -- "herdr server (pid $pid) lacks HERDR_CONFIG_PATH"; exit 1; }
omamac doctor
