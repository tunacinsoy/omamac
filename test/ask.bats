load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
}

# in_ask <code>: run bash 5 code with everything lib/ask.sh needs loaded.
in_ask() {
  run "$BASH5" -c "set -Eeuo pipefail
    for f in paths ui questions choices ask; do source '$REPO_ROOT/lib/'\$f.sh; done
    $1"
}

# The prompts fake-gum saw, one per line.
prompts() { grep -E '^gum (choose|confirm)' "$STUB_LOG" || true; }

@test "fresh: all 16 asked in table order, nothing pre-selected" {
  gum_answers "${FRESH_ANSWERS[@]}"
  in_ask 'ask_missing
    for k in "${QUESTION_KEYS[@]}"; do echo "TEXT ${QUESTION_TEXT[$k]}"; done'
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 16 ]
  i=0
  while IFS= read -r text; do
    i=$((i + 1))
    [[ "$(prompts | sed -n "${i}p")" == *"${text#TEXT }"* ]] || { echo "prompt $i isn't: $text"; return 1; }
  done < <(printf '%s\n' "${lines[@]}" | grep '^TEXT ')
  ! grep -q -- '--selected' "$STUB_LOG"
  [ "$(grep -c '^gum confirm' "$STUB_LOG")" = 5 ]
  [ "$(grep -c '^gum confirm --default=false ' "$STUB_LOG")" = 5 ]
}

@test "multi uses --no-limit, single does not" {
  gum_answers "${FRESH_ANSWERS[@]}"
  in_ask 'ask_missing'
  [ "$status" -eq 0 ]
  [[ "$(prompts | sed -n 1p)" != *--no-limit* ]]
  [[ "$(prompts | sed -n 2p)" == *"--no-limit"* ]]
  [[ "$(prompts | sed -n 16p)" != *--no-limit* ]]
  [[ "$(prompts | sed -n 16p)" == *"--label-delimiter=: No Docker:none colima:colima"* ]]
}

@test "answers land in CHOICES, multi in table order" {
  gum_answers "${FRESH_ANSWERS[@]}"
  in_ask 'ask_missing; choices_render'
  [ "$status" -eq 0 ]
  [[ "$output" == *"apps_browsers=brave firefox"* ]]
  [[ "$output" == *"apps_communication="$'\n'* ]]
  [[ "$output" == *"desktops=yes"* ]]
  [[ "$output" == *"languages=node python"* ]]
  [[ "$output" == *"docker=none"* ]]
}

@test "the app intro line shows once, only if an app group is asked" {
  gum_answers "${FRESH_ANSWERS[@]}"
  in_ask 'ask_missing'
  [ "$(grep -c 'Desktop apps' <<< "$output")" = 1 ]
  gum_answers none
  in_ask 'choices_load "$REPO_ROOT/test/fixtures/bare.env"; unset "CHOICES[docker]"; ask_missing'
  [ "$status" -eq 0 ]
  [[ "$output" != *"Desktop apps"* ]]
}

@test "only missing keys are asked" {
  gum_answers colima
  in_ask 'choices_load "$REPO_ROOT/test/fixtures/bare.env"; unset "CHOICES[docker]"; ask_missing; echo "docker=${CHOICES[docker]}"'
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 1 ]
  [[ "$(prompts)" == *"How should Docker run?"* ]]
  [[ "$output" == *"docker=colima"* ]]
}

@test "Ctrl-C at a question exits 130 with the stop message" {
  gum_answers tokyo-night "exit 130"
  in_ask 'ask_missing'
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing was changed."* ]]
}

@test "Ctrl-C at a yes/no question exits 130" {
  gum_answers "${FRESH_ANSWERS[@]:0:8}" "exit 130"
  in_ask 'ask_missing'
  [ "$status" -eq 130 ]
}

@test "prompts read the tty, not stdin" {
  # After boot.sh's exec, stdin is the spent curl pipe. A decoy there must not matter.
  gum_answers "${FRESH_ANSWERS[@]}" yes
  in_ask 'ask_missing; ask_install' <<< decoy
  [ "$status" -eq 0 ]
  : > "$OMAMAC_TEST_TTY"
  gum_answers "${FRESH_ANSWERS[@]}"
  in_ask 'ask_missing'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not reading the tty"* ]]
}

@test "a prompt that fails another way stops the run, naming the question" {
  gum_answers "exit 2"
  in_ask 'ask_missing'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Theme"* ]]
}

@test "summary shows labels and none" {
  in_ask 'choices_load "$REPO_ROOT/test/fixtures/bare.env"
    CHOICES[apps_browsers]="brave firefox"
    ask_summary'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Theme: Tokyo Night"* ]]
  [[ "$output" == *"Browsers: Brave, Firefox"* ]]
  [[ "$output" == *"Media: none"* ]]
  [[ "$output" == *"Wispr Flow: no"* ]]
  [[ "$output" == *"Docker: No Docker"* ]]
  [ "$(grep -c ': ' <<< "$output")" = 16 ]
}

@test "Install? yes returns 0, no returns 1, Ctrl-C exits 130" {
  gum_answers yes
  in_ask 'ask_install'
  [ "$status" -eq 0 ]
  grep -qx 'gum confirm --default=false Install?' "$STUB_LOG"
  gum_answers no
  in_ask 'ask_install'
  [ "$status" -eq 1 ]
  gum_answers "exit 130"
  in_ask 'ask_install'
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing was changed."* ]]
}
