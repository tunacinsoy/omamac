#!/opt/homebrew/bin/bash
# Everything after the restart. First the questions and "Install?", so nothing
# is written before the user says yes; then omamac's zsh file, the core tools
# and LazyVim, the two guarded lines and a summary.
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
# shellcheck source=lib/lines.sh
source "$OMAMAC_CHECKOUT/lib/lines.sh"
# shellcheck source=lib/ui.sh
source "$OMAMAC_CHECKOUT/lib/ui.sh"
# shellcheck source=lib/questions.sh
source "$OMAMAC_CHECKOUT/lib/questions.sh"
# shellcheck source=lib/choices.sh
source "$OMAMAC_CHECKOUT/lib/choices.sh"
# shellcheck source=lib/ask.sh
source "$OMAMAC_CHECKOUT/lib/ask.sh"
# shellcheck source=lib/core.sh
source "$OMAMAC_CHECKOUT/lib/core.sh"
# shellcheck source=lib/neovim.sh
source "$OMAMAC_CHECKOUT/lib/neovim.sh"
# shellcheck source=lib/apply.sh
source "$OMAMAC_CHECKOUT/lib/apply.sh"

OMAMAC_STEP='starting'

install_failed() {
  ui_fail "omamac stopped while $OMAMAC_STEP."
  ui_fail "Fix the problem and run the one-liner again; it picks up where it stopped."
  exit 1
}
trap install_failed ERR

# Ask only what has no saved answer, show every answer, and save them only
# after "Install?" is answered yes: a "no" must leave the next run free to ask again.
install_questions() {
  OMAMAC_STEP='reading your saved answers'
  # choices_load has said what's wrong and how to fix it.
  choices_load "$OMAMAC_CHOICES_FILE" || exit 1
  OMAMAC_STEP='asking the questions'
  local unanswered
  unanswered=$(choices_missing)
  ask_missing
  ask_summary
  if ! ask_install; then
    # Saved answers stay: changing one later is uninstalling one thing and
    # installing another, not answering again.
    if [ -n "$unanswered" ]; then
      ui_info "Stopped. Nothing else was changed. The next run asks those questions again."
    else
      ui_info "Stopped. Nothing else was changed."
    fi
    exit 0
  fi
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  ui_ok "Your answers are saved"
}

install_lines() {
  OMAMAC_STEP='adding Homebrew to ~/.zprofile'
  lines_add "$HOME/.zprofile" "$OMAMAC_ZPROFILE_LINE" 'brew shellenv'
  ui_ok "Homebrew is on the PATH"
  OMAMAC_STEP='adding omamac to ~/.zshrc'
  lines_add "$HOME/.zshrc" "$OMAMAC_ZSHRC_LINE"
  ui_ok "omamac is loaded by zsh"
}

install_summary() {
  OMAMAC_STEP='printing the summary'
  ui_box "Installed: Homebrew, bash, gum, omamac and the core tools" "Log: $OMAMAC_LOG" "Open a new terminal window, then run omamac."
}

install_main() {
  install_questions
  apply_all
  install_lines
  install_summary
}

install_main
