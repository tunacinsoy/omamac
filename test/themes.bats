load helpers/common

setup() { setup_sandbox; }

# ids: the theme answers, sorted.
ids() {
  "$BASH5" -c "source '$REPO_ROOT/lib/paths.sh'; source '$REPO_ROOT/lib/questions.sh'; question_values theme" | sort
}

@test "one folder per theme answer" {
  run bash -c "cd '$REPO_ROOT/themes' && printf '%s\n' */ | tr -d / | sort"
  [ "$status" -eq 0 ]
  [ "$output" = "$(ids)" ]
}

@test "each theme has its five files" {
  local id f
  for id in $(ids); do
    for f in ghostty.conf btop.theme neovim.lua starship.toml vscode.json; do
      [ -s "$REPO_ROOT/themes/$id/$f" ] || { echo "missing or empty: $id/$f"; return 1; }
    done
  done
}

@test "ghostty.conf is 20 colour lines" {
  local id file key n keys=(background foreground cursor-color selection-background) i
  for i in $(seq 0 15); do keys+=("palette = $i="); done
  for id in $(ids); do
    file="$REPO_ROOT/themes/$id/ghostty.conf"
    for key in "${keys[@]}"; do
      n=$(grep -c "^$key *=\{0,1\} *#[0-9a-fA-F]\{6\}$" "$file" || true)
      [ "$n" -eq 1 ] || { echo "$id: '$key' found $n times"; return 1; }
    done
    # Nothing else but comments.
    n=$(grep -vc '^#' "$file")
    [ "$n" -eq 20 ] || { echo "$id: $n non-comment lines"; return 1; }
  done
}

@test "vscode.json: valid, named omamac, with Ghostty's background" {
  local id file want
  for id in $(ids); do
    file="$REPO_ROOT/themes/$id/vscode.json"
    jq -e '.name == "omamac" and (.type == "dark" or .type == "light") and (.colors | length > 0)' "$file" >/dev/null ||
      { echo "$id: not a VS Code theme named omamac"; return 1; }
    want=$(sed -n 's/^background = //p' "$REPO_ROOT/themes/$id/ghostty.conf" | tr 'A-F' 'a-f')
    [ "$(jq -r '.colors["editor.background"]' "$file" | tr 'A-F' 'a-f')" = "$want" ] ||
      { echo "$id: editor background isn't Ghostty's $want"; return 1; }
  done
}

@test "rose-pine is the one light theme" {
  run bash -c "cd '$REPO_ROOT/themes' && jq -r 'select(.type == \"light\") | input_filename' */vscode.json"
  [ "$status" -eq 0 ]
  [ "$output" = rose-pine/vscode.json ]
}

@test "starship palette names its theme" {
  local id file x
  for id in $(ids); do
    file="$REPO_ROOT/themes/$id/starship.toml"
    x=$(sed -n 's/^palette = "\(.*\)"$/\1/p' "$file")
    [ -n "$x" ] || { echo "$id: no palette line"; return 1; }
    grep -qxF "[palettes.$x]" "$file" || { echo "$id: no [palettes.$x]"; return 1; }
  done
}

@test "licence comes along" {
  [ -f "$REPO_ROOT/themes/LICENSE.omarchy" ]
}
