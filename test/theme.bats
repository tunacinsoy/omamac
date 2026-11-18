load helpers/common

setup() {
  setup_sandbox
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  OM="$HOME/.config/omamac"
  IDS='catppuccin dracula everforest gruvbox kanagawa matte-black nord one-dark osaka-jade ristretto rose-pine solarized tokyo-night'
  MARKER="$HOME/.config/nvim/lua/plugins/omamac.lua"
}

# in_lib <code>: run bash 5 code with the theme step loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/choices.sh'
    source '$REPO_ROOT/lib/herdr.sh'
    source '$REPO_ROOT/lib/ghostty.sh'
    source '$REPO_ROOT/lib/neovim.sh'
    source '$REPO_ROOT/lib/theme.sh'
    source '$REPO_ROOT/lib/apply.sh'
    $1"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# apply <id>: theme_apply with that theme chosen.
apply() { in_lib "CHOICES[theme]=$1; theme_apply"; }

# stamp: every theme file's mtime, in a fixed order.
stamp() { (cd "$OM" && find ghostty.conf herdr.toml starship.toml btop.conf btop-themes neovim.lua -type f -exec stat -f '%N %m' {} + | sort); }

@test "herdr names" {
  local id want
  for id in $IDS; do
    case $id in
      rose-pine) want=rose-pine-dawn ;;
      everforest | matte-black | osaka-jade | ristretto) want=terminal ;;
      *) want=$id ;;
    esac
    in_lib "theme_herdr_name $id"
    [ "$output" = "$want" ]
  done
}

@test "apply writes the six files for the chosen theme" {
  apply dracula
  tail -n 20 "$OM/ghostty.conf" | grep -qxF "$(grep '^background = ' "$REPO_ROOT/themes/dracula/ghostty.conf")"
  grep -qxF "command = direct:$HOME/.local/share/omamac/bin/omamac-terminal" "$OM/ghostty.conf"
  grep -qxF 'name = "dracula"' "$OM/herdr.toml"
  cmp "$OM/starship.toml" "$REPO_ROOT/themes/dracula/starship.toml"
  [ "$(<"$OM/btop.conf")" = 'color_theme = "dracula"' ]
  [ "$(ls "$OM/btop-themes")" = dracula.theme ]
  cmp "$OM/btop-themes/dracula.theme" "$REPO_ROOT/themes/dracula/btop.theme"
  cmp "$OM/neovim.lua" "$REPO_ROOT/themes/dracula/neovim.lua"
  [[ "$output" == *"Theme files are in place"* ]]
}

@test "rose-pine: herdr gets rose-pine-dawn; ristretto: terminal" {
  apply rose-pine
  grep -qxF 'name = "rose-pine-dawn"' "$OM/herdr.toml"
  apply ristretto
  grep -qxF 'name = "terminal"' "$OM/herdr.toml"
}

@test "switching removes the old btop theme file" {
  apply dracula
  apply nord
  [ "$(ls "$OM/btop-themes")" = nord.theme ]
  [ "$(<"$OM/btop.conf")" = 'color_theme = "nord"' ]
}

@test "second apply changes nothing" {
  apply dracula
  local before
  before=$(stamp)
  sleep 1.1
  apply dracula
  [ "$(stamp)" = "$before" ]
  [ -z "$(find "$OM" -name '*.??????' -not -name '*.theme' -not -name '*.conf' -not -name '*.toml' -not -name '*.lua')" ]
}

@test "first run with Catppuccin: marker and theme in place, second run changes nothing" {
  in_lib "CHOICES[theme]=catppuccin; theme_apply; neovim_setup"
  local want
  want=$(printf '%s\n' \
    '-- Set up by omamac. The theme comes from omamac'"'"'s own file, which omamac theme rewrites.' \
    'local theme = vim.fn.expand("~/.config/omamac/neovim.lua")' \
    'if vim.uv.fs_stat(theme) then return dofile(theme) end' \
    'return {}')
  [ "$(<"$MARKER")" = "$want" ]
  cmp "$OM/neovim.lua" "$REPO_ROOT/themes/catppuccin/neovim.lua"
  local before
  before="$(stamp) $(stat -f %m "$MARKER")"
  sleep 1.1
  in_lib "CHOICES[theme]=catppuccin; theme_apply; neovim_setup; theme_apply"
  [ "$(stamp) $(stat -f %m "$MARKER")" = "$before" ]
}

@test "Phase 3's marker is upgraded" {
  mkdir -p "$(dirname "$MARKER")"
  printf -- '-- Set up by omamac.\nreturn {}\n' > "$MARKER"
  apply dracula
  grep -qF 'dofile(theme)' "$MARKER"
}

@test "a user folder without the marker gets nothing written" {
  mkdir -p "$HOME/.config/nvim"
  echo mine > "$HOME/.config/nvim/init.lua"
  apply dracula
  [ "$(ls -A "$HOME/.config/nvim")" = init.lua ]
}
