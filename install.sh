#!/opt/homebrew/bin/bash
# Everything after the restart. First the questions and "Install?", so nothing
# is written before the user says yes; then omamac's zsh file, herdr's config,
# mise's drop-in, the core tools (Ghostty too), LazyVim, the languages, the
# cloud CLIs, Docker, the guarded lines (zprofile, zshrc, and Ghostty's include line)
# and a summary.
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
# shellcheck source=lib/apps.sh
source "$OMAMAC_CHECKOUT/lib/apps.sh"
# shellcheck source=lib/neovim.sh
source "$OMAMAC_CHECKOUT/lib/neovim.sh"
# shellcheck source=lib/herdr.sh
source "$OMAMAC_CHECKOUT/lib/herdr.sh"
# shellcheck source=lib/ghostty.sh
source "$OMAMAC_CHECKOUT/lib/ghostty.sh"
# shellcheck source=lib/theme.sh
source "$OMAMAC_CHECKOUT/lib/theme.sh"
# shellcheck source=lib/vscode.sh
source "$OMAMAC_CHECKOUT/lib/vscode.sh"
# shellcheck source=lib/languages.sh
source "$OMAMAC_CHECKOUT/lib/languages.sh"
# shellcheck source=lib/clis.sh
source "$OMAMAC_CHECKOUT/lib/clis.sh"
# shellcheck source=lib/docker.sh
source "$OMAMAC_CHECKOUT/lib/docker.sh"
# shellcheck source=lib/settings.sh
source "$OMAMAC_CHECKOUT/lib/settings.sh"
# shellcheck source=lib/dock.sh
source "$OMAMAC_CHECKOUT/lib/dock.sh"
# shellcheck source=lib/apply.sh
source "$OMAMAC_CHECKOUT/lib/apply.sh"

OMAMAC_STEP='starting'

install_failed() {
  # With set -E the trap also runs inside ( … ) and $( … ); let only the main shell speak.
  [ "$BASHPID" -eq "$$" ] || exit 1
  if ui_term; then
    ui_stopped "run the one-liner again; it picks up where it stopped"
    exit 1
  fi
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
  local ids=()
  mapfile -t ids < <(apps_chosen)
  if [ "${#ids[@]}" -gt 0 ]; then apps_ask_adopt "${ids[@]}"; fi
  if ui_term; then install_answers; else ask_summary; fi
  apps_password_ahead
  if ! ask_yes "Install?"; then
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
  if ui_term; then ui_row ok "Your answers" saved; else ui_ok "Your answers are saved"; fi
}

# install_answers: the terminal look's summary before "Install?": a sheet of
# every answer, labels as the questions showed them, a dash for none.
install_answers() {
  local key v rows=() words=() labels=()
  for key in "${QUESTION_KEYS[@]}"; do
    labels=()
    read -ra words <<< "${CHOICES[$key]:-}"
    for v in "${words[@]}"; do labels+=("$(question_label "$key" "$v")"); done
    rows+=("${QUESTION_TITLE[$key]}"$'\t'"$(clis_join "${labels[@]}")")
  done
  ui_heading "Your answers"
  ui_sheet_labels "${rows[@]}"
}

install_lines() {
  ui_stage "Startup files"
  OMAMAC_STEP='adding Homebrew to ~/.zprofile'
  lines_add "$HOME/.zprofile" "$OMAMAC_ZPROFILE_LINE" 'brew shellenv'
  ui_ok "Homebrew is on the PATH"
  OMAMAC_STEP='adding omamac to ~/.zshrc'
  lines_add "$HOME/.zshrc" "$OMAMAC_ZSHRC_LINE"
  ui_ok "omamac is loaded by zsh"
  OMAMAC_STEP="adding omamac's file to Ghostty's config"
  ghostty_line_add
  ui_ok "Ghostty starts herdr"
  # shellcheck disable=SC2088 # the ~ is shown, not expanded
  ui_stage_done "~/.zprofile, ~/.zshrc and Ghostty's config"
}

# install_done: the terminal look's summary. A green Done box (Installed,
# Ghostty, Next, Log), then a sheet of the permissions to allow, Ghostty first.
install_done() {
  local apps=() allow=() chosen=("the languages" "cloud CLIs" "coding agents") list line v rows=() perms=()
  mapfile -t apps < <(apps_chosen)
  [ "${#apps[@]}" -eq 0 ] || chosen+=(apps)
  [ "${CHOICES[docker]:-none}" = none ] || chosen+=(Docker)
  list=$(clis_join "${chosen[@]:0:${#chosen[@]}-1}")
  rows=(
    "Installed"$'\t'"Homebrew, bash, gum, omamac, Ghostty and the core tools, and $list and ${chosen[-1]} you chose."
    "Ghostty"$'\t'"omamac sets five Ghostty settings: its colours, command (starts herdr), macos-option-as-alt, Option ←/→, which go to herdr, and Cmd D, which does nothing: herdr splits with Alt n."
  )
  if [ "${#apps[@]}" -eq 0 ]; then
    rows+=("First open"$'\t'"macOS asks you to confirm Ghostty; click Open.")
  else
    rows+=("First open"$'\t'"macOS asks you to confirm Ghostty and each app; click Open.")
  fi
  [ "$SETTINGS_REFUSED" -ne 1 ] || rows+=("Reduce motion"$'\t'"turn it on: search for Reduce motion in System Settings.")
  [ "${#DOCKER_NOTES[@]}" -eq 0 ] || rows+=("Docker"$'\t'"${DOCKER_NOTES[*]}")
  rows+=("Next"$'\t'"Open Ghostty (it starts herdr), then run omamac." "Log"$'\t'"${OMAMAC_LOG/#"$HOME"/\~}")
  ui_titled ok Done "${rows[@]}"
  perms=("Ghostty"$'\t'"App Management, to let omamac update Ghostty: System Settings → Privacy & Security → App Management → Ghostty")
  if [ "${#apps[@]}" -gt 0 ]; then
    mapfile -t allow < <(apps_allow "${apps[@]}")
    # "Zoom: allow Camera and Microphone, …" becomes Zoom and "Camera and Microphone, …".
    for line in ${allow[@]+"${allow[@]}"}; do
      v=${line#*: }
      v=${v#allow }
      perms+=("${line%%: *}"$'\t'"${v^}")
    done
  fi
  ui_sheet $'App\tAllow, the first time it asks' "${perms[@]}"
}

install_summary() {
  if ui_term; then install_done; return; fi
  OMAMAC_STEP='printing the summary'
  # Short lines, so the box fits an 80-column terminal.
  local apps=() allow=() chosen=("the languages" "cloud CLIs" "coding agents") list
  mapfile -t apps < <(apps_chosen)
  [ "${#apps[@]}" -eq 0 ] || chosen+=(apps)
  [ "${CHOICES[docker]:-none}" = none ] || chosen+=(Docker)
  # "a, b and c": all but the last joined, then the last.
  list=$(clis_join "${chosen[@]:0:${#chosen[@]}-1}")
  local lines=(
    "Installed: Homebrew, bash, gum, omamac, Ghostty and the core tools,"
    "and $list and ${chosen[-1]} you chose."
    ""
    "omamac sets five Ghostty settings: its colours, command (starts"
    "herdr), macos-option-as-alt, Option ←/→, which go to herdr, and"
    "Cmd D, which does nothing: herdr splits with Alt n."
  )
  if [ "${#apps[@]}" -eq 0 ]; then
    lines+=("The first time you open Ghostty, macOS asks you to confirm;" "click Open.")
  else
    lines+=("The first time you open Ghostty and each app, macOS asks you" "to confirm; click Open.")
    mapfile -t allow < <(apps_allow "${apps[@]}")
    [ "${#allow[@]}" -eq 0 ] || lines+=("${allow[@]}")
  fi
  lines+=(
    "To let omamac update Ghostty: System Settings → Privacy & Security"
    "→ App Management → Ghostty."
    ""
  )
  if [ "$SETTINGS_REFUSED" -eq 1 ]; then
    lines+=("Turn on Reduce motion: search for Reduce motion in System Settings." "")
  fi
  if [ "${#DOCKER_NOTES[@]}" -gt 0 ]; then
    lines+=("${DOCKER_NOTES[@]}" "")
  fi
  lines+=("Log: $OMAMAC_LOG" "Open Ghostty (it starts herdr), then run omamac.")
  ui_box "${lines[@]}"
}

install_main() {
  install_questions
  # apply_all's stages, then the startup files'.
  if ui_term; then ui_stages $(($(apply_stage_count) + 1)); fi
  apply_all
  install_lines
  install_summary
}

install_main
