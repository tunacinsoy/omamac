load helpers/common

bats_require_minimum_version 1.5.0

setup() { setup_sandbox; }

doctor() { "$BASH5" "$REPO_ROOT/bin/omamac" doctor; }

# A Mac where every check passes.
healthy_mac() {
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install bash
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
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
}

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
  [ "$(printf '%s\n' "$output" | grep -c '^✓')" -eq 8 ]
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
  : > "$CHECKOUT/stray"
  expect_fail "Checkout is clean" "git -C ~/.local/share/omamac status"
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

@test "doctor is read-only" {
  healthy_mac
  : > "$CHECKOUT/stray"
  rm "$HOME/.zprofile"
  snap() { (cd "$HOME" && find . -type f -not -path './.local/share/omamac/.git/*' -exec shasum {} + | sort); }
  before=$(snap)
  run doctor
  [ "$status" -eq 1 ]
  [ "$before" = "$(snap)" ]
}
