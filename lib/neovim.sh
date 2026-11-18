# shellcheck shell=bash disable=SC2034 # OMAMAC_STEP is read by the caller's ERR trap
# LazyVim on a fresh Mac. Sourced after lib/paths.sh and lib/ui.sh.

# neovim_marker_write [<dest>]: omamac's lua/plugins/omamac.lua, the only writer of it.
# It loads the theme from omamac's own file, so a theme switch never rewrites it.
# Moved into place only if different, so a second run leaves its mtime alone.
neovim_marker_write() {
  local dest=${1:-$OMAMAC_NVIM_MARKER} tmp
  # Each step returns on failure itself: inside neovim_setup's && list errexit is off.
  mkdir -p "$(dirname "$dest")" || return 1
  tmp=$(mktemp "$dest.XXXXXX") || return 1
  cat > "$tmp" <<'LUA' || { rm -f "$tmp"; return 1; }
-- Set up by omamac. The theme comes from omamac's own file, which omamac theme rewrites.
local theme = vim.fn.expand("~/.config/omamac/neovim.lua")
if vim.uv.fs_stat(theme) then return dofile(theme) end
return {}
LUA
  if cmp -s "$tmp" "$dest"; then rm -f "$tmp"; else mv "$tmp" "$dest" || { rm -f "$tmp"; return 1; }; fi
}

# neovim_setup: install LazyVim when ~/.config/nvim is absent. Anything already
# there (folder or symlink) is the user's and is never written.
neovim_setup() {
  local tmp status=0
  if [ -e "$OMAMAC_NVIM_DIR" ] || [ -L "$OMAMAC_NVIM_DIR" ]; then
    [ -e "$OMAMAC_NVIM_MARKER" ] || ui_info "Your own neovim config is kept."
    return 0
  fi
  mkdir -p "$HOME/.config"
  # Leftovers of a Ctrl-C'd run (no ERR trap on signals). The name is omamac's, never the user's.
  rm -rf "$HOME"/.config/nvim.omamac.*
  # Same folder as the target, so the final mv is one atomic rename.
  tmp=$(mktemp -d "$HOME/.config/nvim.omamac.XXXXXX")
  # Handle the status here so the temp folder is removed before the caller's ERR trap fires.
  GIT_TERMINAL_PROMPT=0 ui_run "Fetching LazyVim" git clone --depth 1 "$OMAMAC_LAZYVIM_URL" "$tmp" || status=$?
  if [ "$status" -ne 0 ]; then
    rm -rf "$tmp"
    return "$status"
  fi
  # && because errexit is off inside { } ||: only the last status would count.
  # A failure here must remove the temp folder before the caller's ERR trap fires.
  {
    rm -rf "$tmp/.git" &&
    mkdir -p "$tmp/lua/plugins" &&
    neovim_marker_write "$tmp/lua/plugins/omamac.lua" &&
    mv "$tmp" "$OMAMAC_NVIM_DIR"
  } || { rm -rf "$tmp"; return 1; }
  ui_ok "neovim is set up with LazyVim"
}
