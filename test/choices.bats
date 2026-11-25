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
  [[ "$output" == *"Fix: Delete that line"* ]]
}

@test "the table has the 21 keys in the vision's order" {
  in_lib 'echo "${QUESTION_KEYS[*]}"'
  [ "$output" = "theme apps_browsers apps_communication apps_media apps_screen_recording apps_storage apps_developer apps_ai apps_productivity wispr_flow desktops window_margins desktop_widgets dock dock_autohide tap_to_click three_finger_drag languages cloud_clis coding_agents docker" ]
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

@test "13 themes, 21 apps" {
  in_lib 'question_values theme | wc -l'
  [ "${output// /}" = 13 ]
  in_lib 'for k in "${QUESTION_KEYS[@]}"; do [[ $k == apps_* ]] && question_values "$k"; done | wc -l'
  [ "${output// /}" = 21 ]
}

@test "languages has no php" {
  in_lib 'echo $(question_values languages)'
  [ "$output" = "ruby node go python elixir rust java" ]
  expect_bad 1 $'languages=php\n'
}

@test "yes/no questions allow yes and no" {
  in_lib 'question_values dock'
  [ "$output" = "yes
no" ]
}

@test "a missing file has no answers" {
  in_lib 'choices_load "$FILE"; choices_missing | wc -l'
  [ "$status" -eq 0 ]
  [ "${output// /}" = 21 ]
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

@test "choices_add keeps table order and skips repeats" {
  in_lib 'CHOICES[languages]="node rust"
    choices_add languages java go node
    echo "${CHOICES[languages]}"'
  [ "$status" -eq 0 ]
  [ "$output" = "node go rust java" ]
}

@test "choices_drop of the last id leaves an empty answer" {
  in_lib 'CHOICES[cloud_clis]="aws gh"
    choices_drop cloud_clis aws
    echo "1=${CHOICES[cloud_clis]}"
    choices_drop cloud_clis gh
    echo "2=${CHOICES[cloud_clis]+set}=${CHOICES[cloud_clis]}"
    choices_render'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1=gh" ]
  [ "${lines[1]}" = "2=set=" ]
  grep -qx "cloud_clis=" <<< "$output"
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

@test "prompts fit an 80-column terminal" {
  # gum cuts a prompt off at the terminal's edge instead of wrapping it.
  in_lib 'for k in "${QUESTION_KEYS[@]}"; do
      t=${QUESTION_TEXT[$k]}; [ "${#t}" -le 76 ] || echo "$k: ${#t}"
    done'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the vision's disclosures are in the help lines" {
  in_lib 'echo "${QUESTION_HELP[desktops]}|${QUESTION_HELP[wispr_flow]}"'
  [[ "$output" == *"Reduce motion"*"shortens animations everywhere"* ]]
  [[ "$output" == *"in the cloud"* ]]
}
