# shellcheck shell=bash
# shellcheck disable=SC2088 # the ~ in messages is shown to the user, not expanded
# omamac doctor. Sourced after the libraries it checks. It reports, then offers
# fixes as questions: only for a chosen language, cloud CLI, coding agent, colima, Docker Desktop or app that is gone.

# The terminal look (#46) draws doctor as one sheet of every check, so the
# rows are kept and drawn at the end (doctor_draw); plain text prints each as
# it comes. DOCTOR_SECTION is the sheet's section a check's rows go to; the
# checks run in an order of their own, so herdr's row still lands in Terminal.
DOCTOR_SECTION=setup
DOCTOR_ROWS=() DOCTOR_FIX_CMDS=()
declare -A DOCTOR_FIX_WHAT=()

# What each check is, in plain words, for the sheet's Detail column when the
# check is fine (a ✗ or ℹ says its own). At most 45 columns, so the sheet
# fits 80. The macOS settings go by their question's title.
declare -A DOCTOR_ABOUT=(
  [Homebrew]="installs and updates the tools omamac sets up"
  ["bash 5"]="the shell omamac's scripts run in"
  [gum]="draws omamac's questions and boxes"
  [Checkout]="omamac itself, which omamac update refreshes"
  ["Checkout is clean"]="no edits there that would stop omamac update"
  ["Homebrew line"]="lets your shell find Homebrew's tools"
  ["omamac line"]="makes your shell load omamac's settings"
  ["omamac's zsh file"]="omamac's settings for your shell"
  ["Core tools"]="the editor, prompt and tools your shell uses"
  ["Saved answers"]="what you picked when omamac asked"
  ["mise drop-in"]="tells mise which languages you picked"
  [Ghostty]="the terminal app omamac sets up"
  ["Ghostty line"]="makes Ghostty load omamac's settings"
  ["omamac's Ghostty file"]="omamac's settings for Ghostty"
  ["App Management"]="lets omamac update keep Ghostty up to date"
  ["herdr config"]="omamac's keys and theme for herdr's panes"
  ["neovim config"]="the code editor's setup (LazyVim)"
  ["Theme files"]="your theme's colours for each tool"
  ["starship config"]="the prompt follows your theme"
  ["btop config"]="the system monitor follows your theme"
  ["Your tools"]="every language and CLI you picked is there"
  ["Your apps"]="every app you picked is in Applications"
  [docker-compose]="lets docker find its compose plugin"
  [docker-buildx]="lets docker find its build plugin"
  ["colima's service"]="starts colima, docker's engine, at login"
  ["Desktops as workspaces"]="desktops in order, Ctrl 1–6 to switch"
  ["Window margins"]="a gap between windows tiled side by side"
  ["Desktop widgets"]="widgets stay off the desktop"
  ["Dock cleanup"]="the Dock holds the apps omamac installed"
  ["Dock auto-hide"]="the Dock hides until you point at it"
)

# Your tools and apps, after the checks: one row per tool or app omamac
# installed, "group<TAB>name<TAB>version<TAB>newer". newer is "latest", the
# newer version that is out, or empty when it can't be known or isn't asked
# (apps update themselves). DOCTOR_UPDATES counts the newer versions.
DOCTOR_HAVE=() DOCTOR_UPDATES=0 DOCTOR_LIST_TOOLS=0 DOCTOR_LIST_APPS=0
# How long doctor waits for brew outdated and mise outdated, in seconds,
# counted from when they start (after the saved answers are read).
DOCTOR_WAIT=${OMAMAC_TEST_DOCTOR_WAIT:-10}
DOCTOR_LOOKUP_DIR='' DOCTOR_LOOKUP_START=0 DOCTOR_BREW_LISTED=0
declare -A DOCTOR_LOOKUP_PID=() DOCTOR_LOOKUP_OK=() DOCTOR_NEWER=() DOCTOR_BREW_VERSION=()

# doctor_fix <command> <what it does>: one line of the To fix box. Each
# command is said once, with all it fixes.
doctor_fix() {
  if [ -z "${DOCTOR_FIX_WHAT[$1]+set}" ]; then
    DOCTOR_FIX_CMDS+=("$1")
    DOCTOR_FIX_WHAT[$1]=$2
  else
    DOCTOR_FIX_WHAT[$1]+=", $2"
  fi
}

# doctor_report <ok|fail|info> <what> [<why>] [<fix>]. Returns 1 for fail so callers can count it.
doctor_report() {
  local kind=$1 what=$2 why=${3:-} fix=${4:-}
  if ui_term; then
    DOCTOR_ROWS+=("$DOCTOR_SECTION"$'\t'"$kind"$'\t'"$what"$'\t'"$why")
    [ "$kind" = fail ] || return 0
    # A gone pick has two ways out, each its own command.
    if [[ $fix =~ ^omamac\ update\ puts\ it\ back\;\ (omamac\ uninstall\ [^ ]+)\ drops\ it$ ]]; then
      doctor_fix "omamac update" "puts back $what"
      doctor_fix "${BASH_REMATCH[1]}" "drops $what from your answers"
    else
      doctor_fix "$fix" "fixes $what"
    fi
    return 1
  fi
  case "$kind" in
    ok) ui_ok "$what" ;;
    fail)
      ui_fail "$what — $why. Fix: $fix"
      return 1
      ;;
    info) ui_info "$what — $why" ;;
  esac
}

doctor_check_homebrew() {
  local what=Homebrew
  if [ -e "$OMAMAC_USR_LOCAL_BREW" ]; then
    doctor_report fail "$what" "Homebrew is also at /usr/local, which mixes two installs" \
      "see https://docs.brew.sh/Installation"
  elif [ ! -x "$OMAMAC_BREW_PREFIX/bin/brew" ]; then
    doctor_report fail "$what" "Homebrew is missing, and omamac installs everything with it" \
      "Run the one-liner"
  else
    doctor_report ok "$what"
  fi
}

doctor_check_bash() {
  local what="bash 5" major
  # shellcheck disable=SC2016 # the inner bash expands it
  major=$("$OMAMAC_BREW_PREFIX/bin/bash" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null) || major=0
  if [ "${major:-0}" -ge 5 ]; then
    doctor_report ok "$what"
  else
    doctor_report fail "$what" "omamac's scripts need bash 5, and macOS ships 3.2" "brew install bash"
  fi
}

doctor_check_gum() {
  if "$OMAMAC_BREW_PREFIX/bin/brew" list --formula gum >/dev/null 2>&1; then
    doctor_report ok gum
  else
    doctor_report fail gum "omamac draws its output with gum" "brew install gum"
  fi
}

# Sets DOCTOR_HAS_CHECKOUT so the clean check knows whether it can run.
doctor_check_checkout() {
  local what=Checkout origin=""
  DOCTOR_HAS_CHECKOUT=0
  if [ -e "$OMAMAC_HOME/.git" ]; then
    origin=$(git -C "$OMAMAC_HOME" remote get-url origin 2>/dev/null) || origin=""
  fi
  if [ "$origin" = "$OMAMAC_REPO_URL" ]; then
    DOCTOR_HAS_CHECKOUT=1
    doctor_report ok "$what"
  else
    doctor_report fail "$what" "~/.local/share/omamac is not a checkout of omamac" "Run the one-liner"
  fi
}

doctor_check_clean() {
  local what="Checkout is clean" changes
  if [ "$DOCTOR_HAS_CHECKOUT" -ne 1 ]; then
    doctor_report info "$what" "skipped, there is no checkout"
    return 0
  fi
  # No optional locks: a read-only check must not take git's index lock.
  # Untracked files (a .DS_Store) don't block update, so they don't count here either.
  changes=$(GIT_OPTIONAL_LOCKS=0 git -C "$OMAMAC_HOME" status --porcelain --untracked-files=no 2>/dev/null) || changes=unknown
  if [ -z "$changes" ]; then
    doctor_report ok "$what"
  else
    doctor_report fail "$what" "local edits would block omamac update" \
      "git -C ~/.local/share/omamac status, to see them"
  fi
}

# doctor_check_line <what> <file> <fixed string> <why>
doctor_check_line() {
  if lines_has "$2" "$3"; then
    doctor_report ok "$1"
  else
    doctor_report fail "$1" "$4" "Run the one-liner again"
  fi
}

doctor_check_zsh_file() {
  if [ -e "$OMAMAC_ZSH_FILE" ]; then
    doctor_report ok "omamac's zsh file"
  else
    doctor_report fail "omamac's zsh file" "~/.config/omamac/zshrc is missing" "Run the one-liner again"
  fi
}

doctor_check_core() {
  local what="Core tools" missing names
  # Homebrew's own ✗ is reported above; here a failed list only skips the check.
  if ! missing=$(core_missing 2>/dev/null); then
    doctor_report info "$what" "skipped, Homebrew can't list its formulas"
  elif [ -z "$missing" ]; then
    doctor_report ok "$what"
  else
    names=${missing//$'\n'/ }
    doctor_report fail "$what" "$names missing, and omamac's shell and editor need them" \
      "brew install $names"
  fi
}

doctor_check_neovim() {
  local what="neovim config"
  if [ -e "$OMAMAC_NVIM_MARKER" ]; then
    doctor_report ok "$what"
  elif [ -e "$OMAMAC_NVIM_DIR" ] || [ -L "$OMAMAC_NVIM_DIR" ]; then
    doctor_report info "$what" "your own neovim config is kept, so themes don't reach neovim"
  else
    doctor_report fail "$what" "~/.config/nvim is missing" "Run the one-liner again"
  fi
}

doctor_check_herdr() {
  local what="herdr config"
  if herdr_user_config; then
    doctor_report info "$what" "your own herdr config is kept, so omamac's key bindings and themes don't reach herdr"
  elif [ ! -e "$OMAMAC_HERDR_FILE" ]; then
    doctor_report fail "$what" "~/.config/omamac/herdr.toml is missing" "omamac update"
  else
    doctor_report ok "$what"
  fi
}

# doctor_check_theme_files: the files omamac theme writes, except the ones other checks name.
doctor_check_theme_files() {
  local f missing=()
  for f in "$OMAMAC_STARSHIP_FILE" "$OMAMAC_BTOP_FILE" "$OMAMAC_NEOVIM_THEME_FILE"; do
    [ -e "$f" ] || missing+=("${f#"$HOME"/}")
  done
  compgen -G "$OMAMAC_BTOP_THEMES/*.theme" >/dev/null || missing+=(".config/omamac/btop-themes")
  if [ "${#missing[@]}" -eq 0 ]; then
    doctor_report ok "Theme files"
  else
    doctor_report fail "Theme files" "${missing[*]} missing" "omamac update"
  fi
}

# doctor_check_vscode: a line only when VS Code is installed and something is
# off: the user's own theme (ℹ), or omamac's theme missing (✗). When all is
# well, "Theme files" covers it.
doctor_check_vscode() {
  [ -x "$(vscode_code)" ] || return 0
  if vscode_user_theme; then
    doctor_report info "VS Code theme" "your own VS Code theme is kept, so themes don't reach VS Code"
  elif ! vscode_has_theme; then
    doctor_report fail "VS Code theme" "VS Code doesn't have omamac's theme" "omamac update"
  fi
}

doctor_check_starship() {
  if theme_starship_user_config; then
    doctor_report info "starship config" "your own starship config is kept, so themes don't reach the prompt"
  else
    doctor_report ok "starship config"
  fi
}

doctor_check_btop() {
  if theme_btop_user_config; then
    doctor_report info "btop config" "your own btop config is kept, so themes don't reach btop"
  else
    doctor_report ok "btop config"
  fi
}

# Ghostty: the app, the include line in the user's files, omamac's own file,
# and App Management (only for a Ghostty Homebrew upgrades).
doctor_check_ghostty() {
  local what=Ghostty state fix app="$OMAMAC_APPLICATIONS/${CASK_APP[ghostty]}" status=0
  if ! state=$(core_cask_state ghostty 2>/dev/null); then
    doctor_report info "$what" "skipped, Homebrew can't list its casks"
    state=skipped
  else
    case $state in
      brew) doctor_report ok "$what" ;;
      hand) doctor_report info "$what" "installed by hand, so omamac won't update it. To let Homebrew take it over: brew install --cask --adopt ghostty" ;;
      missing)
        # Homebrew's install does nothing for a cask it already lists.
        if core_cask_listed ghostty; then fix="brew reinstall --cask ghostty"; else fix="brew install --cask ghostty"; fi
        doctor_report fail "$what" "omamac's terminal is Ghostty" "$fix" || status=1
        ;;
    esac
  fi
  if lines_has "$(ghostty_line_file)" "$OMAMAC_GHOSTTY_LINE"; then
    doctor_report ok "Ghostty line"
  else
    doctor_report fail "Ghostty line" "Ghostty's config doesn't load omamac's file" "Run the one-liner again" || status=1
  fi
  if [ -e "$OMAMAC_GHOSTTY_FILE" ]; then
    doctor_report ok "omamac's Ghostty file"
  else
    doctor_report fail "omamac's Ghostty file" "~/.config/omamac/ghostty.conf is missing" "omamac update" || status=1
  fi
  if [ "$state" = brew ]; then
    # Status 1 is a refusal, 2 is some other failure; only a refusal is known to be App Management.
    local am=0
    app_management_ok "$app" 2>/dev/null || am=$?
    case $am in
      0) doctor_report ok "App Management" ;;
      1) doctor_report info "App Management" "off, so omamac update can't upgrade Ghostty. Fix: System Settings → Privacy & Security → App Management, turn on your terminal" ;;
      *) doctor_report info "App Management" "skipped, omamac couldn't test it" ;;
    esac
  fi
  return "$status"
}

# doctor_unanswered_fix: the commands that ask the unanswered questions, the
# same ones update names. omamac install takes several names in one run.
doctor_unanswered_fix() {
  local key command names=() commands=()
  while IFS= read -r key; do
    command=$(add_command "$key") || { echo "Run the one-liner; it asks only those"; return 0; }
    case $command in
      "omamac install "*) [[ " ${names[*]} " == *" ${command#omamac install } "* ]] || names+=("${command#omamac install }") ;;
      *) commands+=("$command") ;;
    esac
  done < <(choices_missing)
  [ "${#names[@]}" -eq 0 ] || commands+=("omamac install ${names[*]}")
  local IFS=,
  command="${commands[*]}"
  echo "Run ${command//,/, then }"
}

# Sets DOCTOR_HAS_CHOICES so the checks after it know CHOICES is loaded.
doctor_check_choices() {
  local what="Saved answers" message
  DOCTOR_HAS_CHOICES=0
  if [ ! -e "$OMAMAC_CHOICES_FILE" ]; then
    doctor_report fail "$what" "omamac doesn't know your answers" "Run the one-liner"
  elif ! choices_load "$OMAMAC_CHOICES_FILE" 2>/dev/null; then
    # Load again for the message, "<problem>. Fix: <fix>", split into doctor's why and fix.
    message=$(choices_load "$OMAMAC_CHOICES_FILE" 2>&1) || true
    doctor_report fail "$what" "${message%%. Fix: *}" "${message#*. Fix: }"
  elif [ -n "$(choices_missing)" ]; then
    doctor_report fail "$what" "some questions have no answer yet" "$(doctor_unanswered_fix)"
  else
    DOCTOR_HAS_CHOICES=1
    doctor_report ok "$what"
  fi
}

doctor_check_mise_dropin() {
  local what="mise drop-in"
  if [ "$DOCTOR_HAS_CHOICES" -ne 1 ]; then
    doctor_report info "$what" "skipped, your saved answers can't be read"
  elif [ -f "$OMAMAC_MISE_DROPIN" ] && cmp -s "$OMAMAC_MISE_DROPIN" <(languages_render); then
    doctor_report ok "$what"
  else
    doctor_report fail "$what" "~/.config/mise/conf.d/omamac.toml doesn't match your answers" "omamac update"
  fi
}

# One line per yes answer of the macOS settings: the values omamac set are still there.
doctor_check_settings() {
  local what="macOS settings" answer title unmet status=0
  if [ "$DOCTOR_HAS_CHOICES" -ne 1 ]; then
    doctor_report info "$what" "skipped, your saved answers can't be read"
    return 0
  fi
  for answer in desktops window_margins desktop_widgets dock dock_autohide; do
    [ "${CHOICES[$answer]:-}" = yes ] || continue
    title=${QUESTION_TITLE[$answer]}
    # Without the record, update never cleaned the Dock, so there is nothing to check.
    if [ "$answer" = dock ] && [ ! -f "$OMAMAC_DOCK_RECORD" ]; then
      doctor_report fail "$title" "omamac hasn't cleaned the Dock" "omamac update" || status=1
      continue
    fi
    settings_check "$answer"
    if [ "${#SETTINGS_UNMET[@]}" -gt 0 ]; then
      # Names joined with ", ".
      unmet=$(IFS=,; echo "${SETTINGS_UNMET[*]}")
      doctor_report fail "$title" "${unmet//,/, } was changed since omamac set it" "omamac update" || status=1
    elif [ "$SETTINGS_REFUSED" -eq 1 ]; then
      doctor_report info "$title" "macOS doesn't let omamac read Reduce motion; to check it, search for Reduce motion in System Settings"
    else
      doctor_report ok "$title"
    fi
  done
  return "$status"
}

# doctor_key <id>: the question a gone id answers.
doctor_key() {
  if [ "$1" = colima ] || [ "$1" = docker-desktop ]; then
    echo docker
  elif [ -n "${LANGUAGE_TOOLS[$1]:-}" ]; then
    echo languages
  elif apps_key "$1" 2>/dev/null; then
    :
  else
    clis_key "$1"
  fi
}

# doctor_label <id>: the name shown for a gone id, app or not.
doctor_label() {
  local key
  key=$(doctor_key "$1")
  case $key in
    apps_* | wispr_flow) apps_label "$1" ;;
    *) question_label "$key" "$1" ;;
  esac
}

# Sets DOCTOR_GONE to the chosen language and CLI ids that are gone, and
# colima or docker-desktop when any of its parts is, for doctor_offer.
doctor_check_chosen() {
  local what="Your tools" id tool status=0 out key why result=0 state formulas=() tools=() langs=() clis=() skipped=() docker_gone=
  DOCTOR_GONE=()
  if [ "$DOCTOR_HAS_CHOICES" -ne 1 ]; then
    doctor_report info "$what" "skipped, your saved answers can't be read"
    return 0
  fi
  read -ra langs <<< "${CHOICES[languages]:-}"
  mapfile -t clis < <(clis_chosen)
  # A language is gone when any of its tools is. A missing or failing mise
  # skips them all; the core check names a missing mise.
  for id in "${langs[@]}"; do
    read -ra tools <<< "${LANGUAGE_TOOLS[$id]}"
    for tool in "${tools[@]}"; do
      status=0
      languages_has "$tool" 2>/dev/null || status=$?
      if [ "$status" -ne 0 ]; then break; fi
    done
    case $status in
      1) DOCTOR_GONE+=("$id") ;;
      2)
        DOCTOR_GONE=()
        skipped+=(mise)
        break
        ;;
    esac
  done
  if [ "${#clis[@]}" -gt 0 ]; then
    if out=$(clis_where missing "${clis[@]}" 2>/dev/null); then
      [ -z "$out" ] || mapfile -t -O "${#DOCTOR_GONE[@]}" DOCTOR_GONE <<< "$out"
    else
      skipped+=(Homebrew)
    fi
  fi
  # colima and Docker Desktop are one entry each, however many of their parts are gone.
  case ${CHOICES[docker]:-none} in
    colima)
      mapfile -t tools < <(docker_formulas colima)
      if out=$(core_where missing "${tools[@]}" 2>/dev/null); then
        if [ -n "$out" ]; then
          mapfile -t tools <<< "$out"
          docker_gone=$(clis_join "${tools[@]}")
          DOCTOR_GONE+=(colima)
        fi
      elif [[ " ${skipped[*]} " != *" Homebrew "* ]]; then
        skipped+=(Homebrew)
      fi
      ;;
    docker-desktop)
      tools=()
      mapfile -t formulas < <(docker_formulas docker-desktop)
      if state=$(core_cask_state docker-desktop 2>/dev/null) && out=$(core_where missing "${formulas[@]}" 2>/dev/null); then
        [ "$state" != missing ] || tools+=("Docker Desktop")
        [ -z "$out" ] || { mapfile -t formulas <<< "$out"; tools+=("${formulas[@]}"); }
        if [ "${#tools[@]}" -gt 0 ]; then
          docker_gone=$(clis_join "${tools[@]}")
          DOCTOR_GONE+=(docker-desktop)
        fi
      elif [[ " ${skipped[*]} " != *" Homebrew "* ]]; then
        skipped+=(Homebrew)
      fi
      ;;
  esac
  for tool in "${skipped[@]}"; do
    doctor_report info "$what" "skipped, $tool can't list what's installed"
  done
  for id in "${DOCTOR_GONE[@]}"; do
    key=$(doctor_key "$id") tool=Homebrew why=it
    [ "$key" != languages ] || tool=mise
    [ "$key" != docker ] || why=$docker_gone
    doctor_report fail "$(question_label "$key" "$id")" "you chose it, but $tool no longer has $why" \
      "omamac update puts it back; omamac uninstall $id drops it" || result=1
  done
  if [ "${#skipped[@]}" -eq 0 ] && [ "$result" -eq 0 ]; then doctor_report ok "$what"; fi
  [ "${#skipped[@]}" -gt 0 ] || DOCTOR_LIST_TOOLS=1
  return "$result"
}

# doctor_check_apps: "Your apps". Appends the chosen apps that are gone to DOCTOR_GONE,
# after the tools'. Says nothing when no app is chosen.
doctor_check_apps() {
  local what="Your apps" id label state result=0 ids=()
  if [ "$DOCTOR_HAS_CHOICES" -ne 1 ]; then
    doctor_report info "$what" "skipped, your saved answers can't be read"
    return 0
  fi
  mapfile -t ids < <(apps_chosen)
  [ "${#ids[@]}" -gt 0 ] || return 0
  for id in "${ids[@]}"; do
    if ! state=$(core_cask_state "${APP_CASK[$id]}" 2>/dev/null); then
      doctor_report info "$what" "skipped, Homebrew can't list what's installed"
      return "$result"
    fi
    label=$(apps_label "$id")
    case $state in
      missing)
        DOCTOR_GONE+=("$id")
        doctor_report fail "$label" "you chose it, but it's gone from Applications" \
          "omamac update puts it back; omamac uninstall $id drops it" || result=1
        ;;
      hand)
        # Password apps can't be adopted, so they get no command.
        if [ "${APP_PASSWORD[$id]}" = yes ]; then
          doctor_report info "$label" "installed by hand, so omamac won't update it"
        else
          doctor_report info "$label" "installed by hand, so omamac won't update it. To let Homebrew take it over: brew install --cask --adopt ${APP_CASK[$id]}"
        fi
        ;;
    esac
  done
  if [ "$result" -eq 0 ]; then doctor_report ok "$what"; fi
  DOCTOR_LIST_APPS=1
  return "$result"
}

# doctor_offer: for each gone choice, ask what to do, when a terminal is there.
# A failed reinstall is said and the next one is asked; the report's status stays doctor's.
doctor_offer() {
  local id key label logged=0
  if [ "${#DOCTOR_GONE[@]}" -eq 0 ] || ! ask_has_tty; then return 0; fi
  for id in "${DOCTOR_GONE[@]}"; do
    key=$(doctor_key "$id")
    label=$(doctor_label "$id")
    if [ "$key" = docker ]; then
      # No drop here: dropping colima also removes it, which is omamac uninstall colima.
      ask_choose "$label is gone. What should omamac do?" "Leave it:leave" "Reinstall it:reinstall"
    else
      ask_choose "$label is gone. What should omamac do?" \
        "Leave it:leave" "Reinstall it:reinstall" "Remove it from my answers:drop"
    fi
    case $ASK_PICKED in
      reinstall)
        [ "$logged" -eq 1 ] || { log_start; logged=1; }
        case $key in
          languages) languages_install "$id" || doctor_reinstall_failed "$label" ;;
          # Docker Desktop's cask is the password step's.
          docker)
            if [ "$id" = docker-desktop ]; then
              apps_install_password docker-desktop && docker_install
            else
              docker_install
            fi || doctor_reinstall_failed "$label"
            ;;
          apps_* | wispr_flow)
            # A password app's cask is the password step's, run in the open.
            if [ "${APP_PASSWORD[$id]}" = yes ]; then
              apps_install_password "$id"
            else
              apps_install "$id"
            fi || doctor_reinstall_failed "$label"
            ;;
          *) clis_install "$id" || doctor_reinstall_failed "$label" ;;
        esac
        ;;
      drop)
        case $key in
          apps_* | wispr_flow) apps_drop "$id" ;;
          *) choices_drop "$key" "$id" ;;
        esac
        choices_save "$OMAMAC_CHOICES_FILE"
        [ "$key" != languages ] || languages_write_dropin
        ui_ok "$label is dropped from your answers"
        ;;
    esac
  done
}

# doctor_offer_neovim: a neovim config that isn't omamac's can be moved aside, so omamac sets up its own.
# One mv, so nothing is lost; the marker is only ever written by neovim_setup into a new folder.
doctor_offer_neovim() {
  local backup
  if [ -e "$OMAMAC_NVIM_MARKER" ] || { [ ! -e "$OMAMAC_NVIM_DIR" ] && [ ! -L "$OMAMAC_NVIM_DIR" ]; } || ! ask_has_tty; then
    return 0
  fi
  ask_choose "Move your neovim config aside so omamac can set up its own?" "Leave it:leave" "Move it aside:move"
  [ "$ASK_PICKED" = move ] || return 0
  backup=$OMAMAC_NVIM_DIR.bak-$(date +%Y%m%d)
  [ ! -e "$backup" ] && [ ! -L "$backup" ] || backup=$backup-$(date +%H%M%S)
  if ! mv "$OMAMAC_NVIM_DIR" "$backup"; then
    ui_fail "omamac couldn't move ~/.config/nvim aside. Nothing was changed."
    return 0
  fi
  ui_ok "Your neovim config is now ${backup/#"$HOME"/\~}"
  log_start
  if ! neovim_setup; then
    ui_fail "omamac couldn't fetch LazyVim. Your config is safe at ${backup/#"$HOME"/\~}. Run the one-liner again to set up omamac's."
    return 1
  fi
}

# --- Your tools and apps: versions, and whether a newer one is out.

# doctor_lookups_start: brew outdated and mise outdated, in the background
# while the other checks run, each into a file of its own, once per run. Not
# into a pipe: a lookup cut short must not hold doctor's output open.
# HOMEBREW_NO_AUTO_UPDATE: doctor never updates Homebrew.
doctor_lookups_start() {
  local dir brew=$OMAMAC_BREW_PREFIX/bin/brew mise=$OMAMAC_BREW_PREFIX/bin/mise
  dir=$(mktemp -d "${TMPDIR:-/tmp}/omamac-doctor.XXXXXX" 2>/dev/null) || return 0
  DOCTOR_LOOKUP_DIR=$dir DOCTOR_LOOKUP_START=$SECONDS
  if [ -n "${CHOICES[languages]:-}" ] && [ -x "$mise" ]; then
    (cd "$HOME" && exec "$mise" outdated --json) > "$dir/mise" 2>/dev/null < /dev/null &
    DOCTOR_LOOKUP_PID[mise]=$!
  fi
  if [ -x "$brew" ] && { [ -n "${CHOICES[cloud_clis]:-}${CHOICES[coding_agents]:-}" ] || [ "${CHOICES[docker]:-none}" != none ]; }; then
    HOMEBREW_NO_AUTO_UPDATE=1 "$brew" outdated --greedy --json=v2 > "$dir/brew" 2>/dev/null < /dev/null &
    DOCTOR_LOOKUP_PID[brew]=$!
  fi
}

# doctor_lookups_wait: wait for the lookups, DOCTOR_WAIT seconds at most from
# their start, then read what each found into DOCTOR_NEWER ("mise:<tool>" or
# "brew:<name>" → the newer version). A lookup that failed, timed out or
# printed something unreadable stays out of DOCTOR_LOOKUP_OK, and its rows
# show only the version. Never fails.
doctor_lookups_wait() {
  local dir=$DOCTOR_LOOKUP_DIR source pid running name current latest out
  [ -n "$dir" ] || return 0
  DOCTOR_LOOKUP_DIR=''
  while :; do
    running=0
    for pid in "${DOCTOR_LOOKUP_PID[@]}"; do ! kill -0 "$pid" 2>/dev/null || running=1; done
    [ "$running" -eq 1 ] && [ $((SECONDS - DOCTOR_LOOKUP_START)) -lt "$DOCTOR_WAIT" ] || break
    sleep 0.1
  done
  for source in "${!DOCTOR_LOOKUP_PID[@]}"; do
    pid=${DOCTOR_LOOKUP_PID[$source]}
    if kill -0 "$pid" 2>/dev/null; then
      # Too slow: stopped, and its rows show only the version.
      kill -KILL "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      continue
    fi
    wait "$pid" 2>/dev/null || true
    [ -s "$dir/$source" ] || continue
    if [ "$source" = mise ]; then
      # An object by tool name; a list in older mise versions.
      out=$(jq -r 'if type == "object" then to_entries | map(.value + {key}) elif type == "array" then . else error end
        | .[] | "\(.name // .key)\t\(.current // "")\t\(.latest // "")"' "$dir/mise" 2>/dev/null) || continue
    else
      # Pinned formulas stay where they are, as omamac update leaves them.
      out=$(jq -r 'if has("formulae") then . else error end
        | (.formulae[] | select(.pinned | not)), .casks[]
        | "\(.name)\t\(.installed_versions[-1] // "")\t\(.current_version // "")"' "$dir/brew" 2>/dev/null) || continue
    fi
    DOCTOR_LOOKUP_OK[$source]=1
    while IFS=$'\t' read -r name current latest; do
      [ -n "$name" ] && [ -n "$latest" ] || continue
      latest=$(doctor_version "$latest") current=$(doctor_version "$current")
      [ "$latest" = "$current" ] || DOCTOR_NEWER[$source:${name##*/}]=$latest
    done <<< "$out"
  done
  rm -rf "$dir"
}

# doctor_version <version>: as shown. Homebrew's ",<build>" (casks) and
# "_<revision>" (formulas) are left out.
doctor_version() {
  local v=${1%%,*}
  [[ ! $v =~ ^(.+)_[0-9]+$ ]] || v=${BASH_REMATCH[1]}
  echo "$v"
}

# doctor_brew_version <name>: the version Homebrew has of a formula (any tap)
# or cask; empty when it can't say. One brew list each per run.
doctor_brew_version() {
  local name versions
  if [ "$DOCTOR_BREW_LISTED" -eq 0 ]; then
    DOCTOR_BREW_LISTED=1
    while read -r name versions; do
      [ -z "$name" ] || DOCTOR_BREW_VERSION[$name]=${versions##* }
    done < <("$OMAMAC_BREW_PREFIX/bin/brew" list --formula --versions 2>/dev/null
      "$OMAMAC_BREW_PREFIX/bin/brew" list --cask --versions 2>/dev/null)
  fi
  name=${1##*/}
  [ -z "${DOCTOR_BREW_VERSION[$name]:-}" ] || doctor_version "${DOCTOR_BREW_VERSION[$name]}"
}

# doctor_mise_version <tool>: the newest version mise has installed; empty
# when it can't say.
doctor_mise_version() {
  local line version=''
  while read -r _ line _; do
    [ -z "$line" ] || version=$line
  done < <(languages_mise ls --installed --no-header "$1" 2>/dev/null)
  echo "$version"
}

# doctor_app_version <bundle>: the version the app itself reports, from its
# Info.plist in Applications; empty when it has none.
doctor_app_version() {
  plutil -extract CFBundleShortVersionString raw -o - \
    "$OMAMAC_APPLICATIONS/$1/Contents/Info.plist" 2>/dev/null || true
}

# doctor_have_row <group> <name> <version> [<mise|brew> <name>]: a row of Your
# tools and apps. With a lookup that worked, its newer column: latest, or
# the version that is out.
doctor_have_row() {
  local newer=''
  if [ -n "${4:-}" ] && [ -n "$3" ] && [ -n "${DOCTOR_LOOKUP_OK[$4]:-}" ]; then
    newer=${DOCTOR_NEWER[$4:${5##*/}]:-latest}
    [ "$newer" = latest ] || DOCTOR_UPDATES=$((DOCTOR_UPDATES + 1))
  fi
  DOCTOR_HAVE+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"$newer")
}

# doctor_gone <id>: a pick doctor found gone; its ✗ names it, so it isn't listed.
doctor_gone() { [[ " ${DOCTOR_GONE[*]} " == *" $1 "* ]]; }

# doctor_have: DOCTOR_HAVE, by kind: Languages (mise), Cloud CLIs, Coding
# agents and Docker (Homebrew), then Apps in the catalog's order.
doctor_have() {
  local id key tool name ids=() tools=()
  doctor_lookups_wait
  if [ "$DOCTOR_LIST_TOOLS" -eq 1 ]; then
    read -ra ids <<< "${CHOICES[languages]:-}"
    for id in "${ids[@]}"; do
      ! doctor_gone "$id" || continue
      # A language's version is its last tool's: Elixir's, not Erlang's.
      read -ra tools <<< "${LANGUAGE_TOOLS[$id]}"
      tool=${tools[${#tools[@]} - 1]}
      doctor_have_row "${QUESTION_TITLE[languages]}" "$(question_label languages "$id")" \
        "$(doctor_mise_version "$tool")" mise "$tool"
    done
    for key in "${CLI_KEYS[@]}"; do
      read -ra ids <<< "${CHOICES[$key]:-}"
      for id in "${ids[@]}"; do
        ! doctor_gone "$id" || continue
        name=${CLI_FORMULA[$id]:-${CLI_CASK[$id]:-}}
        doctor_have_row "${QUESTION_TITLE[$key]}" "$(question_label "$key" "$id")" \
          "$(doctor_brew_version "$name")" brew "$name"
      done
    done
    id=${CHOICES[docker]:-none}
    if [ "$id" != none ] && ! doctor_gone "$id"; then
      # Docker Desktop is an app, and updates itself.
      if [ "$id" = docker-desktop ]; then
        doctor_have_row "${QUESTION_TITLE[docker]}" "$(question_label docker "$id")" \
          "$(doctor_app_version "${CASK_APP[docker-desktop]}")"
      fi
      while IFS= read -r name; do
        doctor_have_row "${QUESTION_TITLE[docker]}" "$name" "$(doctor_brew_version "$name")" brew "$name"
      done < <(docker_formulas "$id")
    fi
  fi
  if [ "$DOCTOR_LIST_APPS" -eq 1 ]; then
    while IFS= read -r id; do
      ! doctor_gone "$id" || continue
      doctor_have_row Apps "$(apps_label "$id")" "$(doctor_app_version "${APP_BUNDLE[$id]}")"
    done < <(apps_chosen)
  fi
}

# doctor_have_plain: Your tools and apps in plain text, after the checks: a
# line per group, then one per tool or app ("    Go 1.25.0 (latest)"), and
# how many updates wait.
doctor_have_plain() {
  local row group name version newer last='' line s=s
  for row in "${DOCTOR_HAVE[@]}"; do
    IFS=$'\t' read -r group name version newer <<< "$row"
    [ "$group" = "$last" ] || { printf '%s\n' "$group"; last=$group; }
    line="    $name${version:+ $version}"
    case $newer in
      '') ;;
      latest) line+=" (latest)" ;;
      *) line+=" ($newer is out)" ;;
    esac
    printf '%s\n' "$line"
  done
  [ "$DOCTOR_UPDATES" -ne 1 ] || s=''
  [ "$DOCTOR_UPDATES" -eq 0 ] || ui_info "$DOCTOR_UPDATES update$s waiting: omamac update"
}

# doctor_have_draw: Your tools and apps in the terminal look: one sheet, a
# bold row per group, then each name, its version, and a dim "latest" or a
# yellow "<version> is out". No newer column when no row has one.
doctor_have_draw() {
  local row group name version newer last='' rows=() wide=0
  [ "${#DOCTOR_HAVE[@]}" -gt 0 ] || return 0
  for row in "${DOCTOR_HAVE[@]}"; do [ -z "${row##*$'\t'}" ] || wide=1; done
  for row in "${DOCTOR_HAVE[@]}"; do
    IFS=$'\t' read -r group name version newer <<< "$row"
    if [ "$group" != "$last" ]; then
      rows+=("{bold}$group"$'\t')
      last=$group
    fi
    [ -n "$version" ] || version='{dim}—'
    row="$name"$'\t'"$version"
    if [ "$wide" -eq 1 ]; then
      case $newer in
        '') row+=$'\t' ;;
        latest) row+=$'\t'"{dim}latest" ;;
        *) row+=$'\t'"{yellow}$newer is out" ;;
      esac
    fi
    rows+=("$row")
  done
  ui_heading "Your tools and apps"
  ui_sheet '' "${rows[@]}"
}

# doctor_draw: the terminal look's report. A sheet of every check (mark,
# Check, Detail) in sections, a fine check's Detail saying what it is; the
# count line; a yellow To fix box with each command once; Your tools and apps.
doctor_draw() {
  local section title row kind what why rows=() cmd fixes=() problems=0 notes=0 fine=0
  local -A titles=([setup]=Setup [terminal]=Terminal [theme]=Theme [picks]="Your tools and apps" [macos]=macOS)
  # The theme's name joins its section, once the answers can be read.
  if [ "${DOCTOR_HAS_CHOICES:-0}" -eq 1 ] && [ -n "${CHOICES[theme]:-}" ]; then
    titles[theme]="${UI_BOLD}Theme$UI_OFF $UI_DIM· $(question_label theme "${CHOICES[theme]}")$UI_OFF"
  else
    titles[theme]="${UI_BOLD}Theme$UI_OFF"
  fi
  for section in setup terminal theme picks macos; do
    title=${titles[$section]}
    [[ $title == *$'\e'* ]] || title="{bold}$title"
    for row in "${DOCTOR_ROWS[@]}"; do
      [ "${row%%$'\t'*}" = "$section" ] || continue
      [ -z "$title" ] || { rows+=($'\t'"$title"$'\t'); title=''; }
      IFS=$'\t' read -r _ kind what why <<< "$row"
      case $kind in
        ok) rows+=("{ok}✓"$'\t'"$what"$'\t'"{dim}${why:-${DOCTOR_ABOUT[$what]:-}}"); fine=$((fine + 1)) ;;
        fail) rows+=("{fail}✗"$'\t'"$what"$'\t'"{red}$why"); problems=$((problems + 1)) ;;
        *) rows+=("{info}ℹ"$'\t'"$what"$'\t'"{dim}$why"); notes=$((notes + 1)) ;;
      esac
    done
  done
  ui_sheet $'\tCheck\tDetail' "${rows[@]}"
  ui_count "$problems" "$notes" "$fine" "$DOCTOR_UPDATES"
  if [ "${#DOCTOR_FIX_CMDS[@]}" -gt 0 ]; then
    for cmd in "${DOCTOR_FIX_CMDS[@]}"; do fixes+=("$cmd"$'\t'"${DOCTOR_FIX_WHAT[$cmd]}"); done
    ui_titled -c warn "To fix" "${fixes[@]}"
  fi
  doctor_have_draw
}

# doctor_reinstall_failed <label>: a Reinstall offer failed. The terminal look
# has no Stopped box here (doctor goes on), so the log is named on a row.
doctor_reinstall_failed() {
  ui_fail "omamac couldn't reinstall $1."
  ! ui_term || ui_row info Log "${OMAMAC_LOG/#"$HOME"/\~}"
}

# Prints one line per check; returns 1 if any is a ✗.
doctor_run() {
  local status=0
  DOCTOR_SECTION=setup
  doctor_check_homebrew || status=1
  doctor_check_bash || status=1
  doctor_check_gum || status=1
  doctor_check_checkout || status=1
  doctor_check_clean || status=1
  doctor_check_line "Homebrew line" "$HOME/.zprofile" "brew shellenv" \
    "~/.zprofile does not put Homebrew on PATH" || status=1
  doctor_check_line "omamac line" "$HOME/.zshrc" "$OMAMAC_ZSHRC_LINE" \
    "~/.zshrc does not load omamac's settings" || status=1
  doctor_check_zsh_file || status=1
  doctor_check_core || status=1
  DOCTOR_SECTION=terminal
  doctor_check_ghostty || status=1
  DOCTOR_SECTION=theme
  doctor_check_neovim || status=1
  doctor_check_theme_files || status=1
  doctor_check_starship || status=1
  doctor_check_btop || status=1
  DOCTOR_SECTION=terminal
  doctor_check_herdr || status=1
  DOCTOR_SECTION=setup
  doctor_check_choices || status=1
  [ "$DOCTOR_HAS_CHOICES" -ne 1 ] || doctor_lookups_start
  doctor_check_mise_dropin || status=1
  DOCTOR_SECTION=picks
  doctor_check_chosen || status=1
  doctor_check_apps || status=1
  if [ "$DOCTOR_HAS_CHOICES" -eq 1 ]; then docker_check || status=1; fi
  DOCTOR_SECTION=theme
  if [ "$DOCTOR_HAS_CHOICES" -eq 1 ]; then doctor_check_vscode || status=1; fi
  DOCTOR_SECTION=macos
  doctor_check_settings || status=1
  # Never a ✗: a lookup that fails only leaves its column out.
  [ "$DOCTOR_HAS_CHOICES" -ne 1 ] || doctor_have || true
  if ui_term; then doctor_draw; else doctor_have_plain; fi
  doctor_offer
  doctor_offer_neovim || status=1
  return "$status"
}
