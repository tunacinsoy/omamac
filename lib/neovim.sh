# shellcheck shell=bash
# LazyVim on a fresh Mac. Sourced after lib/paths.sh and lib/ui.sh.

# neovim_setup: install LazyVim when ~/.config/nvim is absent. Anything already
# there (folder or symlink) is the user's and is never written.
neovim_setup() {
  local tmp status=0
  if [ -e "$OMAMAC_NVIM_DIR" ] || [ -L "$OMAMAC_NVIM_DIR" ]; then
    [ -e "$OMAMAC_NVIM_MARKER" ] || ui_info "Your own neovim config is kept."
    return 0
  fi
  mkdir -p "$HOME/.config"
  # Same folder as the target, so the final mv is one atomic rename.
  tmp=$(mktemp -d "$HOME/.config/nvim.omamac.XXXXXX")
  # Handle the status here so the temp folder is removed before the caller's ERR trap fires.
  GIT_TERMINAL_PROMPT=0 ui_run "Fetching LazyVim" git clone --depth 1 "$OMAMAC_LAZYVIM_URL" "$tmp" || status=$?
  if [ "$status" -ne 0 ]; then
    rm -rf "$tmp"
    return "$status"
  fi
  rm -rf "$tmp/.git"
  mkdir -p "$tmp/lua/plugins"
  printf -- '-- Set up by omamac.\nreturn {}\n' > "$tmp/lua/plugins/omamac.lua"
  mv "$tmp" "$OMAMAC_NVIM_DIR"
  ui_ok "neovim is set up with LazyVim"
}
