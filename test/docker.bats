load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
  install_fake_brew
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  P="$OMAMAC_TEST_BREW_PREFIX"
  PLUGINS="$HOME/.docker/cli-plugins"
  MARKER="$HOME/.local/state/omamac/colima-service"
  NOTE="colima starts Docker in the background now and at each login. The first start downloads Linux and takes a few minutes."
  : > "$STUB_LOG"
}

# in_lib <docker> <code>: run bash 5 code with the Docker step loaded and
# CHOICES[docker] set to <docker>.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    for f in paths ui questions choices core clis docker; do source '$REPO_ROOT/lib/'\$f.sh; done
    CHOICES[docker]='$1'
    $2"
}

installs() { grep '^brew install' "$STUB_LOG" || true; }
starts() { grep -c '^brew services start colima$' "$STUB_LOG" || true; }

@test "colima: installs only the missing formulas, in one call" {
  "$P/bin/brew" install docker
  : > "$STUB_LOG"
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(installs)" = "brew install colima docker-compose docker-buildx lazydocker" ]
  [[ "$output" == *"✓ colima is installed"* ]]
}

@test "colima: links both plugins to Homebrew's" {
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(readlink "$PLUGINS/docker-compose")" = "$P/opt/docker-compose/bin/docker-compose" ]
  [ "$(readlink "$PLUGINS/docker-buildx")" = "$P/opt/docker-buildx/bin/docker-buildx" ]
  [ -e "$PLUGINS/docker-compose" ]
  [ -e "$PLUGINS/docker-buildx" ]
}

@test "colima: leaves a user's plugin file alone" {
  mkdir -p "$PLUGINS"
  echo mine > "$PLUGINS/docker-compose"
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(cat "$PLUGINS/docker-compose")" = mine ]
  [ ! -L "$PLUGINS/docker-compose" ]
  [ "$(grep -c 'ℹ.*docker-compose' <<< "$output")" -eq 1 ]
  [ "$(readlink "$PLUGINS/docker-buildx")" = "$P/opt/docker-buildx/bin/docker-buildx" ]
}

@test "docker_link_state: ours, missing, theirs or broken" {
  mkdir -p "$PLUGINS"
  ln -s "$P/opt/docker-compose/bin/docker-compose" "$PLUGINS/docker-compose"
  echo x > "$BATS_TEST_TMPDIR/their-buildx"
  ln -s "$BATS_TEST_TMPDIR/their-buildx" "$PLUGINS/docker-buildx"
  in_lib colima 'docker_link_state docker-compose; docker_link_state docker-buildx
    rm "$HOME/.docker/cli-plugins/docker-buildx"; docker_link_state docker-buildx
    echo x > "$HOME/.docker/cli-plugins/docker-buildx"; docker_link_state docker-buildx
    rm "$HOME/.docker/cli-plugins/docker-buildx"; ln -s /somewhere/else "$HOME/.docker/cli-plugins/docker-buildx"
    docker_link_state docker-buildx'
  [ "$status" -eq 0 ]
  [ "$output" = "ours
theirs
missing
theirs
broken" ]
}

@test "colima: a user's link that points at nothing stays, with what to do" {
  # What Docker Desktop leaves behind once its app is trashed.
  mkdir -p "$PLUGINS"
  ln -s /Applications/Docker.app/Contents/Resources/cli-plugins/docker-compose "$PLUGINS/docker-compose"
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(readlink "$PLUGINS/docker-compose")" = /Applications/Docker.app/Contents/Resources/cli-plugins/docker-compose ]
  [[ "$output" == *"ℹ Your docker-compose link in ~/.docker/cli-plugins points at nothing. Remove it, then run omamac update."* ]]
  [[ "$output" != *"docker uses it"* ]]
  [ "$(readlink "$PLUGINS/docker-buildx")" = "$P/opt/docker-buildx/bin/docker-buildx" ]
}

@test "colima: starts the service once and writes the marker" {
  in_lib colima 'docker_install; printf "notes: %s\n" "${DOCKER_NOTES[*]}"'
  [ "$status" -eq 0 ]
  [ "$(starts)" -eq 1 ]
  [ -f "$MARKER" ]
  [[ "$output" == *"notes: $NOTE"* ]]
}

@test "colima: a second run starts nothing and changes nothing" {
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  before="$(readlink "$PLUGINS/docker-compose") $(readlink "$PLUGINS/docker-buildx") $(stat -f %m "$MARKER")"
  : > "$STUB_LOG"
  in_lib colima 'docker_install; printf "notes: %s\n" "${DOCKER_NOTES[*]}"'
  [ "$status" -eq 0 ]
  [ "$(starts)" -eq 0 ]
  [ -z "$(installs)" ]
  [ "$(readlink "$PLUGINS/docker-compose") $(readlink "$PLUGINS/docker-buildx") $(stat -f %m "$MARKER")" = "$before" ]
  [[ "$output" == *"notes: "* && "$output" != *"first start"* ]]
}

@test "colima: a registered service isn't started, the marker is written" {
  mkdir -p "$P/services"
  : > "$P/services/colima"
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(starts)" -eq 0 ]
  [ -f "$MARKER" ]
}

@test "colima: with the marker, a stopped service stays stopped" {
  mkdir -p "$(dirname "$MARKER")"
  : > "$MARKER"
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(starts)" -eq 0 ]
  [ ! -e "$P/services/colima" ]
}

@test "colima: a failed install starts the service on the next run" {
  T_BREW_FAIL=1 in_lib colima 'docker_install'
  [ "$status" -ne 0 ]
  [ "$(starts)" -eq 0 ]
  [ ! -e "$MARKER" ]
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(starts)" -eq 1 ]
  [ -f "$MARKER" ]
}

@test "colima: a failed service start is tried again on the next run" {
  T_BREW_SERVICES_FAIL=1 in_lib colima 'docker_install'
  [ "$status" -ne 0 ]
  [ ! -e "$MARKER" ]
  : > "$STUB_LOG"
  in_lib colima 'docker_install'
  [ "$status" -eq 0 ]
  [ "$(starts)" -eq 1 ]
  [ -f "$MARKER" ]
  [ -e "$P/services/colima" ]
}

@test "colima: Homebrew failing to read the service stops the step" {
  T_BREW_SERVICES_INFO_FAIL=1 in_lib colima 'docker_service_registered'
  [ "$status" -eq 2 ]
  [[ "$output" == *"colima's service"* ]]
  T_BREW_SERVICES_INFO_FAIL=1 in_lib colima 'docker_install'
  [ "$status" -ne 0 ]
  [[ "$output" == *"✗"*"colima's service"* ]]
  [ "$(starts)" -eq 0 ]
  [ ! -e "$MARKER" ]
}

@test "colima: a failed link stops the step, without the marker or ✓" {
  # Doctor's Reinstall calls docker_install after ||, where errexit is off.
  : > "$HOME/.docker"
  in_lib colima 'docker_install || echo "returned $?"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"returned "[1-9]* ]]
  [[ "$output" != *"✓"* ]]
  [ ! -e "$MARKER" ]
  [ "$(starts)" -eq 0 ]
}

@test "none: installs nothing" {
  in_lib none 'docker_install'
  [ "$status" -eq 0 ]
  [ -z "$(stub_calls)" ]
  [ ! -e "$HOME/.docker" ]
  [ ! -e "$MARKER" ]
}

@test "docker_formulas: colima's five; nothing for the others" {
  in_lib none 'docker_formulas colima | tr "\n" " "; echo "|$(docker_formulas docker-desktop)|$(docker_formulas none)|"'
  [ "$status" -eq 0 ]
  [ "$output" = "colima docker docker-compose docker-buildx lazydocker |lazydocker||" ]
}

@test "the Docker question has no OrbStack" {
  in_lib none 'question_values docker | tr "\n" " "; echo "${QUESTION_HELP[docker]}"'
  [ "$status" -eq 0 ]
  [ "$output" = "none colima docker-desktop colima runs Docker in the background from the command line. Docker Desktop is an app; larger companies need a paid plan for it." ]
}

@test "install summary prints the colima line" {
  "$P/bin/brew" install gum
  choices="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$choices")"
  sed 's/^docker=none$/docker=colima/' "$REPO_ROOT/test/fixtures/bare.env" > "$choices"
  gum_answers yes
  run "$BASH5" "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"and the languages, cloud CLIs and Docker you chose."* ]]
  [[ "$output" == *"colima starts Docker in the background now and at each login."* ]]
  [[ "$output" == *"The first start downloads Linux and takes a few minutes."* ]]
  # The notes come before the log line.
  [[ "$output" == *"takes a few minutes."*"Log: "* ]]
}

@test "install summary names Docker for Docker Desktop" {
  "$P/bin/brew" install gum
  choices="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$choices")"
  sed 's/^docker=none$/docker=docker-desktop/' "$REPO_ROOT/test/fixtures/bare.env" > "$choices"
  gum_answers yes
  run "$BASH5" "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"and the languages, cloud CLIs and Docker you chose."* ]]
  [[ "$output" == *"Open Docker Desktop once to finish its setup."* ]]
}

@test "colima: a failed marker write stops the run" {
  mkdir -p "$(dirname "$MARKER")"
  chmod a-w "$(dirname "$MARKER")"
  in_lib colima 'docker_install || echo "rc=$?"'
  chmod u+w "$(dirname "$MARKER")"
  [[ "$output" == *"rc="* ]]
  [[ "$output" != *"✓ colima is installed"* ]]
}

DESKTOP_NOTE="Open Docker Desktop once to finish its setup."

@test "docker_formulas: Docker Desktop's is lazydocker" {
  in_lib docker-desktop 'docker_formulas docker-desktop'
  [ "$output" = lazydocker ]
}

@test "desktop: installs lazydocker and the cask, asking for sudo first" {
  # shellcheck disable=SC2016 # the stub expands $1 itself
  stub sudo '[ "$1" != -n ] || exit 1'
  in_lib docker-desktop 'docker_install; printf "%s\n" "${DOCKER_NOTES[@]}"'
  [ "$status" -eq 0 ]
  [ -d "$OMAMAC_TEST_APPLICATIONS/Docker.app" ]
  [[ "$output" == *"needs your password"* ]]
  [[ "$output" == *"✓ Docker Desktop is installed"* ]]
  [[ "$output" == *"$DESKTOP_NOTE"* ]]
  [ "$(stub_calls | grep -c '^brew install lazydocker$')" -eq 1 ]
  [ "$(stub_calls | grep -E '^(sudo|brew install --cask)' | tr '\n' ',')" = "sudo -n true,sudo -v,brew install --cask docker-desktop," ]
}

@test "desktop: valid sudo asks nothing" {
  in_lib docker-desktop 'docker_install'
  [ "$status" -eq 0 ]
  [[ "$output" != *"needs your password"* ]]
  ! stub_calls | grep -q '^sudo -v'
  stub_calls | grep -qx 'brew install --cask docker-desktop'
}

@test "desktop: a failed sudo -v stops before the cask" {
  stub sudo 'exit 1'
  in_lib docker-desktop 'docker_install || echo "rc=$?"'
  [[ "$output" == *"rc="* ]]
  ! stub_calls | grep -q 'brew install --cask'
  [[ "$output" != *"✓ Docker Desktop is installed"* ]]
}

@test "desktop: already from Homebrew, a second run changes nothing" {
  "$P/bin/brew" install lazydocker
  "$P/bin/brew" install --cask docker-desktop
  : > "$STUB_LOG"
  in_lib docker-desktop 'docker_install; echo "notes=${#DOCKER_NOTES[@]}"'
  [ "$status" -eq 0 ]
  ! stub_calls | grep -Eq '^brew (install|reinstall)'
  ! stub_calls | grep -q '^sudo'
  [[ "$output" == *"notes=0"* ]]
  [[ "$output" == *"✓ Docker Desktop is installed"* ]]
}

@test "desktop: listed by Homebrew but the app is gone, reinstalls it" {
  "$P/bin/brew" install lazydocker
  "$P/bin/brew" install --cask docker-desktop
  rm -rf "$OMAMAC_TEST_APPLICATIONS/Docker.app"
  : > "$STUB_LOG"
  in_lib docker-desktop 'docker_install; printf "%s\n" "${DOCKER_NOTES[@]}"'
  [ "$status" -eq 0 ]
  stub_calls | grep -qx 'brew reinstall --cask docker-desktop'
  [ -d "$OMAMAC_TEST_APPLICATIONS/Docker.app" ]
  [[ "$output" == *"$DESKTOP_NOTE"* ]]
}

@test "desktop: a hand-installed app is used as it is" {
  "$P/bin/brew" install lazydocker
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/Docker.app"
  : > "$STUB_LOG"
  in_lib docker-desktop 'docker_install; echo "notes=${#DOCKER_NOTES[@]}"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Docker Desktop is already installed, not through Homebrew. omamac won't update it."* ]]
  [[ "$output" == *"✓ Docker Desktop is installed"* ]]
  [[ "$output" == *"notes=0"* ]]
  ! stub_calls | grep -q -- '--cask'
  ! stub_calls | grep -q '^sudo'
}

@test "desktop: the user's own docker formula stays, the cask installs" {
  "$P/bin/brew" install docker
  : > "$STUB_LOG"
  in_lib docker-desktop 'docker_install'
  [ "$status" -eq 0 ]
  stub_calls | grep -qx 'brew install --cask docker-desktop'
  ! stub_calls | grep -Eq '^brew (uninstall|install) docker$'
}
