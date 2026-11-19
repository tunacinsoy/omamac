# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
# colima's service is registered, the links point at Homebrew's plugins, and the tools run.
[[ $(brew services info colima --json | jq -r '.[0].registered') == true ]]
[[ -e ~/.local/state/omamac/colima-service ]]
[[ $(readlink ~/.docker/cli-plugins/docker-compose) == /opt/homebrew/opt/docker-compose/bin/docker-compose ]]
[[ $(readlink ~/.docker/cli-plugins/docker-buildx) == /opt/homebrew/opt/docker-buildx/bin/docker-buildx ]]
docker compose version
docker buildx version
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
# Test-only stand-in for real hardware: the macOS test VM has no nested
# virtualization, so colima runs only under emulation, started from the shell
# (launchd's start times out under emulation). Gate B checks colima on real hardware.
brew install qemu lima-additional-guestagents
brew services stop colima
colima delete -f
colima start --arch x86_64 --vm-type qemu --cpus 2 --memory 2
[[ $(docker run --rm hello-world) == *"Hello from Docker!"* ]]
# Uninstall takes colima's pieces away and keeps the user's data in ~/.colima.
omamac uninstall colima
formulas=$(brew list --formula -1)
for f in colima docker docker-compose docker-buildx lazydocker; do
  [[ $'\n'$formulas$'\n' != *$'\n'$f$'\n'* ]]
done
for p in docker-compose docker-buildx; do
  [[ ! -e ~/.docker/cli-plugins/$p && ! -L ~/.docker/cli-plugins/$p ]]
done
[[ ! -e ~/.local/state/omamac/colima-service ]]
[[ -d ~/.colima ]]
choices=$(< ~/.local/state/omamac/choices.env)
[[ $'\n'$choices$'\n' == *$'\n'docker=none$'\n'* ]]
# Uninstalling again changes nothing and asks nothing.
before=$(fp)
omamac uninstall colima
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
