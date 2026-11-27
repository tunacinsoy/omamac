load helpers/common

# in_release <code>: run bash 5 code with .github/scripts/release.sh loaded.
in_release() {
  run "$BASH5" -c "set -Eeuo pipefail
    source '$REPO_ROOT/.github/scripts/release.sh'
    $1"
}

@test "feat bumps the minor, fix the patch" {
  in_release 'release_bump "feat: omamac font-size"'
  [ "$output" = minor ]
  in_release 'release_bump "fix: download progress on upgrade rows"'
  [ "$output" = patch ]
  in_release 'release_bump "perf: faster doctor"'
  [ "$output" = patch ]
  in_release 'release_bump "revert: feat: omamac font-size"'
  [ "$output" = patch ]
}

@test "a scope and a breaking mark are read" {
  in_release 'release_bump "feat(ghostty): font size"'
  [ "$output" = minor ]
  in_release 'release_bump "feat!: configure replaces install for settings"'
  [ "$output" = major ]
  in_release 'release_bump "fix(update)!: new saved-answers format"'
  [ "$output" = major ]
}

@test "docs, test, chore, ci, refactor, build and style make no release" {
  local t
  for t in docs test chore ci refactor build style; do
    in_release "release_bump '$t: something'"
    [ "$status" -eq 0 ]
    [ "$output" = none ]
  done
}

@test "a title without a known type is refused" {
  local t
  for t in 'Font size' 'feature: font size' 'feat:font size' 'feat: ' 'Feat: font size' 'feat font size' ''; do
    in_release "release_bump '$t'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"feat: "* ]]
  done
}

@test "next version: before 1.0 a breaking change bumps the minor" {
  in_release 'release_next v0.3.0 minor'
  [ "$output" = v0.4.0 ]
  in_release 'release_next v0.4.0 patch'
  [ "$output" = v0.4.1 ]
  in_release 'release_next v0.4.1 major'
  [ "$output" = v0.5.0 ]
  in_release 'release_next v0.9.3 minor'
  [ "$output" = v0.10.0 ]
}

@test "next version: from 1.0 a breaking change bumps the major" {
  in_release 'release_next v1.2.3 major'
  [ "$output" = v2.0.0 ]
  in_release 'release_next v1.2.3 minor'
  [ "$output" = v1.3.0 ]
}

@test "next version refuses a tag that isn't vX.Y.Z" {
  in_release 'release_next 0.3.0 minor'
  [ "$status" -eq 1 ]
  in_release 'release_next v0.3 minor'
  [ "$status" -eq 1 ]
}

@test "notes: the first paragraph of the PR body, then the PR number" {
  in_release 'release_notes 66 "For a screen that wants bigger text, omamac font-size picks the size.
It shows at once.

- detail one
- detail two

🤖 Generated with [Claude Code](https://claude.com/claude-code)"'
  [ "$output" = "For a screen that wants bigger text, omamac font-size picks the size.
It shows at once.

(#66)" ]
}

@test "notes: an empty body still names the PR" {
  in_release 'release_notes 70 ""'
  [ "$output" = "(#70)" ]
  in_release "release_notes 71 \$'\\n\\n'"
  [ "$output" = "(#71)" ]
}

@test "notes: a body with Windows line ends" {
  in_release "release_notes 72 \$'First line.\\r\\n\\r\\nMore.'"
  [ "$output" = "First line.

(#72)" ]
}

@test "notes: headings are skipped, the first paragraph of text is used" {
  in_release 'release_notes 65 "## Why

omamac update felt slow when casks were outdated.

## What"'
  [ "$output" = "omamac update felt slow when casks were outdated.

(#65)" ]
}
