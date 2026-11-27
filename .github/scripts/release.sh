# shellcheck shell=bash
# Releases from PR titles (Conventional Commits). Sourced by the pr-title and
# release workflows and by test/release.bats. Every merge to main is a release
# when its title says it changes what users get.

RELEASE_TYPES='feat|fix|perf|revert|docs|test|chore|ci|refactor|build|style'
RELEASE_HELP="A PR title starts with its type: feat: (new), fix:, perf:, revert: (a release), or docs:, test:, chore:, ci:, refactor:, build:, style: (no release). Example: feat: omamac font-size"

# release_bump <title>: prints major, minor, patch or none. A title without a
# known type prints RELEASE_HELP and returns 1.
release_bump() {
  local re="^(${RELEASE_TYPES})(\\([a-z0-9-]+\\))?(!)?: [^ ]"
  if ! [[ $1 =~ $re ]]; then
    echo "$RELEASE_HELP"
    return 1
  fi
  if [ -n "${BASH_REMATCH[3]}" ]; then echo major; return 0; fi
  case ${BASH_REMATCH[1]} in
    feat) echo minor ;;
    fix | perf | revert) echo patch ;;
    *) echo none ;;
  esac
}

# release_next <tag> <major|minor|patch>: the tag after <tag>. Before 1.0 a
# breaking change bumps the minor, as semantic versioning allows for 0.x.
release_next() {
  local re='^v([0-9]+)\.([0-9]+)\.([0-9]+)$' major minor patch
  [[ $1 =~ $re ]] || { echo "Not a vX.Y.Z tag: $1" >&2; return 1; }
  major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
  case $2 in
    major)
      if [ "$major" -eq 0 ]; then minor=$((minor + 1)) patch=0
      else major=$((major + 1)) minor=0 patch=0; fi
      ;;
    minor) minor=$((minor + 1)) patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) echo "Not a bump: $2" >&2; return 1 ;;
  esac
  echo "v$major.$minor.$patch"
}

# release_notes <number> <body>: the PR body's first paragraph, then (#number).
release_notes() {
  local line para=()
  while IFS= read -r line; do
    line=${line%$'\r'}
    if [ -z "$line" ]; then
      [ "${#para[@]}" -eq 0 ] || break
      continue
    fi
    para+=("$line")
  done <<< "$2"
  if [ "${#para[@]}" -gt 0 ]; then printf '%s\n' "${para[@]}"; echo; fi
  echo "(#$1)"
}
