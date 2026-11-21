# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap
# VS Code follows the theme through omamac's own extension, omamac.omamac-theme: one
# colour theme, "omamac", that it makes VS Code's default. omamac never writes the
# user's settings.json, so a theme the user set there wins. Needs lib/paths.sh,
# lib/ui.sh and lib/choices.sh (the theme is CHOICES[theme]).

VSCODE_EXTENSION=omamac.omamac-theme
VSCODE_VERSION=1.0.0

# vscode_code: the code command inside the app. It is there whenever VS Code is
# installed, whoever installed it.
vscode_code() { echo "$OMAMAC_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin/code"; }

# vscode_theme_file: the chosen theme's colours for VS Code.
vscode_theme_file() { echo "$OMAMAC_CHECKOUT/themes/${CHOICES[theme]:?no theme is chosen}/vscode.json"; }

# vscode_installed_theme: VS Code's copy of the theme file. VS Code copies it as it
# is, but rewrites package.json, so this file is the one to compare.
vscode_installed_theme() { echo "$OMAMAC_VSCODE_EXTENSIONS/$VSCODE_EXTENSION-$VSCODE_VERSION/themes/omamac.json"; }

# vscode_has_theme: VS Code has the chosen theme's colours.
vscode_has_theme() { cmp -s "$(vscode_theme_file)" "$(vscode_installed_theme)"; }

# vscode_user_theme: the user set a theme of their own in VS Code's settings.
# Picking "omamac" in VS Code writes it there too, and that isn't their own.
vscode_user_theme() {
  local lines
  lines=$(grep -s '"workbench.colorTheme"' "$OMAMAC_VSCODE_SETTINGS") || return 1
  grep -qv '"workbench.colorTheme" *: *"omamac"' <<< "$lines"
}

# vscode_package <theme file> <out>: the extension's package.json. VS Code bases
# the colours the theme file doesn't set on uiTheme: vs for a light theme.
vscode_package() {
  local ui=vs-dark
  [ "$(jq -r .type "$1")" != light ] || ui=vs
  cat > "$2" << JSON
{
  "name": "omamac-theme",
  "displayName": "omamac theme",
  "description": "The theme omamac theme chose. omamac replaces it on every run.",
  "publisher": "omamac",
  "version": "$VSCODE_VERSION",
  "engines": { "vscode": "^1.70.0" },
  "contributes": {
    "themes": [{ "id": "omamac", "label": "omamac", "uiTheme": "$ui", "path": "./themes/omamac.json" }],
    "configurationDefaults": { "workbench.colorTheme": "omamac" }
  }
}
JSON
}

# vscode_theme_install: when VS Code is installed and doesn't have the chosen
# theme yet, build the extension and install it with VS Code's own command.
vscode_theme_install() {
  local code tmp
  code=$(vscode_code)
  [ -x "$code" ] || return 0
  ui_step "VS Code's theme"
  if ! vscode_has_theme; then
    OMAMAC_STEP="installing omamac's theme in VS Code"
    tmp=$(mktemp -d)
    mkdir -p "$tmp/extension/themes"
    cp "$(vscode_theme_file)" "$tmp/extension/themes/omamac.json"
    vscode_package "$(vscode_theme_file)" "$tmp/extension/package.json"
    # A .vsix is a zip with the extension in extension/; zip names entries from the folder it runs in.
    (cd "$tmp" && zip -qr omamac-theme.vsix extension)
    if ! "$code" --install-extension "$tmp/omamac-theme.vsix" --force >> "$OMAMAC_LOG" 2>&1; then
      rm -rf "$tmp"
      ui_fail "VS Code didn't install omamac's theme. VS Code's message is in $OMAMAC_LOG"
      return 1
    fi
    rm -rf "$tmp"
  fi
  if vscode_user_theme; then
    ui_info "Your own VS Code theme is kept, so the theme doesn't reach VS Code."
    ui_ok "omamac's theme is in VS Code"
  else
    ui_ok "VS Code has the theme. It shows the next time VS Code opens."
  fi
}
