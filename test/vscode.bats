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

@test "installs the extension with the chosen theme, made the default" {
  vscode_app
  install dracula
  [ "$status" -eq 0 ]
  cmp "$EXT/themes/omamac.json" "$REPO_ROOT/themes/dracula/vscode.json"
  [ "$(jq -r '.contributes.configurationDefaults["workbench.colorTheme"]' "$EXT/package.json")" = omamac ]
  [ "$(jq -r '.contributes.themes[0] | "\(.id) \(.label) \(.uiTheme) \(.path)"' "$EXT/package.json")" = 'omamac omamac vs-dark ./themes/omamac.json' ]
  grep -qx "code --install-extension .*/omamac-theme.vsix --force" "$STUB_LOG"
  # Only the two files: nothing else of omamac's reaches VS Code.
  grep -qx 'vsix extension/package.json extension/themes/omamac.json' "$STUB_LOG"
  [[ "$output" == *"VS Code has the theme. It shows the next time VS Code opens."* ]]
  # The user's settings are never written.
  [ ! -e "$SETTINGS" ]
}

@test "a second run installs nothing" {
  vscode_app
  install dracula
  : > "$STUB_LOG"
  install dracula
  [ "$status" -eq 0 ]
  [ ! -s "$STUB_LOG" ]
  [[ "$output" == *"VS Code has the theme"* ]]
  [[ "$output" != *"It shows the next time"* ]]
}

@test "another theme replaces the colours" {
  vscode_app
  install dracula
  install nord
  [ "$status" -eq 0 ]
  cmp "$EXT/themes/omamac.json" "$REPO_ROOT/themes/nord/vscode.json"
  [ "$(grep -c -- '--install-extension' "$STUB_LOG")" -eq 2 ]
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
  [[ "$output" == *"omamac's theme is in VS Code"* ]]
  [[ "$output" != *"It shows the next time"* ]]
  cmp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
}

@test "omamac picked in VS Code's own list isn't the user's own theme" {
  vscode_app
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n    "workbench.colorTheme": "omamac"\n}\n' > "$SETTINGS"
  install dracula
  [ "$status" -eq 0 ]
  [[ "$output" != *"Your own VS Code theme"* ]]
  [[ "$output" == *"VS Code has the theme"* ]]
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
  export T_CODE_FAIL=1
  install dracula
  [ "$status" -ne 0 ]
  [[ "$output" == *"VS Code didn't install omamac's theme. VS Code's message is in $OMAMAC_LOG"* ]]
  grep -q 'fake-code: Failed Installing Extensions' "$OMAMAC_LOG"
}
