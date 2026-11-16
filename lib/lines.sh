# shellcheck shell=bash
# Add one line to a user file without touching anything else. Sourced.

# lines_has <file> <fixed_string>: 0 if any line contains it; 1 otherwise or if the file is missing.
lines_has() {
  [ -f "$1" ] && grep -qF -- "$2" "$1"
}

# lines_add <file> <line> [<present_pattern>]
lines_add() {
  local file=$1 line=$2 pattern=${3:-$2}
  lines_has "$file" "$pattern" && return 0

  # A missing file needs a writable folder (the nearest one that exists); an existing file must be writable.
  local target=$file reason=''
  if [ -e "$file" ]; then
    [ -w "$file" ] || reason='the file is not writable'
  else
    target=$(dirname -- "$file")
    while [ ! -e "$target" ]; do target=$(dirname -- "$target"); done
    [ -w "$target" ] || reason='the folder is not writable'
  fi
  # chown follows a link and could change a file other tools own (a dotfile
  # manager, a read-only store), so for a link name its target and stop there.
  if [ -n "$reason" ] && [ -L "$file" ]; then
    echo "omamac can't write $file: it links to $(readlink -f -- "$file"), which is not writable. Fix: add this line there yourself: $line" >&2
    return 1
  elif [ -n "$reason" ]; then
    echo "omamac can't write $file: $reason. Fix: sudo chown \"\$USER\" \"$target\" && chmod u+w \"$target\"" >&2
    return 1
  fi

  mkdir -p -- "$(dirname -- "$file")"
  # >> through a symlink appends to its target, so links stay links.
  if [ -s "$file" ] && [ -n "$(tail -c1 -- "$file")" ]; then
    printf '\n' >> "$file"
  fi
  printf '%s\n' "$line" >> "$file"
}
