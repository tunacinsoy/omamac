load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
  FILE="$BATS_TEST_TMPDIR/choices.env"
  export FILE
}

# in_lib <code>: run bash 5 code with the question table and the choices helpers loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/questions.sh'
    source '$REPO_ROOT/lib/choices.sh'
    $1"
}

# load_file <content>: write it to FILE and load it.
load_file() {
  printf '%s' "$1" > "$FILE"
  in_lib 'choices_load "$FILE"'
}

# expect_bad <line number> <content>: loading fails, naming the line and the fix.
expect_bad() {
  load_file "$2"
  [ "$status" -eq 1 ]
  [[ "$output" == *"line $1:"* ]]
  [[ "$output" == *"Fix: delete that line"* ]]
}

@test "the table has the 16 keys in the vision's order" {
  in_lib 'echo "${QUESTION_KEYS[*]}"'
  [ "$output" = "theme apps_browsers apps_communication apps_media apps_screen_recording apps_storage apps_developer apps_productivity wispr_flow desktops window_margins dock dock_autohide languages cloud_clis docker" ]
}

@test "every key has a kind, a text and a title" {
  in_lib 'for k in "${QUESTION_KEYS[@]}"; do
      [ -n "${QUESTION_KIND[$k]}" ] && [ -n "${QUESTION_TEXT[$k]}" ] && [ -n "${QUESTION_TITLE[$k]}" ] || echo "bad $k"
    done'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Docker lists No Docker first" {
  in_lib 'question_values docker'
  [ "${lines[0]}" = none ]
  in_lib 'question_label docker none'
  [ "$output" = "No Docker" ]
}

@test "13 themes, 17 apps" {
  in_lib 'question_values theme | wc -l'
  [ "${output// /}" = 13 ]
  in_lib 'for k in "${QUESTION_KEYS[@]}"; do [[ $k == apps_* ]] && question_values "$k"; done | wc -l'
  [ "${output// /}" = 17 ]
}

@test "yes/no questions allow yes and no" {
  in_lib 'question_values dock'
  [ "$output" = "yes
no" ]
}

@test "a missing file has no answers" {
  in_lib 'choices_load "$FILE"; choices_missing | wc -l'
  [ "$status" -eq 0 ]
  [ "${output// /}" = 16 ]
}

@test "reads a full file" {
  in_lib 'choices_load "$REPO_ROOT/test/fixtures/bare.env"
    echo "${CHOICES[theme]}|${CHOICES[docker]}|${CHOICES[apps_media]}|${CHOICES[dock]}"
    choices_missing'
  [ "$status" -eq 0 ]
  [ "$output" = "tokyo-night|none||no" ]
}

@test "comments and blank lines are skipped" {
  load_file $'# a comment\n\ntheme=nord\n'
  [ "$status" -eq 0 ]
}

@test "the last line needs no newline" {
  printf 'theme=nord' > "$FILE"
  in_lib 'choices_load "$FILE"; echo "${CHOICES[theme]}"'
  [ "$output" = nord ]
}

@test "unknown key stops with the line number" {
  expect_bad 2 $'theme=nord\ncolour=red\n'
  [[ "$output" == *"$FILE"* ]]
}

@test "duplicate key stops" {
  expect_bad 2 $'theme=nord\ntheme=dracula\n'
}

@test "bad single value stops" {
  expect_bad 1 $'theme=neon\n'
}

@test "empty single or yes/no value stops" {
  expect_bad 1 $'theme=\n'
  expect_bad 1 $'dock=\n'
}

@test "bad yes/no value stops" {
  expect_bad 1 $'dock=maybe\n'
}

@test "unknown or duplicate multi value stops" {
  expect_bad 1 $'apps_browsers=brave opera\n'
  expect_bad 1 $'apps_browsers=brave brave\n'
}

@test "double or trailing spaces stop" {
  expect_bad 1 $'apps_browsers=brave  firefox\n'
  expect_bad 1 $'apps_browsers=brave \n'
}

@test "a line without = stops" {
  expect_bad 1 $'theme\n'
}

@test "carriage return stops, without the word Windows" {
  expect_bad 1 $'theme=nord\r\n'
  [[ "$output" == *"carriage return"* ]]
  [[ "$output" != *[Ww]indows* ]]
}

@test "a command in a value never runs" {
  # shellcheck disable=SC2016 # the file must hold the literal text
  expect_bad 1 'theme=$(touch '"$HOME"'/pwned)'
  [ ! -e "$HOME/pwned" ]
}

@test "a folder in place of the file stops" {
  mkdir "$FILE"
  in_lib 'choices_load "$FILE"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"$FILE"* ]]
}

@test "multi values are kept in table order" {
  printf 'apps_browsers=firefox brave\n' > "$FILE"
  in_lib 'choices_load "$FILE"; echo "${CHOICES[apps_browsers]}"'
  [ "$output" = "brave firefox" ]
}

@test "render puts keys in table order" {
  # bare.env reversed (header last) renders back to bare.env.
  tail -r "$REPO_ROOT/test/fixtures/bare.env" > "$FILE"
  in_lib 'choices_load "$FILE"; choices_render'
  [ "$output" = "$(cat "$REPO_ROOT/test/fixtures/bare.env")" ]
}

@test "save writes once, then leaves the file alone" {
  out="$HOME/.local/state/omamac/choices.env"
  in_lib "choices_load '$REPO_ROOT/test/fixtures/bare.env'; choices_save '$out'"
  [ "$status" -eq 0 ]
  cmp "$out" "$REPO_ROOT/test/fixtures/bare.env"
  before="$(shasum < "$out") $(stat -f %m "$out")"
  sleep 1.1
  in_lib "choices_load '$out'; choices_save '$out'"
  [ "$status" -eq 0 ]
  [ "$(shasum < "$out") $(stat -f %m "$out")" = "$before" ]
  [ "$(find "$HOME/.local/state/omamac" -type f | wc -l | tr -d ' ')" = 1 ]
}

@test "every fixture is valid and complete" {
  for f in "$REPO_ROOT"/test/fixtures/*.env; do
    in_lib "choices_load '$f' && choices_missing"
    [ "$status" -eq 0 ] || { echo "$f: $output"; return 1; }
    [ -z "$output" ] || { echo "$f is missing: $output"; return 1; }
  done
}
