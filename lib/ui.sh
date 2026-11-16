# shellcheck shell=bash
# Output helpers. Sourced. Plain text stays readable when gum adds no styling.

OMAMAC_LOG=${OMAMAC_LOG:-/dev/null}

ui_step() { gum style --bold "$*"; }
ui_ok() { gum style "✓ $*"; }
ui_fail() { gum style "✗ $*" >&2; }
ui_info() { gum style "ℹ $*"; }
ui_box() { gum style --border=rounded --padding="0 2" "$@"; }

# ui_run <title> <cmd…>: run under a spinner, keep all output in the log.
ui_run() {
  local title=$1 status=0
  shift
  # The inner bash writes the log itself: gum spin captures output on its own.
  # shellcheck disable=SC2016 # the inner bash expands these
  gum spin --title "$title" -- bash -c '"$@" >>"$0" 2>&1' "$OMAMAC_LOG" "$@" || status=$?
  if [ "$status" -ne 0 ]; then
    tail -n 20 "$OMAMAC_LOG" >&2 || true
    ui_fail "Log: $OMAMAC_LOG"
  fi
  return "$status"
}
