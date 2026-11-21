load helpers/common

bats_require_minimum_version 1.5.0

TEMPLATE="$BATS_TEST_DIRNAME/../config/herdr.toml"

setup() {
  setup_sandbox
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  FILE="$HOME/.config/omamac/herdr.toml"
  # A test points this at a copy of the checkout to change the template.
  CHECKOUT=$REPO_ROOT
}

# in_lib <code>: run bash 5 code with herdr's config steps loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$CHECKOUT'
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/questions.sh'
    source '$REPO_ROOT/lib/choices.sh'
    source '$REPO_ROOT/lib/herdr.sh'
    source '$REPO_ROOT/lib/ghostty.sh'
    source '$REPO_ROOT/lib/neovim.sh'
    source '$REPO_ROOT/lib/theme.sh'
    source '$REPO_ROOT/lib/vscode.sh'
    source '$REPO_ROOT/lib/clis.sh'
    source '$REPO_ROOT/lib/apply.sh'
    CHOICES[theme]=tokyo-night
    $1"
}

# says <line>: the output closes with the theme step's line; the herdr ℹ line
# is there only when the user's own config is kept.
says() {
  [[ "$output" == *"✓ Theme: "* ]]
  if [[ "$1" == ℹ* ]]; then
    [[ "$output" == *"$1"* ]]
  else
    [[ "$output" != *"Your own herdr config is kept."* ]]
  fi
}

@test "the template's commands all name the helper" {
  [ "$(grep -c '^command = "@OMAMAC_HELPER@ ' "$TEMPLATE")" -eq 11 ]
  grep -qx 'name = "@OMAMAC_HERDR_THEME@"' "$TEMPLATE"
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

# rendered: omamac's file as omamac would write it now, at $BATS_TEST_TMPDIR/rendered.toml.
# It replaces $output, so check the output first.
rendered() { in_lib "herdr_render '$BATS_TEST_TMPDIR/rendered.toml'"; [ "$status" -eq 0 ]; }

@test "fresh: writes the file" {
  in_lib theme_apply
  [ "$status" -eq 0 ]
  says "✓ Theme: "
  rendered
  cmp "$FILE" "$BATS_TEST_TMPDIR/rendered.toml"
  grep -qF "command = \"$HOME/.local/share/omamac/bin/omamac-herdr-mode pane\"" "$FILE"
  run ! grep -q '@OMAMAC_HELPER@' "$FILE"
}

@test "a helper path with & or / is written as is" {
  export HOME="$BATS_TEST_TMPDIR/a&b"
  mkdir -p "$HOME"
  in_lib theme_apply
  [ "$status" -eq 0 ]
  grep -qF "command = \"$HOME/.local/share/omamac/bin/omamac-herdr-mode pane\"" "$HOME/.config/omamac/herdr.toml"
}

@test "a second run leaves the file alone" {
  in_lib theme_apply
  before=$(stat -f %m "$FILE")
  sleep 1.1
  in_lib theme_apply
  [ "$status" -eq 0 ]
  [ "$(stat -f %m "$FILE")" = "$before" ]
  [ -z "$(find "$HOME/.config/omamac" -name 'herdr.toml.*')" ]
}

@test "a new template replaces omamac's unchanged file" {
  in_lib theme_apply
  CHECKOUT="$BATS_TEST_TMPDIR/checkout"
  mkdir -p "$CHECKOUT"
  cp -R "$REPO_ROOT/themes" "$REPO_ROOT/config" "$CHECKOUT/"
  { cat "$TEMPLATE"; echo '# a new line'; } > "$CHECKOUT/config/herdr.toml"
  in_lib theme_apply
  [ "$status" -eq 0 ]
  grep -qx '# a new line' "$FILE"
}

@test "changed in herdr: the next run writes omamac's file again" {
  in_lib theme_apply
  awk '{ print } /^\[ui\]$/ { print "sound = false" }' "$FILE" > "$FILE.new"
  mv "$FILE.new" "$FILE"
  in_lib theme_apply
  [ "$status" -eq 0 ]
  says "✓ Theme: "
  rendered
  cmp "$FILE" "$BATS_TEST_TMPDIR/rendered.toml"
}

@test "the user's own config: ℹ and never written" {
  mkdir -p "$HOME/.config/herdr"
  echo 'mine' > "$HOME/.config/herdr/config.toml"
  before="$(shasum < "$HOME/.config/herdr/config.toml") $(stat -f %m "$HOME/.config/herdr/config.toml")"
  sleep 1.1
  in_lib theme_apply
  [ "$status" -eq 0 ]
  says "ℹ Your own herdr config is kept."
  # The theme line doesn't name herdr.
  [[ "$output" == *"✓ Theme: Tokyo Night, in Ghostty, btop, the prompt and neovim"* ]]
  [ "$(shasum < "$HOME/.config/herdr/config.toml") $(stat -f %m "$HOME/.config/herdr/config.toml")" = "$before" ]
  # omamac's file is still kept up to date.
  rendered
  cmp "$FILE" "$BATS_TEST_TMPDIR/rendered.toml"
}

@test "the user's own config and omamac's file changed: omamac's rewritten, only ℹ kept" {
  in_lib theme_apply
  echo '# changed' >> "$FILE"
  mkdir -p "$HOME/.config/herdr"
  echo 'mine' > "$HOME/.config/herdr/config.toml"
  in_lib theme_apply
  [ "$status" -eq 0 ]
  says "ℹ Your own herdr config is kept."
  run ! grep -qx '# changed' "$FILE"
}

@test "herdr's own onboarding file is not the user's" {
  mkdir -p "$HOME/.config/herdr"
  printf 'onboarding = false\n' > "$HOME/.config/herdr/config.toml"
  in_lib theme_apply
  [ "$status" -eq 0 ]
  says "✓ Theme: "
  [ "$(<"$HOME/.config/herdr/config.toml")" = 'onboarding = false' ]
}

@test "the user's own HERDR_CONFIG_PATH: ℹ" {
  export HERDR_CONFIG_PATH="$HOME/mine.toml"
  in_lib theme_apply
  [ "$status" -eq 0 ]
  says "ℹ Your own herdr config is kept."
  [ ! -e "$HOME/mine.toml" ]
}

@test "omamac's own HERDR_CONFIG_PATH counts as omamac's" {
  export HERDR_CONFIG_PATH="$HOME/.config/omamac/herdr.toml"
  in_lib theme_apply
  [ "$status" -eq 0 ]
  says "✓ Theme: "
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
