# shellcheck shell=bash
# Output helpers. Sourced after lib/paths.sh. Plain text stays readable when gum adds no styling.

OMAMAC_LOG=${OMAMAC_LOG:-/dev/null}
# gum by its full path: doctor must still report when Homebrew isn't on PATH.
UI_GUM=${OMAMAC_BREW_PREFIX:?lib/ui.sh needs lib/paths.sh first}/bin/gum

# Each helper falls back to plain text with the same markers when gum is missing,
# so doctor can still say what's wrong.
ui_has_gum() { [ -x "$UI_GUM" ]; }
ui_step() { if ui_has_gum; then "$UI_GUM" style --bold "$*"; else printf '%s\n' "$*"; fi; }
ui_ok() { if ui_has_gum; then "$UI_GUM" style "✓ $*"; else printf '✓ %s\n' "$*"; fi; }
ui_fail() { if ui_has_gum; then "$UI_GUM" style "✗ $*" >&2; else printf '✗ %s\n' "$*" >&2; fi; }
ui_info() { if ui_has_gum; then "$UI_GUM" style "ℹ $*"; else printf 'ℹ %s\n' "$*"; fi; }
ui_box() { if ui_has_gum; then "$UI_GUM" style --border=rounded --padding="0 2" "$@"; else printf '%s\n' "$@"; fi; }

# ui_run <title> <cmd…>: run under a spinner, keep all output in the log.
ui_run() {
  local title=$1 status=0
  shift
  if ui_has_gum; then
    # The inner bash writes the log itself: gum spin captures output on its own.
    # shellcheck disable=SC2016 # the inner bash expands these
    "$UI_GUM" spin --title "$title" -- bash -c '"$@" >>"$0" 2>&1' "$OMAMAC_LOG" "$@" || status=$?
  else
    printf '%s\n' "$title"
    "$@" >>"$OMAMAC_LOG" 2>&1 || status=$?
  fi
  if [ "$status" -ne 0 ]; then
    tail -n 20 "$OMAMAC_LOG" >&2 || true
    ui_fail "Log: $OMAMAC_LOG"
  fi
  return "$status"
}
