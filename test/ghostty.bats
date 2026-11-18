load helpers/common

setup() {
  setup_sandbox
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  LINE='config-file = ?~/.config/omamac/ghostty.conf'
  XDG="$HOME/.config/ghostty"
  APPSUP="$HOME/Library/Application Support/com.mitchellh.ghostty"
}

# in_lib <code>: run bash 5 code with the Ghostty steps loaded.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/lines.sh'
    source '$REPO_ROOT/lib/choices.sh'
    source '$REPO_ROOT/lib/herdr.sh'
    source '$REPO_ROOT/lib/ghostty.sh'
    source '$REPO_ROOT/lib/neovim.sh'
    source '$REPO_ROOT/lib/theme.sh'
    source '$REPO_ROOT/lib/apply.sh'
    CHOICES[theme]=tokyo-night
    $1"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "render names the launcher by absolute path" {
  in_lib "ghostty_render '$BATS_TEST_TMPDIR/out'"
  grep -qxF "command = direct:$HOME/.local/share/omamac/bin/omamac-terminal" "$BATS_TEST_TMPDIR/out"
  grep -qxF 'macos-option-as-alt = left' "$BATS_TEST_TMPDIR/out"
  ! grep -q '@' "$BATS_TEST_TMPDIR/out"
  # The theme's colours come last, so they win over the template.
  tail -n 20 "$BATS_TEST_TMPDIR/out" | grep -qxF "$(grep '^background = ' "$REPO_ROOT/themes/tokyo-night/ghostty.conf")"
}

@test "apply writes once" {
  in_lib theme_apply
  local f="$HOME/.config/omamac/ghostty.conf" before
  [ -f "$f" ]
  before=$(stat -f %m "$f")
  sleep 1
  in_lib theme_apply
  [ "$(stat -f %m "$f")" = "$before" ]
}

@test "no Ghostty config: the line creates config.ghostty" {
  in_lib ghostty_line_add
  [ "$(<"$XDG/config.ghostty")" = "$LINE" ]
}

@test "line goes in the last existing file" {
  mkdir -p "$XDG" "$APPSUP"
  echo 'font-size = 14' > "$XDG/config"
  echo 'font-size = 14' > "$APPSUP/config"
  cp "$XDG/config" "$BATS_TEST_TMPDIR/xdg.orig"
  in_lib ghostty_line_add
  [ "$(<"$APPSUP/config")" = "font-size = 14"$'\n'"$LINE" ]
  cmp "$XDG/config" "$BATS_TEST_TMPDIR/xdg.orig"
  [ ! -e "$APPSUP/config.ghostty" ]
}

@test "only config and config.ghostty exist: the line goes to config.ghostty" {
  mkdir -p "$XDG"
  echo 'font-size = 14' > "$XDG/config"
  echo 'theme = x' > "$XDG/config.ghostty"
  cp "$XDG/config" "$BATS_TEST_TMPDIR/config.orig"
  in_lib ghostty_line_add
  [ "$(<"$XDG/config.ghostty")" = "theme = x"$'\n'"$LINE" ]
  cmp "$XDG/config" "$BATS_TEST_TMPDIR/config.orig"
}

@test "line already in any file: nothing added" {
  mkdir -p "$XDG" "$APPSUP"
  echo "$LINE" > "$XDG/config"
  echo 'font-size = 14' > "$APPSUP/config.ghostty"
  cp -R "$HOME/.config" "$BATS_TEST_TMPDIR/before-cfg"
  cp "$APPSUP/config.ghostty" "$BATS_TEST_TMPDIR/before-app"
  in_lib ghostty_line_add
  diff -r "$HOME/.config" "$BATS_TEST_TMPDIR/before-cfg"
  cmp "$APPSUP/config.ghostty" "$BATS_TEST_TMPDIR/before-app"
}

@test "second install_lines changes nothing" {
  # The real function, cut out of install.sh (running install.sh would install).
  local fn
  fn=$(sed -n '/^install_lines() {/,/^}/p' "$REPO_ROOT/install.sh")
  in_lib "$fn
    install_lines >/dev/null
    cp -R '$HOME' '$BATS_TEST_TMPDIR/after-first'
    install_lines >/dev/null"
  diff -r "$HOME" "$BATS_TEST_TMPDIR/after-first"
  [ "$(grep -cF "$LINE" "$XDG/config.ghostty")" -eq 1 ]
}
