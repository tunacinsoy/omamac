load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install bash gum
  export TMPDIR="$BATS_TEST_TMPDIR"
  OM="$HOME/.config/omamac"
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  stub ps
  stub herdr
}

teardown() { chmod -R u+w "$HOME" 2>/dev/null || true; }

# omamac_theme [<arg>…]: omamac theme, only ever in the sandbox, never on the real Mac.
omamac_theme() {
  if [ -z "${BATS_TEST_TMPDIR:-}" ] || [[ $HOME != "$BATS_TEST_TMPDIR"/* ]]; then
    echo "theme_cmd.bats: HOME isn't the sandbox; not running omamac theme" >&2
    return 1
  fi
  "$BASH5" "$REPO_ROOT/bin/omamac" theme "$@"
}

# stamp: every omamac theme file's mtime.
stamp() { (cd "$OM" && find . -type f -exec stat -f '%N %m' {} + | sort); }

@test "theme nord reaches VS Code" {
  local bin="$OMAMAC_TEST_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$bin"
  ln -sf "$HELPERS_DIR/fake-code" "$bin/code"
  run omamac_theme nord
  [ "$status" -eq 0 ]
  cmp "$HOME/.vscode/extensions/omamac.omamac-theme-1.0.0/themes/omamac.json" "$REPO_ROOT/themes/nord/vscode.json"
  [[ "$output" == *"What's running shows it now, an open VS Code too; neovim the next time it opens."* ]]
}

@test "theme with the user's own VS Code theme doesn't promise VS Code" {
  local bin="$OMAMAC_TEST_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$bin"
  ln -sf "$HELPERS_DIR/fake-code" "$bin/code"
  mkdir -p "$HOME/Library/Application Support/Code/User"
  echo '{ "workbench.colorTheme": "Solarized Light" }' > "$HOME/Library/Application Support/Code/User/settings.json"
  run omamac_theme nord
  [ "$status" -eq 0 ]
  [[ "$output" == *"What's running shows it now; neovim the next time it opens."* ]]
}

@test "theme dracula: saved, applied, reloaded, summary" {
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  grep -qx 'theme=dracula' "$CHOICES_FILE"
  cmp "$OM/starship.toml" "$REPO_ROOT/themes/dracula/starship.toml"
  [ "$(<"$OM/btop.conf")" = 'color_theme = "dracula"' ]
  cmp "$OM/neovim.lua" "$REPO_ROOT/themes/dracula/neovim.lua"
  grep -qx 'herdr server reload-config' "$STUB_LOG"
  [[ "$output" == *"✓ Theme: Dracula, in "* ]]
}

# listener <file>: a process that writes "reloaded" to <file> on SIGUSR2; prints its pid.
listener() {
  bash -c 'trap "echo reloaded > \"$1\"; exit 0" USR2; while :; do sleep 0.1; done' _ "$1" > /dev/null 2>&1 &
  echo $!
}

@test "theme reloads Ghostty and btop by their program name, as ps lists them" {
  local g b other
  g=$(listener "$BATS_TEST_TMPDIR/ghostty")
  b=$(listener "$BATS_TEST_TMPDIR/btop")
  other=$(listener "$BATS_TEST_TMPDIR/other")
  stub ps "printf '%s\\n' '  $g /Applications/Ghostty.app/Contents/MacOS/ghostty' '  $b /opt/homebrew/bin/btop' '  $other /usr/bin/ghostty-helper'"
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  local i
  for i in $(seq 50); do [ -e "$BATS_TEST_TMPDIR/ghostty" ] && [ -e "$BATS_TEST_TMPDIR/btop" ] && break; sleep 0.1; done
  kill "$other" 2> /dev/null || true
  [ "$(cat "$BATS_TEST_TMPDIR/ghostty")" = reloaded ]
  [ "$(cat "$BATS_TEST_TMPDIR/btop")" = reloaded ]
  [ ! -e "$BATS_TEST_TMPDIR/other" ]
}

@test "own starship config: kept, said so, summary is honest" {
  mkdir -p "$HOME/.config"
  echo mine > "$HOME/.config/starship.toml"
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  [[ "$output" == *"Your own starship config is kept, so the theme doesn't reach the prompt."* ]]
  [[ "$output" == *"✓ Theme: Dracula, in Ghostty, herdr, btop and neovim"* ]]
  [[ "$output" == *"What's running shows it now; neovim the next time it opens."* ]]
}

@test "own btop and neovim configs: said so" {
  mkdir -p "$HOME/.config/btop" "$HOME/.config/nvim"
  echo mine > "$HOME/.config/btop/btop.conf"
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  [[ "$output" == *"Your own btop config is kept, so the theme doesn't reach btop."* ]]
  [[ "$output" == *"Your own neovim config is kept, so the theme doesn't reach neovim."* ]]
}

@test "own starship and btop files stay byte-identical" {
  mkdir -p "$HOME/.config/btop"
  echo mine > "$HOME/.config/starship.toml"
  echo mine > "$HOME/.config/btop/btop.conf"
  local before after
  before=$(stat -f '%m' "$HOME/.config/starship.toml" "$HOME/.config/btop/btop.conf"; cat "$HOME/.config/starship.toml" "$HOME/.config/btop/btop.conf")
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  after=$(stat -f '%m' "$HOME/.config/starship.toml" "$HOME/.config/btop/btop.conf"; cat "$HOME/.config/starship.toml" "$HOME/.config/btop/btop.conf")
  [ "$after" = "$before" ]
}

@test "nothing running: still exit 0" {
  stub ps 'exit 1'
  stub herdr 'echo "no server" >&2; exit 1'
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Theme: Dracula, in "* ]]
  [[ "$output" != *"no server"* ]]
}

@test "no id asks; picking one applies it" {
  gum_answers nord
  run omamac_theme
  [ "$status" -eq 0 ]
  grep -qx 'theme=nord' "$CHOICES_FILE"
  [[ "$output" == *"✓ Theme: Nord, in "* ]]
  grep -q '^gum choose --header Which theme?' "$STUB_LOG"
}

@test "unknown id" {
  run omamac_theme bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"bogus"* ]]
  for id in catppuccin dracula everforest gruvbox kanagawa matte-black nord one-dark osaka-jade ristretto rose-pine solarized tokyo-night; do
    [[ "$output" == *"$id"* ]]
  done
  grep -qx 'theme=tokyo-night' "$CHOICES_FILE"
}

@test "more than one argument: usage, exit 2" {
  run omamac_theme nord dracula
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: omamac"* ]]
}

@test "same theme again changes nothing" {
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  before=$(stamp)
  sleep 1
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  [ "$(stamp)" = "$before" ]
}

@test "same theme again puts back a missing file" {
  run omamac_theme dracula
  rm "$OM/starship.toml"
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  cmp "$OM/starship.toml" "$REPO_ROOT/themes/dracula/starship.toml"
}

@test "a failed write names the step" {
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  chmod a-w "$OM"
  run omamac_theme nord
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while"* ]]
  [[ "$output" == *"omamac theme again"* ]]
}

# The terminal look (#46): three rows, each naming only what the theme reaches.

@test "terminal look: Theme, Now and Next open; VS Code changes now" {
  local bin="$OMAMAC_TEST_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$bin"
  ln -sf "$HELPERS_DIR/fake-code" "$bin/code"
  terminal_look
  run omamac_theme nord
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | uncoloured)" = "  ✓ Theme           Nord
  ✓ Now             Ghostty, herdr, btop, the prompt, VS Code
  ℹ Next open       neovim" ]
  cmp "$HOME/.vscode/extensions/omamac.omamac-theme-1.0.0/themes/omamac.json" "$REPO_ROOT/themes/nord/vscode.json"
}

@test "terminal look: no VS Code, or the user's own VS Code theme, and Now leaves it out" {
  terminal_look
  run omamac_theme nord
  [ "$(printf '%s\n' "$output" | uncoloured | sed -n 2p)" = "  ✓ Now             Ghostty, herdr, btop, the prompt" ]
  local bin="$OMAMAC_TEST_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$bin" "$HOME/Library/Application Support/Code/User"
  ln -sf "$HELPERS_DIR/fake-code" "$bin/code"
  echo '{ "workbench.colorTheme": "Solarized Light" }' > "$HOME/Library/Application Support/Code/User/settings.json"
  run omamac_theme nord
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | uncoloured | sed -n 2p)" = "  ✓ Now             Ghostty, herdr, btop, the prompt" ]
}

@test "terminal look: the user's own btop, starship and neovim configs aren't named; no Next open row" {
  mkdir -p "$HOME/.config/btop" "$HOME/.config/nvim"
  echo mine > "$HOME/.config/btop/btop.conf"
  echo mine > "$HOME/.config/starship.toml"
  terminal_look
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | uncoloured)" = "  ✓ Theme           Dracula
  ✓ Now             Ghostty, herdr" ]
}

@test "terminal look: a failed write stops in the Stopped box" {
  run omamac_theme dracula
  chmod a-w "$OM"
  terminal_look
  run omamac_theme nord
  [ "$status" -eq 1 ]
  # The path is long in the sandbox, so it wraps inside the box.
  [[ "$(printf "%s\n" "$output" | uncoloured)" == *"╭ Stopped"*"│ While  writing "*"│ Fix    run omamac theme again"* ]]
}

@test "theme switch keeps the size" {
  mkdir -p "$HOME/.local/state/omamac"
  echo 16 > "$HOME/.local/state/omamac/font-size"
  run omamac_theme nord
  [ "$status" -eq 0 ]
  grep -qx 'font-size = 16' "$OM/ghostty.conf"
}
