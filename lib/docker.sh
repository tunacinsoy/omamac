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
# dangling one), missing (nothing at the path), broken (the user's link to
# nothing, such as one Docker Desktop left) or theirs (anything else).
docker_link_state() {
  local path
  path=$(docker_link_path "$1")
  if [ -L "$path" ]; then
    if [ "$(readlink "$path")" = "$(docker_link_target "$1")" ]; then
      echo ours
    elif [ -e "$path" ]; then
      echo theirs
    else
      echo broken
    fi
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
      # The user's, so it stays; docker can't use it.
      broken) ui_info "Your $plugin link in ~/.docker/cli-plugins points at nothing. Remove it, then run omamac update." ;;
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

# docker_uninstall_colima: take colima's pieces away, never ~/.colima (the
# user's images and volumes) and never a plugin that isn't omamac's link.
# Safe to run again after a failure: each step looks first.
docker_uninstall_colima() {
  local formulas=() installed=() list plugin rc why colima="$OMAMAC_BREW_PREFIX/bin/colima"
  mapfile -t formulas < <(docker_formulas colima)
  list=$(core_where installed "${formulas[@]}") || return
  [ -z "$list" ] || mapfile -t installed <<< "$list"
  # Without the colima formula there is no service to ask about and no binary
  # to stop (a retry after a half-finished uninstall, or colima removed by hand).
  if [[ " ${installed[*]} " == *" colima "* ]]; then
    OMAMAC_STEP="stopping colima"
    rc=0
    why=$(docker_service_registered) || rc=$?
    case $rc in
      0) ui_run "Stopping colima's service" "$OMAMAC_BREW_PREFIX/bin/brew" services stop colima || return ;;
      1) ;;
      *) ui_fail "$why"; return 1 ;;
    esac
    # A VM started by hand outlives the service, and its files go with colima.
    if "$colima" status > /dev/null 2>&1; then
      ui_run "Stopping colima" "$colima" stop || return
    fi
  fi
  OMAMAC_STEP="removing docker's plugin links"
  for plugin in "${DOCKER_PLUGINS[@]}"; do
    [ "$(docker_link_state "$plugin")" != ours ] || rm "$(docker_link_path "$plugin")"
  done
  # rmdir only removes an empty folder.
  rmdir "$HOME/.docker/cli-plugins" 2> /dev/null || true
  OMAMAC_STEP="removing colima"
  if [ "${#installed[@]}" -gt 0 ]; then
    ui_run "Removing $(clis_join "${installed[@]}")" "$OMAMAC_BREW_PREFIX/bin/brew" uninstall "${installed[@]}" || return
  fi
  rm -f "$OMAMAC_COLIMA_MARKER"
}

# docker_check: doctor's lines for colima's plugin links and its service
# (doctor_check_chosen reports its formulas). Returns 1 only for a ✗.
docker_check() {
  local plugin state rc status=0
  [ "${CHOICES[docker]:-none}" = colima ] || return 0
  for plugin in "${DOCKER_PLUGINS[@]}"; do
    state=$(docker_link_state "$plugin")
    if [ "$state" = theirs ]; then
      doctor_report info "$plugin" "your own file in ~/.docker/cli-plugins is kept, and docker uses it"
    elif [ "$state" = broken ]; then
      doctor_report fail "$plugin" "your link in ~/.docker/cli-plugins points at nothing" \
        "Remove it, then run omamac update" || status=1
    elif [ "$state" = ours ] && [ -e "$(docker_link_path "$plugin")" ]; then
      doctor_report ok "$plugin"
    else
      doctor_report fail "$plugin" "docker can't find ${plugin#docker-}" "omamac update" || status=1
    fi
  done
  # The service is colima's state, not omamac's, so it is never a ✗.
  rc=0
  docker_service_registered > /dev/null 2>&1 || rc=$?
  case $rc in
    0)
      if [ "$(docker_service_status)" = error ]; then
        doctor_report info "colima's service" "colima didn't start; see $OMAMAC_BREW_PREFIX/var/log/colima.log"
      else
        doctor_report ok "colima's service"
      fi
      ;;
    1) doctor_report info "colima's service" "colima doesn't start at login. To start it: brew services start colima" ;;
    *) doctor_report info "colima's service" "skipped, Homebrew can't say whether it's registered" ;;
  esac
  return "$status"
}

# docker_service_status: Homebrew's status for colima's service (started,
# error, none, ...); empty when Homebrew can't say.
docker_service_status() {
  local out
  out=$("$OMAMAC_BREW_PREFIX/bin/brew" services info colima --json 2> /dev/null) &&
    jq -r '.[0].status' <<< "$out" 2> /dev/null
}
