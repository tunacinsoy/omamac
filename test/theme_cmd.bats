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
  stub pkill
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

@test "theme dracula: saved, applied, reloaded, summary" {
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  grep -qx 'theme=dracula' "$CHOICES_FILE"
  cmp "$OM/starship.toml" "$REPO_ROOT/themes/dracula/starship.toml"
  [ "$(<"$OM/btop.conf")" = 'color_theme = "dracula"' ]
  cmp "$OM/neovim.lua" "$REPO_ROOT/themes/dracula/neovim.lua"
  grep -qx 'pkill -USR2 -x ghostty' "$STUB_LOG"
  grep -qx 'herdr server reload-config' "$STUB_LOG"
  grep -qx 'pkill -USR2 -x btop' "$STUB_LOG"
  [[ "$output" == *"Theme: Dracula."* ]]
}

@test "own starship config: kept, said so, summary is honest" {
  mkdir -p "$HOME/.config"
  echo mine > "$HOME/.config/starship.toml"
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  [[ "$output" == *"Your own starship config is kept, so the theme doesn't reach the prompt."* ]]
  [[ "$output" == *"Theme: Dracula. What's running shows it now; neovim the next time it opens."* ]]
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
  stub pkill 'exit 1'
  stub herdr 'echo "no server" >&2; exit 1'
  run omamac_theme dracula
  [ "$status" -eq 0 ]
  [[ "$output" == *"Theme: Dracula."* ]]
  [[ "$output" != *"no server"* ]]
}

@test "no id asks; picking one applies it" {
  gum_answers nord
  run omamac_theme
  [ "$status" -eq 0 ]
  grep -qx 'theme=nord' "$CHOICES_FILE"
  [[ "$output" == *"Theme: Nord."* ]]
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
