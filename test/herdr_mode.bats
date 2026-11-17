load helpers/common

TWO_TABS='[{"tab_id":"w1:t1","number":1,"focused":true},{"tab_id":"w1:t2","number":2,"focused":false}]'

setup() {
  setup_sandbox
  command -v jq >/dev/null || skip "jq is not installed"
  local bin="$OMAMAC_TEST_BREW_PREFIX/bin"
  mkdir -p "$bin"
  ln -s "$(command -v jq)" "$bin/jq"
  MODE="$REPO_ROOT/bin/omamac-herdr-mode"
  # A developer running the suite inside herdr must not reach the real one.
  unset HERDR_SOCKET_PATH HERDR_ACTIVE_PANE_ID HERDR_ACTIVE_TAB_ID HERDR_ACTIVE_WORKSPACE_ID OMAMAC_TEST_NC
  unset STUB_NO_PANE STUB_TAB STUB_TABS STUB_PANES STUB_LABEL
  unset STUB_NEIGHBOR_left STUB_NEIGHBOR_right STUB_NEIGHBOR_up STUB_NEIGHBOR_down
  cat > "$bin/herdr" <<'EOF'
#!/bin/bash
echo "herdr $*" >> "$STUB_LOG"
# Defaults live in variables: a literal JSON default inside ${VAR:-...}
# would end the expansion at its first "}".
default_panes='[{"pane_id":"w1:p1","rect":{"width":120,"height":40}}]'
default_tabs='[{"tab_id":"w1:t1","number":1,"focused":true}]'
dir=""
for ((i = 1; i <= $#; i++)); do
  if [[ ${!i} == --direction ]]; then j=$((i + 1)); dir=${!j}; fi
done
case "$1 $2" in
  "pane list")
    if [[ -n ${STUB_NO_PANE:-} ]]; then
      echo '{"result":{"panes":[]}}'
    else
      printf '{"result":{"panes":[{"pane_id":"w1:p1","tab_id":"%s","workspace_id":"w1","focused":true}]}}\n' "${STUB_TAB:-w1:t1}"
    fi ;;
  "pane layout")
    printf '{"result":{"layout":{"panes":%s}}}\n' "${STUB_PANES:-$default_panes}" ;;
  "pane neighbor")
    v="STUB_NEIGHBOR_$dir"
    if [[ -n ${!v:-} ]]; then
      printf '{"result":{"neighbor":{"neighbor_pane_id":"%s"}}}\n' "${!v}"
    else
      echo '{"result":{"neighbor":{}}}'
    fi ;;
  "tab list")
    printf '{"result":{"tabs":%s}}\n' "${STUB_TABS:-$default_tabs}" ;;
  "pane get")
    if [[ -n ${STUB_LABEL:-} ]]; then
      printf '{"result":{"pane":{"pane_id":"w1:p1","label":"%s"}}}\n' "$STUB_LABEL"
    else
      echo '{"result":{"pane":{"pane_id":"w1:p1","label":null}}}'
    fi ;;
  *) echo '{}' ;;
esac
EOF
  chmod +x "$bin/herdr"
}

# keys <keys> <args>…: run the helper with <keys> on stdin, as a popup gets them.
keys() {
  local k=$1
  shift
  run "$BASH5" "$MODE" "$@" < <(printf '%s' "$k")
}

@test "pane mode: d splits the focused pane down" {
  keys d pane
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr pane split --pane w1:p1 --direction down --focus"* ]]
}

@test "pane mode: c saves the typed note as the pane's name" {
  keys $'cinvoice export, waiting on review\n' pane
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr pane rename w1:p1 invoice export, waiting on review"* ]]
}

@test "pane mode: c with an empty note clears the pane's name" {
  export STUB_LABEL="old note"
  keys $'c\n' pane
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr pane rename w1:p1 --clear"* ]]
}

@test "pane mode: c starts from the pane's current note" {
  # The prompt is pre-filled with the note so it can be edited, not retyped.
  export STUB_LABEL="old note"
  keys $'c\n' pane
  [[ "$(stub_calls)" == *"herdr pane get w1:p1"* ]]
}

@test "pane mode: hjkl focus is sticky until Esc" {
  keys $'hl\e' pane
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr pane focus --pane w1:p1 --direction left"* ]]
  [[ "$(stub_calls)" == *"herdr pane focus --pane w1:p1 --direction right"* ]]
}

@test "pane mode: Tab focuses the next pane by id over the socket" {
  export STUB_PANES='[{"pane_id":"w1:p1"},{"pane_id":"w1:p2"}]'
  # shellcheck disable=SC2016 # $STUB_LOG expands when the stub runs
  stub nc 'cat >> "$STUB_LOG"'
  export OMAMAC_TEST_NC="$STUB_DIR/nc" HERDR_SOCKET_PATH=/x
  keys $'\t\e' pane
  [ "$status" -eq 0 ]
  grep -qx 'nc -U -w 1 /x' "$STUB_LOG"
  [[ "$(stub_calls)" == *'"method":"pane.focus"'* ]]
  [[ "$(stub_calls)" == *'"pane_id":"w1:p2"'* ]]
}

@test "Esc, Enter and Ctrl g leave a mode without acting" {
  local k
  for k in $'\e' $'\n' $'\a'; do
    keys "$k" pane
    [ "$status" -eq 0 ]
  done
  [[ "$(stub_calls)" != *"pane split"* ]]
  [[ "$(stub_calls)" != *"pane focus"* ]]
  [[ "$(stub_calls)" != *"pane close"* ]]
}

@test "Enter sent as a carriage return (how real terminals send it) leaves a mode" {
  export STUB_TABS="$TWO_TABS"
  # l switches tab, then Enter must end the popup: the x after it would
  # otherwise close the tab.
  keys $'l\rx' tab
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr tab focus w1:t2"* ]]
  [[ "$(stub_calls)" != *"tab close"* ]]
}

@test "new-pane splits right in a wide pane and down in a tall one" {
  run "$BASH5" "$MODE" new-pane
  [[ "$(stub_calls)" == *"pane split --pane w1:p1 --direction right --focus"* ]]
  export STUB_PANES='[{"pane_id":"w1:p1","rect":{"width":60,"height":40}}]'
  run "$BASH5" "$MODE" new-pane
  [[ "$(stub_calls)" == *"pane split --pane w1:p1 --direction down --focus"* ]]
}

@test "focus-or-tab moves focus when there's a neighbor that way" {
  export STUB_NEIGHBOR_left=w1:p2
  run "$BASH5" "$MODE" focus-or-tab left
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr pane focus --pane w1:p1 --direction left"* ]]
  [[ "$(stub_calls)" != *"tab focus"* ]]
}

@test "focus-or-tab switches tab at the edge, wrapping around" {
  export STUB_TABS="$TWO_TABS"
  run "$BASH5" "$MODE" focus-or-tab left
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr tab focus w1:t2"* ]]
}

@test "tab mode: a digit jumps to that tab number" {
  export STUB_TABS="$TWO_TABS"
  keys 2 tab
  [[ "$(stub_calls)" == *"herdr tab focus w1:t2"* ]]
}

@test "tab mode: [ at the first tab breaks the pane into a new tab instead of wrapping" {
  export STUB_TABS="$TWO_TABS"
  keys '[' tab
  [[ "$(stub_calls)" == *"herdr pane move w1:p1 --new-tab --focus"* ]]
  [[ "$(stub_calls)" != *"--tab w1:t2"* ]]
}

@test "tab mode: ] moves the pane into the next tab" {
  export STUB_TABS="$TWO_TABS"
  keys ']' tab
  [[ "$(stub_calls)" == *"herdr pane move w1:p1 --tab w1:t2 --split right --focus"* ]]
}

@test "resize mode: l grows toward a right neighbor, L shrinks from it" {
  export STUB_NEIGHBOR_right=w1:p2
  keys lLr resize
  [[ "$(stub_calls)" == *"herdr pane resize --pane w1:p1 --direction right"* ]]
  [[ "$(stub_calls)" == *"herdr pane resize --pane w1:p1 --direction left"* ]]
}

@test "resize mode: l with no right neighbor still moves the border right" {
  # The right-hand pane: herdr moves its left border instead.
  export STUB_NEIGHBOR_left=w1:p0
  keys lr resize
  [[ "$(stub_calls)" == *"herdr pane resize --pane w1:p1 --direction right"* ]]
}

@test "resize mode: h with no left neighbor still moves the border left" {
  export STUB_NEIGHBOR_right=w1:p2
  keys hr resize
  [[ "$(stub_calls)" == *"herdr pane resize --pane w1:p1 --direction left"* ]]
}

@test "resize mode: HJKL do nothing toward a side with no neighbor" {
  keys HJKLr resize
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr pane neighbor"* ]]
  [[ "$(stub_calls)" != *"pane resize"* ]]
}

@test "move mode: h swaps with the pane to the left" {
  keys $'h\e' move
  [[ "$(stub_calls)" == *"herdr pane swap --pane w1:p1 --direction left"* ]]
}

@test "tab mode: hjkl switches tab and closes the popup" {
  # Not sticky: herdr 0.9 keeps placing popups on the old tab once a
  # running popup switches tabs, so later popups would open out of sight.
  export STUB_TABS="$TWO_TABS"
  keys lx tab
  [ "$status" -eq 0 ]
  [[ "$(stub_calls)" == *"herdr tab focus w1:t2"* ]]
  [[ "$(stub_calls)" != *"tab close"* ]]
}

@test "rejects an unknown mode with usage and exit 2" {
  run "$BASH5" "$MODE" not-a-mode
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: omamac-herdr-mode"* ]]
}

@test "no pane: says herdr isn't running, calls nothing else" {
  export STUB_NO_PANE=1
  keys x pane
  [ "$status" -eq 1 ]
  [[ "$output" == *"herdr isn't running"* ]]
  [ "$(stub_calls)" = "herdr pane list" ]
}

@test "no jq: names the fix" {
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/jq"
  keys x pane
  [ "$status" -eq 1 ]
  [[ "$output" == *"brew install jq"* ]]
  [ ! -s "$STUB_LOG" ]
}
