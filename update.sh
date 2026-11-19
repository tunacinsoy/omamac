#!/opt/homebrew/bin/bash
# omamac update, after bin/omamac pulled the new code: with the saved answers
# and no questions, put back what's missing, then upgrade what omamac installed.
# An older bin/omamac execs this file with no arguments after pulling, so it
# must keep working when started that way.
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

# Keep this check first and bash 3.2-safe: a Mac's /bin/bash must reach the message.
if [ "${BASH_VERSINFO[0]}" -lt 5 ]; then
  echo "omamac needs bash 5. Run the one-liner again; it installs bash for you." >&2
  exit 1
fi

OMAMAC_CHECKOUT=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib/paths.sh
source "$OMAMAC_CHECKOUT/lib/paths.sh"
# shellcheck source=lib/ui.sh
source "$OMAMAC_CHECKOUT/lib/ui.sh"
# shellcheck source=lib/log.sh
source "$OMAMAC_CHECKOUT/lib/log.sh"
# shellcheck source=lib/questions.sh
source "$OMAMAC_CHECKOUT/lib/questions.sh"
# shellcheck source=lib/choices.sh
source "$OMAMAC_CHECKOUT/lib/choices.sh"
# shellcheck source=lib/core.sh
source "$OMAMAC_CHECKOUT/lib/core.sh"
# shellcheck source=lib/neovim.sh
source "$OMAMAC_CHECKOUT/lib/neovim.sh"
# shellcheck source=lib/herdr.sh
source "$OMAMAC_CHECKOUT/lib/herdr.sh"
# shellcheck source=lib/ghostty.sh
source "$OMAMAC_CHECKOUT/lib/ghostty.sh"
# shellcheck source=lib/theme.sh
source "$OMAMAC_CHECKOUT/lib/theme.sh"
# shellcheck source=lib/languages.sh
source "$OMAMAC_CHECKOUT/lib/languages.sh"
# shellcheck source=lib/clis.sh
source "$OMAMAC_CHECKOUT/lib/clis.sh"
# shellcheck source=lib/docker.sh
source "$OMAMAC_CHECKOUT/lib/docker.sh"
# shellcheck source=lib/appmanagement.sh
source "$OMAMAC_CHECKOUT/lib/appmanagement.sh"
# shellcheck source=lib/settings.sh
source "$OMAMAC_CHECKOUT/lib/settings.sh"
# shellcheck source=lib/apply.sh
source "$OMAMAC_CHECKOUT/lib/apply.sh"

OMAMAC_STEP='starting'
# Labels of apps whose upgrade was skipped on purpose; update finishes, then exits 1.
UPDATE_NOT_UPGRADED=()

update_failed() {
  # With set -E the trap also runs inside ( … ) and $( … ); let only the main shell speak.
  [ "$BASHPID" -eq "$$" ] || exit 1
  ui_fail "omamac stopped while $OMAMAC_STEP."
  ui_fail "Fix the problem and run omamac update again."
  exit 1
}
trap update_failed ERR

update_choices() {
  OMAMAC_STEP='reading your saved answers'
  # choices_load reads a missing file as no answers; update has no questions to ask.
  if [ ! -e "$OMAMAC_CHOICES_FILE" ]; then
    ui_fail "omamac doesn't know your answers. Fix: run the one-liner."
    exit 1
  fi
  # choices_load has said what's wrong and how to fix it.
  choices_load "$OMAMAC_CHOICES_FILE" || exit 1
}

# update_upgrade: upgrade, by name, the installed formulas omamac installs:
# the core, bash, gum and the chosen cloud CLIs (full names).
update_upgrade() {
  local list pinned_list installed=() pinned=() kept=() name ids=() chosen=()
  local -A is_pinned=()
  OMAMAC_STEP='upgrading your tools'
  list=$(core_where installed "${CORE_FORMULAS[@]}" bash gum)
  [ -z "$list" ] || mapfile -t installed <<< "$list"
  read -ra ids <<< "${CHOICES[cloud_clis]:-}"
  if [ "${#ids[@]}" -gt 0 ]; then
    list=$(clis_where installed "${ids[@]}")
    [ -z "$list" ] || mapfile -t chosen <<< "$list"
    for name in "${chosen[@]}"; do
      [ -z "${CLI_FORMULA[$name]:-}" ] || installed+=("${CLI_FORMULA[$name]}")
    done
  fi
  # Only the answer's own Docker formulas: with none, a user's own docker is theirs.
  list=$(docker_formulas "${CHOICES[docker]:-none}")
  if [ -n "$list" ]; then
    mapfile -t chosen <<< "$list"
    list=$(core_where installed "${chosen[@]}")
    [ -z "$list" ] || { mapfile -t chosen <<< "$list"; installed+=("${chosen[@]}"); }
  fi
  # brew upgrade fails when a named formula is pinned, so leave those out.
  # brew list --pinned prints short names, so compare the last / part.
  pinned_list=$("$OMAMAC_BREW_PREFIX/bin/brew" list --pinned)
  [ -z "$pinned_list" ] || mapfile -t pinned <<< "$pinned_list"
  for name in "${pinned[@]}"; do is_pinned[$name]=1; done
  list=("${installed[@]}")
  installed=()
  for name in "${list[@]}"; do
    if [ -n "${is_pinned[${name##*/}]:-}" ]; then kept+=("$name"); else installed+=("$name"); fi
  done
  [ "${#kept[@]}" -eq 0 ] || ui_info "Kept ${kept[*]} at the pinned version."
  # A bare brew upgrade would upgrade everything the user has.
  [ "${#installed[@]}" -gt 0 ] || return 0
  ui_run "Upgrading your tools" "$OMAMAC_BREW_PREFIX/bin/brew" upgrade "${installed[@]}"
}

# update_upgrade_casks: the chosen CLIs that are casks and installed, in one
# greedy call, as casks update themselves and brew would otherwise skip them.
update_upgrade_casks() {
  local ids=() id list casks=() names=()
  read -ra ids <<< "${CHOICES[cloud_clis]:-}"
  OMAMAC_STEP='upgrading the cloud CLI casks'
  for id in "${ids[@]}"; do
    [ -z "${CLI_CASK[$id]:-}" ] || casks+=("$id")
  done
  [ "${#casks[@]}" -gt 0 ] || return 0
  list=$(clis_where installed "${casks[@]}") || return
  [ -n "$list" ] || return 0
  mapfile -t casks <<< "$list"
  for id in "${casks[@]}"; do names+=("${CLI_CASK[$id]}"); done
  ui_run "Upgrading the cloud CLIs that are casks" "$OMAMAC_BREW_PREFIX/bin/brew" upgrade --cask --greedy "${names[@]}"
}

# update_upgrade_app <cask> <label>: upgrade an app when Homebrew manages it and
# says it is outdated. Homebrew replaces the app, which needs App Management;
# without it, skip only this, say how to fix it, and let update_main finish and
# exit 1.
update_upgrade_app() {
  local cask=$1 label=$2 state out status=0 app="$OMAMAC_APPLICATIONS/${CASK_APP[$1]}"
  OMAMAC_STEP="upgrading $label"
  state=$(core_cask_state "$cask") || return
  [ "$state" = brew ] || return 0
  # No --greedy: the app updates itself, and --greedy would compare only
  # Homebrew's own record, so update would call it outdated forever.
  # brew outdated exits 1 when the named cask is outdated; the output says which.
  out=$("$OMAMAC_BREW_PREFIX/bin/brew" outdated --cask --quiet "$cask") || true
  [ -n "$out" ] || return 0
  app_management_ok "$app" || status=$?
  case $status in
    0)
      if [ "$cask" = docker-desktop ]; then
        docker_cask_run "Upgrading $label" upgrade --cask "$cask"
      else
        ui_run "Upgrading $label" "$OMAMAC_BREW_PREFIX/bin/brew" upgrade --cask "$cask"
      fi
      ;;
    1)
      ui_fail "$label has an update, but macOS won't let your terminal change apps."
      ui_fail "Fix: System Settings → Privacy & Security → App Management, turn on your terminal, then run omamac update again."
      open "$APP_MANAGEMENT_URL" || true
      UPDATE_NOT_UPGRADED+=("$label")
      ;;
    *)
      ui_fail "$label has an update, but omamac couldn't test write access to $app."
      UPDATE_NOT_UPGRADED+=("$label")
      ;;
  esac
}

# update_upgrade_languages: the chosen languages to their newest versions, old
# ones pruned, then the rails gem.
update_upgrade_languages() {
  local ids=() id tools=() t
  read -ra ids <<< "${CHOICES[languages]:-}"
  [ "${#ids[@]}" -gt 0 ] || return 0
  OMAMAC_STEP='upgrading your languages'
  for id in "${ids[@]}"; do
    read -ra t <<< "${LANGUAGE_TOOLS[$id]}"
    tools+=("${t[@]}")
  done
  (cd "$HOME" && ui_run "Upgrading your languages" "$OMAMAC_BREW_PREFIX/bin/mise" upgrade "${tools[@]}")
  # Prune may ask before removing each old version; choosing update is the yes.
  (cd "$HOME" && MISE_YES=1 ui_run "Removing old language versions" "$OMAMAC_BREW_PREFIX/bin/mise" prune --tools "${tools[@]}")
  if [[ " ${ids[*]} " == *" ruby "* ]]; then languages_rails; fi
}

update_main() {
  log_start
  update_choices
  apply_all
  update_upgrade
  update_upgrade_casks
  update_upgrade_app ghostty Ghostty
  [ "${CHOICES[docker]:-}" != docker-desktop ] || update_upgrade_app docker-desktop "Docker Desktop"
  update_upgrade_languages
  OMAMAC_STEP='printing the summary'
  # This run may be the one that started colima's service, as install would have.
  local notes=()
  [ "${#DOCKER_NOTES[@]}" -eq 0 ] || notes=("" "${DOCKER_NOTES[@]}" "")
  if [ "${#UPDATE_NOT_UPGRADED[@]}" -gt 0 ]; then
    local names verb=is
    names=${UPDATE_NOT_UPGRADED[0]}
    [ "${#UPDATE_NOT_UPGRADED[@]}" -eq 1 ] || { names+=" and ${UPDATE_NOT_UPGRADED[1]}"; verb=are; }
    ui_box "✗ Everything else is up to date. $names $verb not." "${notes[@]}" "Log: $OMAMAC_LOG" >&2
    exit 1
  fi
  ui_box "omamac and your tools are up to date." "${notes[@]}" "Log: $OMAMAC_LOG"
}

update_main
