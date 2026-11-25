# shellcheck shell=bash
# shellcheck disable=SC2034 # read by the scripts that source this file
# The first-run questions, in the order they are asked: most visible first.
# Each key is one line in choices.env. Options are "Label:value"; the values
# are stable ids that later phases map to formulas, casks and mise names.

QUESTION_KEYS=()
declare -gA QUESTION_KIND=() QUESTION_TITLE=() QUESTION_TEXT=() QUESTION_OPTIONS=() QUESTION_HELP=()

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

# question_help <key> <text>: a line printed before the question. gum cuts a prompt off
# at the terminal's edge, so prompts stay short and the explanation goes here,
# where the terminal wraps it.
question_help() { QUESTION_HELP[$1]=$2; }

question theme single Theme "Pick a theme for the terminal, editor and prompt." \
  Catppuccin:catppuccin Dracula:dracula Everforest:everforest Gruvbox:gruvbox \
  Kanagawa:kanagawa "Matte Black:matte-black" Nord:nord "One Dark:one-dark" \
  "Osaka Jade:osaka-jade" Ristretto:ristretto "Rosé Pine:rose-pine" \
  Solarized:solarized "Tokyo Night:tokyo-night"
question_help theme "You can change it later with omamac theme."
question apps_browsers multi Browsers Browsers Brave:brave Chrome:chrome Firefox:firefox
question apps_communication multi Communication Communication \
  WhatsApp:whatsapp Telegram:telegram Signal:signal Discord:discord Slack:slack Zoom:zoom
question apps_media multi Media Media Spotify:spotify VLC:vlc
question apps_screen_recording multi "Screen recording" "Screen recording" Cap:cap
question apps_storage multi "Storage and sync" "Storage and sync" Dropbox:dropbox "Google Drive:google-drive"
question apps_developer multi Developer Developer "VS Code:vscode"
question apps_ai multi "AI apps" "AI desktop apps" \
  Claude:claude "ChatGPT and Codex:chatgpt" "GitHub Copilot:copilot" Antigravity:antigravity
question_help apps_ai "These are desktop apps. ChatGPT's includes Codex. The terminal tools come later, under Coding agents."
question apps_productivity multi Productivity Productivity Raycast:raycast Obsidian:obsidian
question wispr_flow yesno "Wispr Flow" "Install Wispr Flow for voice dictation?"
question_help wispr_flow "Wispr Flow turns your speech into text in the cloud."
question desktops yesno "Desktops as workspaces" "Make desktops behave like workspaces?"
question_help desktops "Desktops keep their order, switching to an app goes to its desktop, Ctrl 1–6 jump to desktops 1 to 6, and Reduce motion turns on, which shortens animations everywhere."
question window_margins yesno "Window margins" "Add margins between tiled windows?"
question desktop_widgets yesno "Desktop widgets" "Hide widgets on the desktop?"
question_help desktop_widgets "The Weather and other widgets a new Mac shows leave the desktop and Stage Manager."
question dock yesno "Dock cleanup" "Clean up the Dock?"
question_help dock "Apple's apps and Downloads leave the Dock (not your Mac), and the apps omamac installs take their place."
question dock_autohide yesno "Dock auto-hide" "Hide the Dock when you're not using it?"
question tap_to_click yesno "Tap to click" "Click with a tap on the trackpad?"
question_help tap_to_click "A light tap clicks, as on a phone, so you don't have to press the trackpad down."
question three_finger_drag yesno "Three-finger drag" "Drag with three fingers on the trackpad?"
question_help three_finger_drag "Move three fingers to drag a window or select text, without pressing down. Swiping between desktops and to Mission Control moves to four fingers, as macOS does when you turn it on."
question languages multi Languages "Programming languages" \
  "Ruby on Rails:ruby" Node.js:node Go:go Python:python Elixir:elixir Rust:rust Java:java
question cloud_clis multi "Cloud CLIs" "Cloud command-line tools" \
  "Azure CLI:azure" "AWS CLI:aws" "Google Cloud CLI:gcloud" "GitHub CLI:gh" Terraform:terraform
question coding_agents multi "Coding agents" "Coding agents for the terminal" \
  "Claude Code CLI:claude-code" "Codex CLI:codex" "Copilot CLI:copilot-cli" \
  "Antigravity CLI:antigravity-cli" "opencode CLI:opencode"
question_help coding_agents "They run in the terminal, in herdr. Each asks you to sign in the first time."
# "No Docker" comes first: Enter picks the option under the cursor, and Enter
# alone must never opt in to anything.
question docker single Docker "How should Docker run?" \
  "No Docker:none" colima:colima "Docker Desktop:docker-desktop"
question_help docker "colima runs Docker in the background from the command line. Docker Desktop is an app; larger companies need a paid plan for it."

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
  local value values
  # Read every value first: returning mid-read would leave question_values
  # writing into a closed pipe, which prints an error where SIGPIPE is ignored (CI).
  mapfile -t values < <(question_values "$1")
  for value in "${values[@]}"; do [ "$value" != "$2" ] || return 0; done
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
