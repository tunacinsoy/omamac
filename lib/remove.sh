# shellcheck shell=bash
# shellcheck disable=SC2034 # OMAMAC_STEP is read by bin/omamac's ERR trap
# omamac uninstall: remove one language or cloud CLI. Sourced after lib/ask.sh,
# lib/log.sh, lib/core.sh, lib/languages.sh and lib/clis.sh.

# The questions whose picks omamac uninstall can remove.
REMOVE_KEYS=(languages cloud_clis)

# remove_run [<name>]: CHOICES is loaded (bin/omamac did that). Nothing is
# changed before "Remove?" is yes, and the choice is saved last, so a failure
# leaves it saved for doctor to report.
remove_run() {
  local name=${1:-} key='' k v label status tool joined list ids=() options=() tools=() all=()
  OMAMAC_STEP='checking what to remove'
  if [ "$#" -eq 0 ]; then
    for k in "${REMOVE_KEYS[@]}"; do
      read -ra ids <<< "${CHOICES[$k]:-}"
      for v in "${ids[@]}"; do options+=("$(question_label "$k" "$v"):$v"); done
    done
    if [ "${#options[@]}" -eq 0 ]; then
      ui_info "omamac installed no languages or cloud CLIs, so there's nothing to remove."
      exit 0
    fi
    ask_choose "What should omamac remove?" "Nothing:none" "${options[@]}"
    [ "$ASK_PICKED" != none ] || exit 0
    name=$ASK_PICKED
  fi
  # bash and gum are omamac's own, so they count as core.
  for v in "${CORE_FORMULAS[@]}" "${CORE_CASKS[@]}" bash gum zsh; do
    if [ "$name" = "$v" ]; then
      ui_fail "$name is part of omamac's core and can't be removed on its own."
      exit 1
    fi
  done
  for k in "${REMOVE_KEYS[@]}"; do
    if question_has "$k" "$name"; then key=$k; fi
    mapfile -t ids < <(question_values "$k")
    all+=("${ids[@]}")
  done
  if [ -z "$key" ]; then
    ui_fail "omamac can't remove '$name'. It can remove: $(clis_join "${all[@]}")."
    exit 2
  fi
  label=$(question_label "$key" "$name")
  if [[ " ${CHOICES[$key]:-} " != *" $name "* ]]; then
    ui_info "$label isn't installed by omamac."
    exit 0
  fi
  if [ "$key" = languages ]; then
    read -ra tools <<< "${LANGUAGE_TOOLS[$name]}"
    printf -v joined '%s and ' "${tools[@]}"
    ui_box "$label: mise's ${joined% and }"
  else
    ui_box "$label: $(clis_what "$name")"
  fi
  if ! ask_yes "Remove $label?"; then
    ui_info "Nothing was removed."
    exit 0
  fi
  log_start
  choices_drop "$key" "$name"
  if [ "$key" = languages ]; then
    OMAMAC_STEP='writing ~/.config/mise/conf.d/omamac.toml'
    languages_write_dropin
    OMAMAC_STEP="removing $label"
    # MISE_YES: prune asks before it deletes; "Remove?" was the question.
    (cd "$HOME" && MISE_YES=1 ui_run "Removing $label" "$OMAMAC_BREW_PREFIX/bin/mise" prune --tools "${tools[@]}") || return
    OMAMAC_STEP='checking what mise kept'
    for tool in "${tools[@]}"; do
      status=0
      languages_has "$tool" || status=$?
      [ "$status" -ne 2 ] || return 2
      [ "$status" -ne 0 ] || ui_info "mise kept $tool: another of your mise configs uses it."
    done
  else
    OMAMAC_STEP="removing $label"
    # A CLI removed by hand needs no brew call.
    list=$(clis_where installed "$name") || return
    if [ -n "$list" ]; then
      if [ -n "${CLI_FORMULA[$name]:-}" ]; then
        ui_run "Removing $label" "$OMAMAC_BREW_PREFIX/bin/brew" uninstall "${CLI_FORMULA[$name]}"
      else
        ui_run "Removing $label" "$OMAMAC_BREW_PREFIX/bin/brew" uninstall --cask "${CLI_CASK[$name]}"
      fi
    fi
  fi
  OMAMAC_STEP='saving your answers'
  choices_save "$OMAMAC_CHOICES_FILE"
  ui_ok "$label is removed"
}
