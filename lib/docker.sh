# shellcheck shell=bash
# shellcheck disable=SC2034 # DOCKER_NOTES is read by install_summary
# Docker, the way the user chose. Sourced after lib/paths.sh, lib/ui.sh,
# lib/choices.sh, lib/core.sh and lib/clis.sh, before lib/apply.sh.

# docker's plugins: Homebrew's docker doesn't find Homebrew's, so omamac links
# them into docker's own plugin folder.
DOCKER_PLUGINS=(docker-compose docker-buildx)
# Lines for the run's summary box.
DOCKER_NOTES=()

# docker_formulas <answer>: the formulas omamac installs for that answer, one per line.
docker_formulas() {
  case $1 in
    colima) printf '%s\n' colima docker docker-compose docker-buildx lazydocker ;;
  esac
}

docker_link_path() { echo "$HOME/.docker/cli-plugins/$1"; }
docker_link_target() { echo "$OMAMAC_BREW_PREFIX/opt/$1/bin/$1"; }

# docker_link_state <plugin>: ours (a link to Homebrew's plugin, even a
# dangling one), missing (nothing at the path) or theirs (anything else).
docker_link_state() {
  local path
  path=$(docker_link_path "$1")
  if [ -L "$path" ]; then
    if [ "$(readlink "$path")" = "$(docker_link_target "$1")" ]; then echo ours; else echo theirs; fi
  elif [ -e "$path" ]; then
    echo theirs
  else
    echo missing
  fi
}

# docker_service_registered: 0 when colima's Homebrew service is registered,
# 1 when it isn't, 2 when Homebrew can't say (prints why). jq from PATH:
# macOS 27 has /usr/bin/jq, and the core tools add Homebrew's.
docker_service_registered() {
  local out registered
  out=$("$OMAMAC_BREW_PREFIX/bin/brew" services info colima --json) &&
    registered=$(jq -r '.[0].registered' <<< "$out") || registered=''
  case $registered in
    true) return 0 ;;
    false) return 1 ;;
  esac
  echo "Homebrew can't say whether colima's service is registered."
  return 2
}

# docker_install: what the Docker answer needs. For colima: the missing
# formulas in one brew call, the plugin links, and the login service, started
# only once (see OMAMAC_COLIMA_MARKER).
docker_install() {
  local formulas=() list missing=() plugin rc why
  DOCKER_NOTES=()
  [ "${CHOICES[docker]:-none}" = colima ] || return 0
  mapfile -t formulas < <(docker_formulas colima)
  # Not mapfile < <(…): that would hide a failed brew list and install nothing.
  list=$(core_where missing "${formulas[@]}") || return
  [ -z "$list" ] || mapfile -t missing <<< "$list"
  if [ "${#missing[@]}" -gt 0 ]; then
    ui_run "Installing $(clis_join "${missing[@]}")" "$OMAMAC_BREW_PREFIX/bin/brew" install "${missing[@]}" || return
  fi
  for plugin in "${DOCKER_PLUGINS[@]}"; do
    case $(docker_link_state "$plugin") in
      missing)
        mkdir -p "$HOME/.docker/cli-plugins"
        ln -s "$(docker_link_target "$plugin")" "$(docker_link_path "$plugin")"
        ;;
      theirs) ui_info "Your own $plugin in ~/.docker/cli-plugins stays, and docker uses it." ;;
    esac
  done
  if [ ! -e "$OMAMAC_COLIMA_MARKER" ]; then
    rc=0
    why=$(docker_service_registered) || rc=$?
    case $rc in
      0) ;;
      1) ui_run "Starting colima's service" "$OMAMAC_BREW_PREFIX/bin/brew" services start colima || return ;;
      *) ui_fail "$why"; return 1 ;;
    esac
    mkdir -p "$OMAMAC_STATE_DIR"
    : > "$OMAMAC_COLIMA_MARKER"
    # Two lines, so the summary box fits an 80-column terminal.
    DOCKER_NOTES+=("colima starts Docker in the background now and at each login."
      "The first start downloads Linux and takes a few minutes.")
  fi
  ui_ok "colima is installed"
}
