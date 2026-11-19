# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
# The app is there, Homebrew lists the cask, its docker link points into the app, and lazydocker runs.
[[ -d /Applications/Docker.app ]]
brew list --cask docker-desktop
[[ $(readlink /usr/local/bin/docker) == /Applications/Docker.app/* ]]
lazydocker --version
# Updating again changes nothing.
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
# Test-only stand-in for the user typing the password: the steps have no keyboard.
# -p '' because vm.exp answers any "Password:" prompt and counts it.
print -r -- admin | sudo -S -p '' -v
# Uninstall takes the app, the cask's links and lazydocker away.
omamac uninstall docker-desktop
[[ ! -e /Applications/Docker.app ]]
if brew list --cask docker-desktop; then exit 1; fi
if brew list --formula lazydocker; then exit 1; fi
[[ ! -e /usr/local/bin/docker && ! -L /usr/local/bin/docker ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'docker=none$'\n'* ]]
# Uninstalling again changes nothing and asks nothing.
before=$(fp)
omamac uninstall docker-desktop
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
