# shellcheck shell=bash
# shellcheck disable=SC2034 # used by the scripts that source this file
# macOS App Management: Homebrew can only upgrade a cask app in /Applications
# when the terminal has this permission. Sourced; needs no other library.

APP_MANAGEMENT_URL='x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles'

# app_management_ok <app path>: 0 when this shell may change the app, 1 when macOS
# says "Operation not permitted" (prints nothing), 2 on any other failure (prints why).
# Writes and removes one file inside the app: the only way to ask, as there is no query API.
app_management_ok() {
  local probe="$1/.omamac-write-test" err
  if err=$(touch "$probe" 2>&1); then
    rm -f "$probe"
    return 0
  fi
  if [[ "$err" == *"Operation not permitted"* ]]; then return 1; fi
  printf '%s\n' "$err" >&2
  return 2
}
