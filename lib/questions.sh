# shellcheck shell=bash
# shellcheck disable=SC2034 # read by the scripts that source this file
# The first-run questions, in the order they are asked: most visible first.
# Each key is one line in choices.env. Options are "Label:value"; the values
# are stable ids that later phases map to formulas, casks and mise names.

QUESTION_KEYS=()
declare -gA QUESTION_KIND=() QUESTION_TITLE=() QUESTION_TEXT=() QUESTION_OPTIONS=()

# question <key> <single|multi|yesno> <title for the summary> <text> [<Label:value>…]
question() {
  local key=$1
  QUESTION_KEYS+=("$key")
  QUESTION_KIND[$key]=$2
  QUESTION_TITLE[$key]=$3
  QUESTION_TEXT[$key]=$4
  shift 4
  QUESTION_OPTIONS[$key]=$(printf '%s\n' "$@")
}

question theme single Theme \
  "Pick a theme for the terminal, editor and prompt. omamac theme changes it later." \
  Catppuccin:catppuccin Dracula:dracula Everforest:everforest Gruvbox:gruvbox \
  Kanagawa:kanagawa "Matte Black:matte-black" Nord:nord "One Dark:one-dark" \
  "Osaka Jade:osaka-jade" Ristretto:ristretto "Rosé Pine:rose-pine" \
  Solarized:solarized "Tokyo Night:tokyo-night"
question apps_browsers multi Browsers Browsers Brave:brave Chrome:chrome Firefox:firefox
question apps_communication multi Communication Communication \
  WhatsApp:whatsapp Telegram:telegram Signal:signal Discord:discord Slack:slack Zoom:zoom
question apps_media multi Media Media Spotify:spotify VLC:vlc
question apps_screen_recording multi "Screen recording" "Screen recording" Cap:cap
question apps_storage multi "Storage and sync" "Storage and sync" Dropbox:dropbox "Google Drive:google-drive"
question apps_developer multi Developer Developer "VS Code:vscode"
question apps_productivity multi Productivity Productivity Raycast:raycast Obsidian:obsidian
question wispr_flow yesno "Wispr Flow" \
  "Install Wispr Flow for voice dictation? It turns speech into text in the cloud."
question desktops yesno "Desktops as workspaces" \
  "Make desktops behave like workspaces? They keep their order, switching to an app goes to its desktop, and Reduce motion turns on, which shortens animations everywhere."
question window_margins yesno "Window margins" "Add margins between tiled windows?"
question dock yesno "Dock cleanup" \
  "Clean up the Dock? Apple's apps and Downloads leave the Dock (not your Mac), and the apps omamac installs take their place."
question dock_autohide yesno "Dock auto-hide" "Hide the Dock when you're not using it?"
question languages multi Languages "Programming languages" \
  "Ruby on Rails:ruby" Node.js:node Go:go PHP:php Python:python Elixir:elixir Rust:rust Java:java
question cloud_clis multi "Cloud CLIs" "Cloud command-line tools" \
  "Azure CLI:azure" "AWS CLI:aws" "Google Cloud CLI:gcloud" "GitHub CLI:gh" Terraform:terraform
# "No Docker" comes first: Enter picks the option under the cursor, and Enter
# alone must never opt in to anything.
question docker single Docker "How should Docker run?" \
  "No Docker:none" colima:colima OrbStack:orbstack "Docker Desktop:docker-desktop"

# question_values <key>: the allowed answers, one per line.
question_values() {
  local option
  if [ "${QUESTION_KIND[$1]}" = yesno ]; then
    printf '%s\n' yes no
    return
  fi
  while IFS= read -r option; do echo "${option##*:}"; done <<< "${QUESTION_OPTIONS[$1]}"
}

# question_has <key> <value>: 0 if value is an allowed answer.
question_has() {
  local value
  while IFS= read -r value; do [ "$value" != "$2" ] || return 0; done < <(question_values "$1")
  return 1
}

# question_label <key> <value>: the label shown for a value.
question_label() {
  local option
  if [ "${QUESTION_KIND[$1]}" = yesno ]; then
    echo "$2"
    return
  fi
  while IFS= read -r option; do
    [ "${option##*:}" != "$2" ] || { echo "${option%:*}"; return; }
  done <<< "${QUESTION_OPTIONS[$1]}"
}
