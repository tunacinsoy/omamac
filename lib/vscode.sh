# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap
# VS Code follows the theme through omamac's own extension, omamac.omamac-theme: one
# colour theme, "omamac", that it makes VS Code's default. omamac never writes the
# user's settings.json, so a theme the user set there wins. An open VS Code shows
# a new theme at once, because the theme asks VS Code to watch its file. Needs
# lib/paths.sh, lib/ui.sh and lib/choices.sh (the theme is CHOICES[theme]).

VSCODE_EXTENSION=omamac.omamac-theme
# The version stays 1.0.0: VS Code's list names the folder it installed, so a
# folder with a new version in its name would be ignored.
VSCODE_VERSION=1.0.0

# vscode_code: the code command inside the app. It is there whenever VS Code is
# installed, whoever installed it.
vscode_code() { echo "$OMAMAC_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin/code"; }

# vscode_theme_file: the chosen theme's colours for VS Code.
vscode_theme_file() { echo "$OMAMAC_CHECKOUT/themes/${CHOICES[theme]:?no theme is chosen}/vscode.json"; }

# vscode_installed_theme: the theme file in VS Code's extensions folder. VS Code's
# own install copies it as it is, but rewrites package.json, so this file is the
# one to compare.
vscode_installed_theme() { echo "$OMAMAC_VSCODE_EXTENSIONS/$VSCODE_EXTENSION-$VSCODE_VERSION/themes/omamac.json"; }

# vscode_has_theme: VS Code has the chosen theme's colours, in an extension that
# asks VS Code to watch them. One written before the watch existed doesn't, so it
# is written again.
vscode_has_theme() {
  local theme
  theme=$(vscode_installed_theme)
  cmp -s "$(vscode_theme_file)" "$theme" &&
    jq -e '.contributes.themes[0]._watch == true' "${theme%/themes/*}/package.json" > /dev/null 2>&1
}

# vscode_user_theme: the user set a theme of their own in VS Code's settings. A
# line that starts with // is a comment. Picking "omamac" in VS Code writes it
# there too, and that isn't their own.
vscode_user_theme() {
  local lines
  lines=$(grep -s '"workbench.colorTheme"' "$OMAMAC_VSCODE_SETTINGS" | grep -v '^[[:space:]]*//') || return 1
  grep -qv '"workbench.colorTheme"[[:space:]]*:[[:space:]]*"omamac"' <<< "$lines"
}

# vscode_package <theme file> <out>: the extension's package.json. VS Code bases
# the colours the theme file doesn't set on uiTheme: vs for a light theme. VS Code
# reads package.json only when it starts, so an open window keeps its old base.
# "_watch": true makes VS Code watch the theme file while the theme is in use and
# reload it when the file changes: that is how an open window follows omamac
# theme with no code in the extension and no write to settings.json. It is VS
# Code's own switch for theme authors, undocumented (1.147 reads it when it
# loads an extension's themes). If VS Code drops it, the theme still changes the
# next time VS Code opens.
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
    "themes": [{ "id": "omamac", "label": "omamac", "uiTheme": "$ui", "path": "./themes/omamac.json", "_watch": true }],
    "configurationDefaults": { "workbench.colorTheme": "omamac" }
  }
}
JSON
}

# vscode_extension_files <dir>: write the extension's two files into dir, the
# theme file last: it is the one vscode_has_theme compares, so a run cut short
# between the two writes both again. cp writes over the theme file in place, so
# the file VS Code watches stays the same file.
vscode_extension_files() {
  mkdir -p "$1/themes" &&
    vscode_package "$(vscode_theme_file)" "$1/package.json" &&
    cp "$(vscode_theme_file)" "$1/themes/omamac.json"
}

# vscode_knows_folder: VS Code will use omamac's folder in its extensions folder.
# With no extensions.json, VS Code hasn't run yet, and its first start registers
# every folder there. Once the list exists, a folder it doesn't name is ignored.
vscode_knows_folder() {
  local list=$OMAMAC_VSCODE_EXTENSIONS/extensions.json
  [ ! -e "$list" ] || grep -qF "\"$VSCODE_EXTENSION\"" "$list"
}

# vscode_theme_install: when VS Code is installed and doesn't have the chosen
# theme yet, put it in. Mostly by writing omamac's own extension folder: no VS
# Code program runs, so macOS's first-open check of a new app, which nobody is
# there to answer during the run, never comes up. Only when VS Code has run and
# keeps a list without omamac's extension does omamac use VS Code's own
# command; the app has been opened on this Mac by then.
vscode_theme_install() {
  local code tmp wrote=''
  code=$(vscode_code)
  [ -x "$code" ] || return 0
  if ! vscode_has_theme; then
    OMAMAC_STEP="writing omamac's theme for VS Code"
    if vscode_knows_folder; then
      vscode_extension_files "$OMAMAC_VSCODE_EXTENSIONS/$VSCODE_EXTENSION-$VSCODE_VERSION"
    else
      OMAMAC_STEP="installing omamac's theme in VS Code"
      tmp=$(mktemp -d)
      # && because errexit is off inside { } ||; a failure removes the temp folder
      # before the caller's ERR trap fires. A .vsix is a zip with the extension in
      # extension/; zip names entries from the folder it runs in.
      {
        vscode_extension_files "$tmp/extension" &&
          (cd "$tmp" && zip -qr omamac-theme.vsix extension)
      } || { rm -rf "$tmp"; return 1; }
      if ! "$code" --install-extension "$tmp/omamac-theme.vsix" --force >> "$OMAMAC_LOG" 2>&1; then
        rm -rf "$tmp"
        ui_fail "VS Code didn't install omamac's theme. VS Code's message is in $OMAMAC_LOG"
        return 1
      fi
      rm -rf "$tmp"
    fi
    wrote=1
  fi
  # The theme step's line names VS Code already; only a change is said here.
  if vscode_user_theme; then
    ui_info "Your own VS Code theme is kept, so the theme doesn't reach VS Code."
  elif [ -n "$wrote" ]; then
    ui_ok "VS Code has the theme too."
  fi
}
