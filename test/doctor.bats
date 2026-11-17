load helpers/common

bats_require_minimum_version 1.5.0

setup() { setup_sandbox; }

doctor() { "$BASH5" "$REPO_ROOT/bin/omamac" doctor; }

# A Mac where every check passes.
healthy_mac() {
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install bash
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq
  mkdir -p "$HOME/.config/nvim/lua/plugins"
  : > "$HOME/.config/nvim/lua/plugins/omamac.lua"
  CHECKOUT="$HOME/.local/share/omamac"
  mkdir -p "$CHECKOUT" "$HOME/.config/omamac"
  git -C "$CHECKOUT" init -q
  git -C "$CHECKOUT" remote add origin https://github.com/tunacinsoy/omamac
  # shellcheck disable=SC2016 # literal lines for the user's files
  {
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)" # added by omamac' > "$HOME/.zprofile"
    echo '[[ -r ~/.config/omamac/zshrc ]] && source ~/.config/omamac/zshrc # added by omamac' > "$HOME/.zshrc"
  }
  : > "$HOME/.config/omamac/zshrc"
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  # omamac's herdr file and its copy, and the mise drop-in, written the way install writes them.
  omamac_lib herdr_config_apply
  omamac_lib languages_write_dropin
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/mise"
}

# omamac_lib <code>: run code with omamac's libraries and the saved answers loaded.
omamac_lib() {
  "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    for lib in paths ui questions choices herdr languages apply; do source \"$REPO_ROOT/lib/\$lib.sh\"; done
    choices_load \"\$OMAMAC_CHOICES_FILE\"
    $1" >/dev/null
}

# choose <key> <value>: save that answer, and write the drop-in that matches it.
choose() {
  sed -i '' "s/^$1=.*/$1=$2/" "$CHOICES_FILE"
  omamac_lib languages_write_dropin
}

# A tool fake-mise has installed.
mise_has() { touch "$OMAMAC_TEST_BREW_PREFIX/mise/$1"; }

snap() { (cd "$HOME" && find . -type f -not -path './.local/share/omamac/.git/*' -exec shasum {} + | sort); }

# expect_fail <what> <fix>: doctor exits 1 and prints a ✗ line with the fix.
expect_fail() {
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ $1"* ]]
  [[ "$output" == *"Fix: "*"$2"* ]]
}

@test "healthy Mac: every check passes" {
  healthy_mac
  run doctor
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^✓')" -eq 14 ]
}

@test "Homebrew missing" {
  healthy_mac
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
  expect_fail "Homebrew" "Run the one-liner"
}

@test "Homebrew at /usr/local" {
  healthy_mac
  : > "$BATS_TEST_TMPDIR/usr-local-brew"
  export OMAMAC_TEST_USR_LOCAL_BREW="$BATS_TEST_TMPDIR/usr-local-brew"
  expect_fail "Homebrew" "https://docs.brew.sh/Installation"
}

@test "bash is the old one" {
  healthy_mac
  ln -sf /bin/bash "$OMAMAC_TEST_BREW_PREFIX/bin/bash"
  expect_fail "bash 5" "brew install bash"
}

@test "gum not installed" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Cellar/gum"
  expect_fail "gum" "brew install gum"
}

@test "gum not installed and none on PATH: plain ✗ lines" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Cellar/gum" "$OMAMAC_TEST_BREW_PREFIX/bin/gum" "$STUB_DIR/gum"
  PATH=/usr/bin:/bin expect_fail "gum" "brew install gum"
}

@test "Homebrew line missing and no brew or gum on PATH" {
  healthy_mac
  : > "$HOME/.zprofile"
  rm "$STUB_DIR/gum"
  PATH=/usr/bin:/bin expect_fail "Homebrew line" "Run the one-liner again"
}

@test "checkout missing" {
  healthy_mac
  rm -rf "$HOME/.local/share/omamac"
  expect_fail "Checkout" "Run the one-liner"
}

@test "checkout with another origin" {
  healthy_mac
  git -C "$CHECKOUT" remote set-url origin https://example.com/other
  expect_fail "Checkout" "Run the one-liner"
}

@test "checkout has local changes" {
  healthy_mac
  echo a > "$CHECKOUT/tracked"
  git -C "$CHECKOUT" add tracked
  git -C "$CHECKOUT" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m tracked
  echo b > "$CHECKOUT/tracked"
  expect_fail "Checkout is clean" "git -C ~/.local/share/omamac status"
}

@test "an untracked file in the checkout still passes" {
  healthy_mac
  : > "$CHECKOUT/.DS_Store"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Checkout is clean"* ]]
}

@test "Homebrew line missing" {
  healthy_mac
  : > "$HOME/.zprofile"
  expect_fail "Homebrew line" "Run the one-liner again"
}

@test "user's own brew shellenv line is enough" {
  healthy_mac
  echo 'eval "$(/usr/bin/env brew shellenv)"' > "$HOME/.zprofile"
  run doctor
  [ "$status" -eq 0 ]
}

@test "omamac line missing" {
  healthy_mac
  : > "$HOME/.zshrc"
  expect_fail "omamac line" "Run the one-liner again"
}

@test "omamac's zsh file missing" {
  healthy_mac
  rm "$HOME/.config/omamac/zshrc"
  expect_fail "omamac's zsh file" "Run the one-liner again"
}

@test "core formula missing" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Cellar/eza"
  expect_fail "Core tools" "brew install eza"
}

@test "core formulas missing are all named" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Cellar/eza" "$OMAMAC_TEST_BREW_PREFIX/Cellar/bat"
  expect_fail "Core tools" "brew install eza bat"
}

@test "core check is skipped when Homebrew is missing" {
  healthy_mac
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ℹ Core tools — skipped"* ]]
  [[ "$output" == *"neovim config"* ]]
}

@test "core check is skipped when brew can't list" {
  healthy_mac
  T_BREW_LIST_FAIL=1 run doctor
  [[ "$output" == *"ℹ Core tools — skipped"* ]]
}

@test "user's own neovim config is kept" {
  healthy_mac
  rm "$HOME/.config/nvim/lua/plugins/omamac.lua"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ neovim config — your own neovim config is kept"* ]]
}

@test "a dangling neovim symlink counts as the user's own" {
  healthy_mac
  rm -r "$HOME/.config/nvim"
  ln -s "$BATS_TEST_TMPDIR/nowhere" "$HOME/.config/nvim"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ neovim config"* ]]
}

@test "neovim config missing" {
  healthy_mac
  rm -r "$HOME/.config/nvim"
  expect_fail "neovim config" "Run the one-liner again"
}

@test "herdr: omamac's config" {
  healthy_mac
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ herdr config"* ]]
}

@test "herdr: the user's own config" {
  healthy_mac
  mkdir -p "$HOME/.config/herdr"
  echo mine > "$HOME/.config/herdr/config.toml"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ herdr config — your own herdr config is kept, so omamac's key bindings and themes don't reach herdr"* ]]
}

@test "herdr: herdr's own onboarding file is not the user's" {
  healthy_mac
  mkdir -p "$HOME/.config/herdr"
  printf 'onboarding = false\n' > "$HOME/.config/herdr/config.toml"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ herdr config"* ]]
}

@test "herdr: changed in herdr is still omamac's" {
  healthy_mac
  echo '# changed' >> "$HOME/.config/omamac/herdr.toml"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ herdr config"* ]]
}

@test "herdr: omamac's file missing" {
  healthy_mac
  rm "$HOME/.config/omamac/herdr.toml"
  expect_fail "herdr config" "omamac update"
  [[ "$output" == *"~/.config/omamac/herdr.toml is missing"* ]]
}

@test "the report alone changes nothing" {
  healthy_mac
  : > "$CHECKOUT/stray"
  rm "$HOME/.zprofile"
  before=$(snap)
  run doctor
  [ "$status" -eq 1 ]
  [ "$before" = "$(snap)" ]
}

@test "saved answers missing" {
  healthy_mac
  rm "$CHOICES_FILE"
  expect_fail "Saved answers" "Run the one-liner"
}

@test "saved answers invalid" {
  healthy_mac
  echo 'colour=red' >> "$CHOICES_FILE"
  expect_fail "Saved answers" "Delete that line"
  [[ "$output" == *"line 18"* ]]
}

@test "saved answers incomplete" {
  healthy_mac
  sed -i '' '/^docker=/d' "$CHOICES_FILE"
  expect_fail "Saved answers" "it asks only that one"
}

@test "git status takes no lock" {
  healthy_mac
  # shellcheck disable=SC2016 # the stub expands it
  stub git 'echo "locks=${GIT_OPTIONAL_LOCKS:-unset}" >> "$STUB_LOG"; exec /usr/bin/git "$@"'
  run doctor
  [ "$status" -eq 0 ]
  [ "$(grep -A1 'status --porcelain' "$STUB_LOG" | sed -n 2p)" = "locks=0" ]
}

@test "mise drop-in missing" {
  healthy_mac
  rm "$HOME/.config/mise/conf.d/omamac.toml"
  expect_fail "mise drop-in" "omamac update"
  [[ "$output" == *"~/.config/mise/conf.d/omamac.toml doesn't match your answers"* ]]
}

@test "mise drop-in edited" {
  healthy_mac
  echo 'go = "latest"' >> "$HOME/.config/mise/conf.d/omamac.toml"
  expect_fail "mise drop-in" "omamac update"
}

@test "without saved answers the drop-in and chosen tools are skipped" {
  healthy_mac
  rm "$CHOICES_FILE"
  run doctor
  [[ "$output" == *"ℹ mise drop-in — skipped, your saved answers can't be read"* ]]
  [[ "$output" == *"ℹ Languages and cloud CLIs — skipped, your saved answers can't be read"* ]]
}

@test "a chosen language gone: ✗ naming it" {
  healthy_mac
  choose languages go
  gum_answers leave
  expect_fail "Go — you chose it, but mise no longer has it" \
    "omamac update puts it back; omamac uninstall go drops it"
}

@test "a language is gone when one of its tools is" {
  healthy_mac
  choose languages elixir
  mise_has erlang
  gum_answers leave
  expect_fail "Elixir — you chose it" "omamac uninstall elixir drops it"
}

@test "a chosen CLI gone: ✗" {
  healthy_mac
  choose cloud_clis gh
  gum_answers leave
  expect_fail "GitHub CLI — you chose it, but Homebrew no longer has it" \
    "omamac update puts it back; omamac uninstall gh drops it"
}

@test "chosen tools there: ✓ and no prompt" {
  healthy_mac
  choose languages go
  choose cloud_clis gh
  mise_has go
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/Cellar/gh"
  gum_answers
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Languages and cloud CLIs"* ]]
  [ -z "$(grep '^gum' "$STUB_LOG")" ]
}

@test "mise missing: chosen languages skipped" {
  healthy_mac
  choose languages go
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  run doctor
  [[ "$output" == *"ℹ Languages and cloud CLIs — skipped, mise can't list what's installed"* ]]
  [[ "$output" != *"✗ Go"* ]]
}

@test "mise fails: chosen languages skipped" {
  healthy_mac
  choose languages go
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  printf '#!/bin/bash\nexit 1\n' > "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  chmod +x "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  run doctor
  [[ "$output" == *"ℹ Languages and cloud CLIs — skipped, mise can't list what's installed"* ]]
  [[ "$output" != *"✗ Go"* ]]
}

@test "Homebrew can't list: chosen CLIs skipped" {
  healthy_mac
  choose cloud_clis gh
  T_BREW_LIST_FAIL=1 run doctor
  [[ "$output" == *"ℹ Languages and cloud CLIs — skipped, Homebrew can't list what's installed"* ]]
  [[ "$output" != *"✗ GitHub CLI"* ]]
}

@test "Leave it: nothing changes" {
  healthy_mac
  choose languages go
  gum_answers leave
  before=$(snap)
  run doctor
  [ "$status" -eq 1 ]
  grep -qx 'gum choose --header Go is gone. What should omamac do? --label-delimiter=: Leave it:leave Reinstall it:reinstall Remove it from my answers:drop' "$STUB_LOG"
  [ "$before" = "$(snap)" ]
  [ -z "$(grep '^mise install' "$STUB_LOG")" ]
}

@test "Reinstall it: mise install go runs" {
  healthy_mac
  choose languages go
  gum_answers reinstall
  run doctor
  [ "$status" -eq 1 ]
  grep -qx 'mise install go' "$STUB_LOG"
  [ -e "$OMAMAC_TEST_BREW_PREFIX/mise/go" ]
  ls "$HOME/.local/state/omamac/logs/"*.log
}

@test "Reinstall it: brew install gh runs" {
  healthy_mac
  choose cloud_clis gh
  gum_answers reinstall
  run doctor
  [ "$status" -eq 1 ]
  grep -qx 'brew install gh' "$STUB_LOG"
}

@test "Reinstall it fails: doctor says so and asks about the next one" {
  healthy_mac
  choose languages go
  choose cloud_clis gh
  gum_answers reinstall leave
  T_MISE_FAIL=1 run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac couldn't reinstall Go"* ]]
  [ "$(grep -c '^gum choose' "$STUB_LOG")" -eq 2 ]
}

@test "Remove it from my answers: choices and drop-in lose it" {
  healthy_mac
  choose languages "go node"
  mise_has node
  gum_answers drop
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✓ Go is dropped from your answers"* ]]
  grep -qx 'languages=node' "$CHOICES_FILE"
  [ -z "$(grep '^go ' "$HOME/.config/mise/conf.d/omamac.toml")" ]
  grep -qx 'node = "latest"' "$HOME/.config/mise/conf.d/omamac.toml"
  run doctor
  [ "$status" -eq 0 ]
}

@test "Remove it from my answers: a CLI" {
  healthy_mac
  choose cloud_clis "aws gh"
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/Cellar/awscli"
  gum_answers drop
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✓ GitHub CLI is dropped from your answers"* ]]
  grep -qx 'cloud_clis=aws' "$CHOICES_FILE"
}

@test "two gone: asked about each" {
  healthy_mac
  choose languages go
  choose cloud_clis gh
  gum_answers leave leave
  run doctor
  [ "$status" -eq 1 ]
  [ "$(grep -c '^gum choose' "$STUB_LOG")" -eq 2 ]
}

@test "Ctrl-C at the offer stops" {
  healthy_mac
  choose languages go
  gum_answers "exit 130"
  run doctor
  [ "$status" -eq 130 ]
  [[ "$output" == *"Stopped. Nothing else was changed."* ]]
}

@test "no terminal: no offer" {
  healthy_mac
  choose languages go
  export OMAMAC_TEST_TTY="$BATS_TEST_TMPDIR/no-tty"
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ Go"* ]]
  [ -z "$(grep '^gum' "$STUB_LOG")" ]
}

@test "a terminal that can't be opened: no offer" {
  healthy_mac
  choose languages go
  unopenable_tty "$OMAMAC_TEST_TTY"
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ Go"* ]]
  [[ "$output" != *"couldn't ask"* ]]
  [ -z "$(grep '^gum' "$STUB_LOG")" ]
}

@test "nothing gone: no prompt" {
  healthy_mac
  gum_answers
  run doctor
  [ "$status" -eq 0 ]
  [ -z "$(grep '^gum' "$STUB_LOG")" ]
}
