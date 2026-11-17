# shellcheck shell=bash
# The saved answers in choices.env. Sourced after lib/questions.sh.
# The file is read as data, line by line, and checked against the question
# table. It is never sourced: a value like $(…) must not run.

declare -gA CHOICES=()
CHOICES_HEADER="# omamac's saved answers. omamac reads this file as data; it is never run."

# choices_normalise <key> <value>: prints the value as saved (multi in table
# order); returns 1 if it isn't a valid answer.
choices_normalise() {
  local key=$1 value=$2 word v out=() words=()
  local -A picked=()
  case ${QUESTION_KIND[$key]} in
    single | yesno)
      [ -n "$value" ] && question_has "$key" "$value" && echo "$value"
      ;;
    multi)
      # One space between ids, none at the ends, so no empty id can slip in.
      [[ $value =~ ^([a-z0-9-]+( [a-z0-9-]+)*)?$ ]] || return 1
      read -ra words <<< "$value"
      for word in "${words[@]}"; do
        question_has "$key" "$word" && [ -z "${picked[$word]:-}" ] || return 1
        picked[$word]=1
      done
      while IFS= read -r v; do [ -z "${picked[$v]:-}" ] || out+=("$v"); done < <(question_values "$key")
      echo "${out[*]}"
      ;;
  esac
}

# choices_load <file>: fill CHOICES from the file. A missing file means no
# answers. On a bad line, says which and how to fix it, and returns 1.
choices_load() {
  local file=$1 line key value normal problem n=0
  local shown=${file/#"$HOME"/\~}
  CHOICES=()
  [ -e "$file" ] || return 0
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "omamac can't read $shown. Fix: move it aside and run the one-liner again." >&2
    return 1
  fi
  # The || keeps a last line that has no newline.
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    [[ -z $line || $line == \#* ]] && continue
    problem=''
    if [[ $line == *$'\r'* ]]; then
      problem='it ends in a carriage return'
    elif [[ ! $line =~ ^([a-z_]+)=([a-z0-9\ -]*)$ ]]; then
      problem="it isn't one key=value of lowercase letters, digits and dashes"
    else
      key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
      if [ -z "${QUESTION_KIND[$key]:-}" ]; then
        problem="omamac has no question '$key'"
      elif [ -n "${CHOICES[$key]+set}" ]; then
        problem="'$key' is there twice"
      elif ! normal=$(choices_normalise "$key" "$value"); then
        problem="'$value' isn't an answer to '$key'"
      else
        CHOICES[$key]=$normal
      fi
    fi
    if [ -n "$problem" ]; then
      echo "$shown, line $n: $problem. Fix: Delete that line, then run the one-liner again." >&2
      return 1
    fi
  done < "$file"
}

# choices_missing: the keys with no answer yet, in table order.
choices_missing() {
  local key
  for key in "${QUESTION_KEYS[@]}"; do
    [ -n "${CHOICES[$key]+set}" ] || echo "$key"
  done
}

# choices_add <key> <id>…: add the ids to a multi answer, in table order;
# repeats are skipped. Returns 1 if an id isn't an answer to key.
choices_add() {
  local key=$1 v normal words=() all=()
  local -A seen=()
  shift
  read -ra words <<< "${CHOICES[$key]:-}"
  for v in "${words[@]}" "$@"; do
    [ -n "${seen[$v]:-}" ] || all+=("$v")
    seen[$v]=1
  done
  normal=$(choices_normalise "$key" "${all[*]}") || return 1
  CHOICES[$key]=$normal
}

# choices_drop <key> <id>: take the id out of a multi answer. Dropping the
# last one leaves an empty answer, not a missing one.
choices_drop() {
  local key=$1 v words=() kept=()
  read -ra words <<< "${CHOICES[$key]:-}"
  for v in "${words[@]}"; do [ "$v" = "$2" ] || kept+=("$v"); done
  CHOICES[$key]=${kept[*]}
}

# choices_render: the file's text, every answer in table order.
choices_render() {
  local key
  echo "$CHOICES_HEADER"
  for key in "${QUESTION_KEYS[@]}"; do
    [ -z "${CHOICES[$key]+set}" ] || printf '%s=%s\n' "$key" "${CHOICES[$key]}"
  done
}

# choices_save <file>: write the answers; leave the file (and its mtime) alone
# when nothing changed, so a re-run changes nothing.
choices_save() {
  local file=$1 dir tmp
  dir=$(dirname -- "$file")
  mkdir -p -- "$dir"
  tmp=$(mktemp "$dir/choices.XXXXXX")
  choices_render > "$tmp" || { rm -f -- "$tmp"; return 1; }
  if cmp -s "$tmp" "$file"; then
    rm -f -- "$tmp"
  else
    mv -- "$tmp" "$file"
  fi
}
