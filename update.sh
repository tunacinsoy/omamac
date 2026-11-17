#!/opt/homebrew/bin/bash
# omamac update, after bin/omamac pulled the new code: with the saved answers
# and no questions, put back what's missing, then upgrade what omamac installed.
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
# shellcheck source=lib/apply.sh
source "$OMAMAC_CHECKOUT/lib/apply.sh"

OMAMAC_STEP='starting'

update_failed() {
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

# update_upgrade: upgrade, by name, the installed formulas omamac installs.
update_upgrade() {
  local formula installed=()
  OMAMAC_STEP='upgrading your tools'
  for formula in "${CORE_FORMULAS[@]}" bash gum; do
    if "$OMAMAC_BREW_PREFIX/bin/brew" list --formula "$formula" >/dev/null 2>&1; then
      installed+=("$formula")
    fi
  done
  # A bare brew upgrade would upgrade everything the user has.
  [ "${#installed[@]}" -gt 0 ] || return 0
  ui_run "Upgrading your tools" "$OMAMAC_BREW_PREFIX/bin/brew" upgrade "${installed[@]}"
}

update_main() {
  log_start
  update_choices
  apply_all
  update_upgrade
  OMAMAC_STEP='printing the summary'
  ui_box "omamac and your tools are up to date." "Log: $OMAMAC_LOG"
}

update_main
