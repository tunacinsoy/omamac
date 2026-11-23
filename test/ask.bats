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

@test "fresh: all 19 asked in table order, nothing pre-selected" {
  gum_answers "${FRESH_ANSWERS[@]}"
  in_ask 'ask_missing
    for k in "${QUESTION_KEYS[@]}"; do echo "TEXT ${QUESTION_TEXT[$k]}"; done'
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 19 ]
  i=0
  while IFS= read -r text; do
    i=$((i + 1))
    [[ "$(prompts | sed -n "${i}p")" == *"${text#TEXT }"* ]] || { echo "prompt $i isn't: $text"; return 1; }
  done < <(printf '%s\n' "${lines[@]}" | grep '^TEXT ')
  ! grep -q -- '--selected' "$STUB_LOG"
  [ "$(grep -c '^gum confirm' "$STUB_LOG")" = 6 ]
  [ "$(grep -c '^gum confirm --default=false ' "$STUB_LOG")" = 6 ]
}

@test "the user's GUM_ settings don't reach the prompts" {
  gum_answers "${FRESH_ANSWERS[@]}"
  GUM_CHOOSE_SELECTED=tokyo-night GUM_CONFIRM_DEFAULT=true in_ask 'ask_missing'
  [ "$status" -eq 0 ]
  [ "$(prompts | wc -l | tr -d ' ')" = 19 ]
  [ ! -s "$STUB_LOG.gum-env" ]
}

@test "a gum failure under omamac <command> says to run that command again" {
  gum_answers "exit 2"
  OMAMAC_CMD=install in_ask 'ask_missing'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Run omamac install again."* ]]
  [[ "$output" != *"one-liner"* ]]
  gum_answers "exit 2"
  in_ask 'ask_missing'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Run the one-liner again."* ]]
}

@test "multi uses --no-limit, single does not" {
  gum_answers "${FRESH_ANSWERS[@]}"
  in_ask 'ask_missing'
  [ "$status" -eq 0 ]
  [[ "$(prompts | sed -n 1p)" != *--no-limit* ]]
  [[ "$(prompts | sed -n 2p)" == *"--no-limit"* ]]
  [[ "$(prompts | sed -n 19p)" != *--no-limit* ]]
  [[ "$(prompts | sed -n 19p)" == *"--label-delimiter=: No Docker:none colima:colima Docker Desktop:docker-desktop"* ]]
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
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
}

@test "Ctrl-C at a yes/no question exits 130" {
  gum_answers "${FRESH_ANSWERS[@]:0:8}" "exit 130"
  in_ask 'ask_missing'
  [ "$status" -eq 130 ]
}

@test "prompts read the tty, not stdin" {
  # After boot.sh's exec, stdin is the spent curl pipe. A decoy there must not matter.
  gum_answers "${FRESH_ANSWERS[@]}" yes
  in_ask 'ask_missing; ask_yes "Install?"' <<< decoy
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
  [ "$(grep -c ': ' <<< "$output")" = 19 ]
}

@test "ask_yes: yes 0, no 1, Ctrl-C 130" {
  gum_answers yes
  in_ask 'ask_yes "Install?"'
  [ "$status" -eq 0 ]
  grep -qx 'gum confirm --default=false Install?' "$STUB_LOG"
  gum_answers no
  in_ask 'ask_yes "Install?"'
  [ "$status" -eq 1 ]
  gum_answers "exit 130"
  in_ask 'ask_yes "Install?"'
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
}

@test "ask_one with values offers only those" {
  gum_answers "go"
  in_ask 'CHOICES[languages]=node
    ask_one languages rust go
    echo "languages=${CHOICES[languages]}"'
  [ "$status" -eq 0 ]
  [[ "$(prompts)" == *"--label-delimiter=: Go:go Rust:rust" ]]
  [[ "$output" == *"languages=go"* ]]
}

@test "ask_choose sets ASK_PICKED; Ctrl-C exits 130" {
  gum_answers rust
  in_ask 'ask_choose "Remove which?" Go:go Rust:rust; echo "picked=$ASK_PICKED"'
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum choose --header Remove which? --label-delimiter=: Go:go Rust:rust" ]
  [[ "$output" == *"picked=rust"* ]]
  gum_answers "exit 130"
  in_ask 'ask_choose "Remove which?" Go:go Rust:rust; echo "after"'
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
  [[ "$output" != *after* ]]
}

@test "the help line comes before its question" {
  gum_answers yes
  in_ask 'choices_load "$REPO_ROOT/test/fixtures/bare.env"; unset "CHOICES[desktops]"; ask_missing'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Reduce motion turns on, which shortens animations everywhere."* ]]
  [ "$(prompts)" = "gum confirm --default=false Make desktops behave like workspaces?" ]
}

@test "the summary fits an 80-column terminal with every app picked" {
  in_ask 'choices_load "$REPO_ROOT/test/fixtures/bare.env"
    for k in "${QUESTION_KEYS[@]}"; do
      [ "${QUESTION_KIND[$k]}" != multi ] || CHOICES[$k]=$(question_values "$k" | paste -sd" " -)
    done
    ask_summary'
  [ "$status" -eq 0 ]
  # The box adds a border and two spaces of padding on each side.
  while IFS= read -r line; do
    [ "${#line}" -le 74 ] || { echo "too long: $line"; return 1; }
  done <<< "$output"
}

@test "a long summary line goes on, indented, at a comma" {
  in_ask 'choices_load "$REPO_ROOT/test/fixtures/bare.env"
    CHOICES[coding_agents]="claude-code codex copilot-cli antigravity-cli opencode"
    ask_summary'
  [ "$status" -eq 0 ]
  [[ "$output" == *$'Coding agents: Claude Code CLI, Codex CLI, Copilot CLI, Antigravity CLI,\n  opencode CLI'* ]]
}

@test "no terminal: stops before asking, never reads it as no" {
  gum_answers "${FRESH_ANSWERS[@]}"
  rm "$OMAMAC_TEST_TTY"
  in_ask 'ask_missing'
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs a terminal"* ]]
  [ -z "$(prompts)" ]
  in_ask 'ask_yes "Install?"'
  [ "$status" -eq 1 ]
}

@test "a terminal that can't be opened: ask_yes stops, never reads it as no" {
  gum_answers no
  unopenable_tty "$OMAMAC_TEST_TTY"
  in_ask 'ask_yes "Install?"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ omamac needs a terminal to ask its questions. Run it from Terminal."* ]]
  [ -z "$(prompts)" ]
}
