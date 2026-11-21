load helpers/common

setup() {
  setup_sandbox
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  EXT="$HOME/.vscode/extensions/omamac.omamac-theme-1.0.0"
  SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
}

# vscode_app: VS Code is installed, with the fake code command in it.
vscode_app() {
  local bin="$OMAMAC_TEST_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$bin"
  ln -sf "$HELPERS_DIR/fake-code" "$bin/code"
}

# install <id>: vscode_theme_install with that theme chosen.
install() {
  run "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/choices.sh'
    source '$REPO_ROOT/lib/vscode.sh'
    CHOICES[theme]=$1
    vscode_theme_install"
}

@test "no VS Code: nothing happens" {
  install dracula
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$HOME/.vscode" ]
}

# used_vscode [<json>]: VS Code has run, and its extensions list holds json ([] by default).
used_vscode() {
  mkdir -p "$HOME/.vscode/extensions"
  echo "${1:-[]}" > "$HOME/.vscode/extensions/extensions.json"
}

@test "VS Code that hasn't run: omamac's folder, made the default, and no VS Code program runs" {
  vscode_app
  install dracula
  [ "$status" -eq 0 ]
  cmp "$EXT/themes/omamac.json" "$REPO_ROOT/themes/dracula/vscode.json"
  [ "$(jq -r '"\(.publisher).\(.name) \(.version)"' "$EXT/package.json")" = 'omamac.omamac-theme 1.0.0' ]
  [ "$(jq -r '.contributes.configurationDefaults["workbench.colorTheme"]' "$EXT/package.json")" = omamac ]
  [ "$(jq -r '.contributes.themes[0] | "\(.id) \(.label) \(.uiTheme) \(.path)"' "$EXT/package.json")" = 'omamac omamac vs-dark ./themes/omamac.json' ]
  [ "$(cd "$EXT" && find . -type f | sort | paste -sd' ' -)" = './package.json ./themes/omamac.json' ]
  [ ! -s "$STUB_LOG" ]
  [ "$output" = "✓ VS Code has the theme too." ]
  # The user's settings and VS Code's list are never written.
  [ ! -e "$SETTINGS" ]
  [ ! -e "$HOME/.vscode/extensions/extensions.json" ]
}

@test "VS Code that has run: its own command installs the two files" {
  vscode_app
  used_vscode
  install dracula
  [ "$status" -eq 0 ]
  cmp "$EXT/themes/omamac.json" "$REPO_ROOT/themes/dracula/vscode.json"
  grep -qx "code --install-extension .*/omamac-theme.vsix --force" "$STUB_LOG"
  grep -qx 'vsix extension/package.json extension/themes/omamac.json' "$STUB_LOG"
  [ "$output" = "✓ VS Code has the theme too." ]
}

@test "VS Code that lists omamac's extension: the files are rewritten in place" {
  vscode_app
  used_vscode
  install dracula
  : > "$STUB_LOG"
  install nord
  [ "$status" -eq 0 ]
  cmp "$EXT/themes/omamac.json" "$REPO_ROOT/themes/nord/vscode.json"
  [ ! -s "$STUB_LOG" ]
  grep -q '"omamac.omamac-theme"' "$HOME/.vscode/extensions/extensions.json"
}

@test "a second run writes nothing" {
  vscode_app
  install dracula
  before=$(stat -f %m "$EXT/package.json" "$EXT/themes/omamac.json")
  sleep 1.1
  install dracula
  [ "$status" -eq 0 ]
  [ "$(stat -f %m "$EXT/package.json" "$EXT/themes/omamac.json")" = "$before" ]
  [ ! -s "$STUB_LOG" ]
  # Nothing changed, so nothing is said: the theme step's line names VS Code.
  [ -z "$output" ]
}

@test "another theme replaces the colours" {
  vscode_app
  install dracula
  install nord
  [ "$status" -eq 0 ]
  cmp "$EXT/themes/omamac.json" "$REPO_ROOT/themes/nord/vscode.json"
}

@test "the light theme is based on VS Code's light colours" {
  vscode_app
  install rose-pine
  [ "$status" -eq 0 ]
  [ "$(jq -r '.contributes.themes[0].uiTheme' "$EXT/package.json")" = vs ]
}

@test "the user's own VS Code theme is kept, and said" {
  vscode_app
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  // mine\n  "workbench.colorTheme": "Solarized Light"\n}\n' > "$SETTINGS"
  cp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
  install dracula
  [ "$status" -eq 0 ]
  [[ "$output" == *"Your own VS Code theme is kept, so the theme doesn't reach VS Code."* ]]
  [[ "$output" != *"VS Code has the theme"* ]]
  cmp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
}

@test "omamac picked in VS Code's own list isn't the user's own theme" {
  vscode_app
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n    "workbench.colorTheme": "omamac"\n}\n' > "$SETTINGS"
  install dracula
  [ "$status" -eq 0 ]
  [[ "$output" != *"Your own VS Code theme"* ]]
  [[ "$output" == *"VS Code has the theme too."* ]]
}

@test "a commented-out theme line isn't the user's own" {
  vscode_app
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  // "workbench.colorTheme": "Default Dark+",\n  "editor.fontSize": 14\n}\n' > "$SETTINGS"
  install dracula
  [ "$status" -eq 0 ]
  [[ "$output" != *"Your own VS Code theme"* ]]
}

@test "omamac picked with a tab before it isn't the user's own either" {
  vscode_app
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n\t"workbench.colorTheme":\t"omamac"\n}\n' > "$SETTINGS"
  install dracula
  [ "$status" -eq 0 ]
  [[ "$output" != *"Your own VS Code theme"* ]]
}

@test "zip fails: the temp folder goes, and the run stops" {
  vscode_app
  used_vscode
  stub zip 'exit 3'
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
  install dracula
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$TMPDIR")" ]
  [ ! -e "$EXT" ]
}

@test "VS Code fails to install: a clear message, and the run stops" {
  vscode_app
  used_vscode
  export T_CODE_FAIL=1
  install dracula
  [ "$status" -ne 0 ]
  [[ "$output" == *"VS Code didn't install omamac's theme. VS Code's message is in $OMAMAC_LOG"* ]]
  grep -q 'fake-code: Failed Installing Extensions' "$OMAMAC_LOG"
}
