# shellcheck shell=bash
# The languages, through mise. Sourced after lib/paths.sh, lib/ui.sh,
# lib/questions.sh and lib/choices.sh, before lib/apply.sh (it uses apply_put).
# omamac's drop-in names the chosen languages' tools at "latest". mise reads the
# user's ~/.config/mise/config.toml after it, so a pin there wins.

# Each language id's mise tools, space-separated.
declare -gA LANGUAGE_TOOLS=(
  [ruby]=ruby [node]=node [go]=go [python]=python [elixir]='erlang elixir' [rust]=rust [java]=java
)

# languages_mise <args…>: mise from HOME, so a project's mise.toml in the
# current folder is never installed or trusted. ui_run can't run a function,
# so its calls do the same cd themselves.
languages_mise() { (cd "$HOME" && "$OMAMAC_BREW_PREFIX/bin/mise" "$@"); }

# languages_render: the drop-in for CHOICES[languages].
languages_render() {
  local id tool ids=() tools=()
  read -ra ids <<< "${CHOICES[languages]:-}"
  echo '# Written by omamac from your answers; omamac rewrites it. Your own pins go in ~/.config/mise/config.toml.'
  echo '[tools]'
  for id in "${ids[@]}"; do
    read -ra tools <<< "${LANGUAGE_TOOLS[$id]}"
    for tool in "${tools[@]}"; do printf '%s = "latest"\n' "$tool"; done
  done
}

languages_write_dropin() {
  local dir tmp
  dir=$(dirname "$OMAMAC_MISE_DROPIN")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/omamac.toml.XXXXXX")
  languages_render > "$tmp"
  apply_put "$tmp" "$OMAMAC_MISE_DROPIN"
}

# languages_has <tool>: 0 if mise has a version installed, 1 if not, 2 if mise failed.
# mise's warnings go to the log, not between the spinners. doctor has no log.
languages_has() {
  local out
  out=$(languages_mise ls --installed --no-header "$1" 2>> "${OMAMAC_LOG:-/dev/null}") || return 2
  [ -n "$out" ]
}

# languages_install [<id>…]: the given languages, or the chosen ones. Only the
# tools mise lacks are installed, so a re-run never fetches a newer "latest";
# upgrading is omamac update's job.
languages_install() {
  local ids=("$@") id tool tools=() missing=() labels=() names status lacking
  [ "$#" -gt 0 ] || read -ra ids <<< "${CHOICES[languages]:-}"
  [ "${#ids[@]}" -gt 0 ] || return 0
  for id in "${ids[@]}"; do
    lacking=''
    read -ra tools <<< "${LANGUAGE_TOOLS[$id]}"
    for tool in "${tools[@]}"; do
      status=0
      languages_has "$tool" || status=$?
      [ "$status" -ne 2 ] || return 2
      [ "$status" -eq 0 ] || { missing+=("$tool"); lacking=1; }
    done
    [ -z "$lacking" ] || labels+=("$(question_label languages "$id")")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    names=$(IFS=,; echo "${labels[*]}")
    (cd "$HOME" && ui_run "Installing ${names//,/, }" "$OMAMAC_BREW_PREFIX/bin/mise" install "${missing[@]}") || return
  fi
  if [[ " ${ids[*]} " == *" ruby "* ]]; then languages_rails || return; fi
  ui_ok "Languages are installed"
}

# languages_rails: the rails gem under mise's Ruby, when it's missing.
languages_rails() {
  if languages_mise exec ruby -- gem list --installed --exact rails > /dev/null; then return 0; fi
  (cd "$HOME" && ui_run "Installing Rails" "$OMAMAC_BREW_PREFIX/bin/mise" exec ruby -- gem install rails --no-document)
}
