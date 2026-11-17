# shellcheck shell=bash
# The cloud CLIs, through Homebrew. Sourced after lib/paths.sh, lib/ui.sh and
# lib/questions.sh, before lib/apply.sh.

# Each CLI id's Homebrew formula (full name) or cask.
declare -gA CLI_FORMULA=([azure]=azure-cli [aws]=awscli [gh]=gh [terraform]=hashicorp/tap/terraform)
declare -gA CLI_CASK=([gcloud]=gcloud-cli)

# clis_where <installed|missing> <id>…: the ids in that state, one per line, in
# the given order. One brew list for the formulas and one for the casks.
# Full names, so homebrew/core's old terraform isn't hashicorp/tap/terraform.
# Returns non-zero if Homebrew can't list.
clis_where() {
  local want=$1 formulas casks id name
  local -A have=()
  shift
  formulas=$("$OMAMAC_BREW_PREFIX/bin/brew" list --formula --full-name -1) || return
  casks=$("$OMAMAC_BREW_PREFIX/bin/brew" list --cask -1) || return
  while IFS= read -r name; do
    [ -z "$name" ] || have[f:$name]=1
  done <<< "$formulas"
  while IFS= read -r name; do
    [ -z "$name" ] || have[c:$name]=1
  done <<< "$casks"
  for id in "$@"; do
    if [ -n "${CLI_FORMULA[$id]:-}" ]; then name=f:${CLI_FORMULA[$id]}; else name=c:${CLI_CASK[$id]}; fi
    if [ -n "${have[$name]:-}" ]; then
      [ "$want" != installed ] || echo "$id"
    else
      [ "$want" != missing ] || echo "$id"
    fi
  done
}

# clis_what <id>: what Homebrew calls it, for messages.
clis_what() {
  if [ -n "${CLI_FORMULA[$1]:-}" ]; then echo "${CLI_FORMULA[$1]}"; else echo "the ${CLI_CASK[$1]} cask"; fi
}

# clis_join <label>…: "A, B".
clis_join() { local IFS=,; local out="$*"; echo "${out//,/, }"; }

# clis_install [<id>…]: the given CLIs, or the chosen ones. Only what's missing
# is installed: formulas in one brew call, casks in another.
clis_install() {
  local ids=("$@") list taps id missing=() formulas=() casks=() flabels=() clabels=() brew
  brew="$OMAMAC_BREW_PREFIX/bin/brew"
  [ "$#" -gt 0 ] || read -ra ids <<< "${CHOICES[cloud_clis]:-}"
  [ "${#ids[@]}" -gt 0 ] || return 0
  # Not mapfile < <(…): that would hide a failed brew list and install nothing.
  list=$(clis_where missing "${ids[@]}") || return
  [ -z "$list" ] || mapfile -t missing <<< "$list"
  for id in "${missing[@]}"; do
    if [ -n "${CLI_FORMULA[$id]:-}" ]; then
      formulas+=("${CLI_FORMULA[$id]}"); flabels+=("$(question_label cloud_clis "$id")")
    else
      casks+=("${CLI_CASK[$id]}"); clabels+=("$(question_label cloud_clis "$id")")
    fi
  done
  if [[ " ${missing[*]} " == *" terraform "* ]]; then
    # Read the list first: in a pipe a failing brew, or grep -q closing early, reads as "not tapped".
    taps=$("$brew" tap) || return
  fi
  if [[ " ${missing[*]} " == *" terraform "* && $'\n'$taps$'\n' != *$'\nhashicorp/tap\n'* ]]; then
    ui_run "Adding the HashiCorp tap" "$brew" tap hashicorp/tap || return
  fi
  if [ "${#formulas[@]}" -gt 0 ]; then
    ui_run "Installing $(clis_join "${flabels[@]}")" "$brew" install "${formulas[@]}" || return
  fi
  if [ "${#casks[@]}" -gt 0 ]; then
    ui_run "Installing $(clis_join "${clabels[@]}")" "$brew" install --cask "${casks[@]}" || return
  fi
  ui_ok "Cloud CLIs are installed"
}
