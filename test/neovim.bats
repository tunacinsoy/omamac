load helpers/common

setup() {
  setup_sandbox
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
}

# in_lib <code>: run bash 5 code with neovim_setup loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/neovim.sh'
    $1"
}

@test "fresh: clones the starter, drops .git, adds the marker" {
  in_lib neovim_setup
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/nvim/init.lua" ]
  [ ! -e "$HOME/.config/nvim/.git" ]
  [ "$(cat "$HOME/.config/nvim/lua/plugins/omamac.lua")" = "$(printf -- '-- Set up by omamac.\nreturn {}')" ]
  [[ "$output" == *"neovim is set up with LazyVim"* ]]
  [ -z "$(ls -d "$HOME"/.config/nvim.omamac.* 2>/dev/null)" ]
}

@test "existing folder: untouched, says so" {
  mkdir -p "$HOME/.config/nvim"
  echo mine > "$HOME/.config/nvim/init.lua"
  in_lib neovim_setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Your own neovim config is kept."* ]]
  [ "$(ls -A "$HOME/.config/nvim")" = "init.lua" ]
  [ "$(cat "$HOME/.config/nvim/init.lua")" = mine ]
  [ -z "$(ls -d "$HOME"/.config/nvim.omamac.* 2>/dev/null)" ]
}

@test "omamac's own folder: no message on a re-run" {
  in_lib neovim_setup
  in_lib neovim_setup
  [ "$status" -eq 0 ]
  [[ "$output" != *"kept"* ]]
}

@test "a symlink counts as the user's" {
  mkdir -p "$HOME/.config" "$HOME/dotfiles/nvim"
  ln -s "$HOME/dotfiles/nvim" "$HOME/.config/nvim"
  in_lib neovim_setup
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/nvim" ]
  [ "$(readlink "$HOME/.config/nvim")" = "$HOME/dotfiles/nvim" ]
  [ -z "$(ls -A "$HOME/dotfiles/nvim")" ]
  [ -z "$(ls -d "$HOME"/.config/nvim.omamac.* 2>/dev/null)" ]
}

@test "a dangling symlink counts as the user's" {
  mkdir -p "$HOME/.config"
  ln -s "$HOME/nowhere" "$HOME/.config/nvim"
  in_lib neovim_setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Your own neovim config is kept."* ]]
  [ -L "$HOME/.config/nvim" ]
  [ ! -e "$HOME/nowhere" ]
  [ -z "$(ls -d "$HOME"/.config/nvim.omamac.* 2>/dev/null)" ]
}

@test "a failed clone leaves nothing" {
  export OMAMAC_TEST_LAZYVIM_URL="file://$BATS_TEST_TMPDIR/missing"
  in_lib neovim_setup
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.config/nvim" ]
  [ -z "$(ls -d "$HOME"/.config/nvim.omamac.* 2>/dev/null)" ]
}

@test "a failed marker write leaves nothing" {
  local repo="$BATS_TEST_TMPDIR/bad-starter"
  mkdir -p "$repo/lua"
  echo x > "$repo/lua/plugins"   # a file where the folder must go
  git -C "$repo" init -q
  git -C "$repo" add -A
  git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m bad
  export OMAMAC_TEST_LAZYVIM_URL="file://$repo"
  in_lib neovim_setup
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.config/nvim" ]
  [ -z "$(ls -d "$HOME"/.config/nvim.omamac.* 2>/dev/null)" ]
}
