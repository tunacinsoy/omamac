load helpers/common

bats_require_minimum_version 1.5.0

TEMPLATE="$BATS_TEST_DIRNAME/../config/herdr.toml"

setup() {
  setup_sandbox
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  FILE="$HOME/.config/omamac/herdr.toml"
  WRITTEN="$HOME/.local/state/omamac/herdr.toml.written"
  # A test points this at a copy of the checkout to change the template.
  CHECKOUT=$REPO_ROOT
}

# in_lib <code>: run bash 5 code with herdr's config steps loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$CHECKOUT'
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/herdr.sh'
    source '$REPO_ROOT/lib/apply.sh'
    $1"
}

@test "the template's commands all name the helper" {
  [ "$(grep -c '^command = "@OMAMAC_HELPER@ ' "$TEMPLATE")" -eq 11 ]
  run ! grep -niE 'omawsl|zellij' "$TEMPLATE"
}

@test "the template sets onboarding = false before any table" {
  [ "$(grep -vE '^[[:space:]]*(#|$)' "$TEMPLATE" | head -n 1)" = "onboarding = false" ]
}

@test "each Ctrl g mode letter opens its popup" {
  local pair
  in_lib "herdr_render '$BATS_TEST_TMPDIR/rendered.toml'"
  [ "$status" -eq 0 ]
  for pair in p:pane t:tab r:resize m:move o:session; do
    grep -A2 "^key = \"prefix+${pair%%:*}\"" "$BATS_TEST_TMPDIR/rendered.toml" | grep -qF "omamac-herdr-mode ${pair#*:}\""
  done
}

@test "fresh: writes the file and its copy" {
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  cmp "$FILE" "$WRITTEN"
  grep -qF "command = \"$HOME/.local/share/omamac/bin/omamac-herdr-mode pane\"" "$FILE"
  [[ "$output" == *"herdr's config is in place"* ]]
  run ! grep -q '@OMAMAC_HELPER@' "$FILE"
}

@test "a helper path with & or / is written as is" {
  export HOME="$BATS_TEST_TMPDIR/a&b"
  mkdir -p "$HOME"
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  grep -qF "command = \"$HOME/.local/share/omamac/bin/omamac-herdr-mode pane\"" "$HOME/.config/omamac/herdr.toml"
}

@test "a second run leaves both files alone" {
  in_lib herdr_config_apply
  before="$(stat -f %m "$FILE") $(stat -f %m "$WRITTEN")"
  sleep 1.1
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  [ "$(stat -f %m "$FILE") $(stat -f %m "$WRITTEN")" = "$before" ]
  [ -z "$(find "$HOME/.config/omamac" "$HOME/.local/state/omamac" -name 'herdr.toml.*' -not -name '*.written')" ]
}

@test "a new template replaces omamac's unchanged file" {
  in_lib herdr_config_apply
  CHECKOUT="$BATS_TEST_TMPDIR/checkout"
  mkdir -p "$CHECKOUT/config"
  { cat "$TEMPLATE"; echo '# a new line'; } > "$CHECKOUT/config/herdr.toml"
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  grep -qx '# a new line' "$FILE"
  cmp "$FILE" "$WRITTEN"
}

@test "changed in herdr: left alone, says how to undo" {
  in_lib herdr_config_apply
  awk '{ print } /^\[ui\]$/ { print "sound = false" }' "$FILE" > "$FILE.new"
  mv "$FILE.new" "$FILE"
  before=$(shasum < "$FILE")
  for _ in 1 2; do
    in_lib herdr_config_apply
    [ "$status" -eq 0 ]
    [ "$(shasum < "$FILE")" = "$before" ]
    [[ "$output" == *"delete ~/.config/omamac/herdr.toml"* ]]
  done
  grep -qx 'sound = false' "$FILE"
}

@test "stopped before the copy: finishes it quietly" {
  in_lib herdr_config_apply
  rm "$WRITTEN"
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  cmp "$FILE" "$WRITTEN"
  [[ "$output" != *"changed in herdr"* ]]
}

@test "the user's own config: ℹ and never written" {
  mkdir -p "$HOME/.config/herdr"
  echo 'mine' > "$HOME/.config/herdr/config.toml"
  before="$(shasum < "$HOME/.config/herdr/config.toml") $(stat -f %m "$HOME/.config/herdr/config.toml")"
  sleep 1.1
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Your own herdr config is kept."* ]]
  [ "$(shasum < "$HOME/.config/herdr/config.toml") $(stat -f %m "$HOME/.config/herdr/config.toml")" = "$before" ]
}

@test "herdr's own onboarding file is not the user's" {
  mkdir -p "$HOME/.config/herdr"
  printf 'onboarding = false\n' > "$HOME/.config/herdr/config.toml"
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ herdr's config is in place"* ]]
  [[ "$output" != *"Your own herdr config is kept."* ]]
  [ "$(<"$HOME/.config/herdr/config.toml")" = 'onboarding = false' ]
}

@test "the user's own HERDR_CONFIG_PATH: ℹ" {
  export HERDR_CONFIG_PATH="$HOME/mine.toml"
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Your own herdr config is kept."* ]]
  [ ! -e "$HOME/mine.toml" ]
}

@test "omamac's own HERDR_CONFIG_PATH counts as omamac's" {
  export HERDR_CONFIG_PATH="$HOME/.config/omamac/herdr.toml"
  in_lib herdr_config_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"herdr's config is in place"* ]]
}

@test "herdr config check accepts the rendered file" {
  command -v herdr >/dev/null || skip "herdr is not installed"
  in_lib "herdr_render '$BATS_TEST_TMPDIR/rendered.toml'"
  [ "$status" -eq 0 ]
  HERDR_CONFIG_PATH="$BATS_TEST_TMPDIR/rendered.toml" run herdr config check
  [ "$status" -eq 0 ]
  [[ "$output" == "config: ok"* ]]
}

@test "no key spelling herdr's client rejects" {
  # "alt+plus" passes `herdr config check` but the client rewrites it to
  # "alt++" and disables it; "+" can't be bound at all.
  [ -z "$(grep -vE '^[[:space:]]*#' "$TEMPLATE" | grep -E '"[^"]*\+plus"|"[^"]*\+\+"' || true)" ]
}
