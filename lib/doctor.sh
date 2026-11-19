# shellcheck shell=bash
# shellcheck disable=SC2088 # the ~ in messages is shown to the user, not expanded
# omamac doctor. Sourced after the libraries it checks. It reports, then offers
# fixes as questions: only for a chosen language, cloud CLI, colima or Docker Desktop that is gone.

# doctor_report <ok|fail|info> <what> [<why>] [<fix>]. Returns 1 for fail so callers can count it.
doctor_report() {
  local kind=$1 what=$2 why=${3:-} fix=${4:-}
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
      hand) doctor_report info "$what" "installed by hand, so omamac won't update it" ;;
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
    doctor_report fail "$what" "a question has no answer yet" "Run the one-liner; it asks only that one"
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
  for answer in desktops window_margins; do
    [ "${CHOICES[$answer]:-}" = yes ] || continue
    title=${QUESTION_TITLE[$answer]}
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
  else
    echo cloud_clis
  fi
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
  read -ra clis <<< "${CHOICES[cloud_clis]:-}"
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
  return "$result"
}

# doctor_offer: for each gone choice, ask what to do, when a terminal is there.
# A failed reinstall is said and the next one is asked; the report's status stays doctor's.
doctor_offer() {
  local id key label logged=0
  if [ "${#DOCTOR_GONE[@]}" -eq 0 ] || ! ask_has_tty; then return 0; fi
  for id in "${DOCTOR_GONE[@]}"; do
    key=$(doctor_key "$id")
    label=$(question_label "$key" "$id")
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
          languages) languages_install "$id" || ui_fail "omamac couldn't reinstall $label." ;;
          # Docker Desktop's cask is the password step's.
          docker)
            if [ "$id" = docker-desktop ]; then
              apps_install_password docker-desktop && docker_install
            else
              docker_install
            fi || ui_fail "omamac couldn't reinstall $label."
            ;;
          *) clis_install "$id" || ui_fail "omamac couldn't reinstall $label." ;;
        esac
        ;;
      drop)
        choices_drop "$key" "$id"
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

# Prints one line per check; returns 1 if any is a ✗.
doctor_run() {
  local status=0
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
  doctor_check_ghostty || status=1
  doctor_check_neovim || status=1
  doctor_check_theme_files || status=1
  doctor_check_starship || status=1
  doctor_check_btop || status=1
  doctor_check_herdr || status=1
  doctor_check_choices || status=1
  doctor_check_mise_dropin || status=1
  doctor_check_chosen || status=1
  if [ "$DOCTOR_HAS_CHOICES" -eq 1 ]; then docker_check || status=1; fi
  doctor_check_settings || status=1
  doctor_offer
  doctor_offer_neovim || status=1
  return "$status"
}
