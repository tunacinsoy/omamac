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
  omamac_lib theme_apply
  omamac_lib languages_write_dropin
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/mise"
  healthy_ghostty
}

# omamac_lib <code>: run code with omamac's libraries and the saved answers loaded.
omamac_lib() {
  "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    for lib in paths ui questions choices herdr ghostty neovim theme languages apply; do source \"$REPO_ROOT/lib/\$lib.sh\"; done
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
  [ "$(printf '%s\n' "$output" | grep -c '^✓')" -eq 21 ]
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
  gum_answers leave
  rm "$HOME/.config/nvim/lua/plugins/omamac.lua"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ neovim config — your own neovim config is kept"* ]]
}

@test "own starship config is info" {
  healthy_mac
  : > "$HOME/.config/starship.toml"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ starship config — your own starship config is kept, so themes don't reach the prompt"* ]]
}

@test "own STARSHIP_CONFIG is info" {
  healthy_mac
  STARSHIP_CONFIG="$BATS_TEST_TMPDIR/mine.toml" run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ starship config — your own starship config is kept"* ]]
}

@test "STARSHIP_CONFIG naming omamac's file is ok" {
  healthy_mac
  STARSHIP_CONFIG="$HOME/.config/omamac/starship.toml" run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ starship config"* ]]
}

@test "own btop config is info" {
  healthy_mac
  mkdir -p "$HOME/.config/btop"
  : > "$HOME/.config/btop/btop.conf"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ btop config — your own btop config is kept, so themes don't reach btop"* ]]
}

@test "a missing theme file is a fail" {
  healthy_mac
  rm "$HOME/.config/omamac/starship.toml"
  expect_fail "Theme files" "omamac update"
}

@test "own nvim: info says themes don't reach neovim" {
  healthy_mac
  gum_answers leave
  rm "$HOME/.config/nvim/lua/plugins/omamac.lua"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ neovim config — your own neovim config is kept, so themes don't reach neovim"* ]]
}

# own_nvim: the user's neovim config, without omamac's marker.
own_nvim() {
  healthy_mac
  rm -r "$HOME/.config/nvim"
  mkdir -p "$HOME/.config/nvim"
  echo 'mine' > "$HOME/.config/nvim/init.lua"
}

@test "move-aside offered with a terminal, not without" {
  own_nvim
  gum_answers leave
  run doctor
  [ "$status" -eq 0 ]
  grep -q '^gum choose --header Move your neovim config aside so omamac can set up its own? --label-delimiter=: Leave it:leave Move it aside:move' "$STUB_LOG"
  [ "$(<"$HOME/.config/nvim/init.lua")" = mine ]
  : > "$STUB_LOG"
  export OMAMAC_TEST_TTY="$BATS_TEST_TMPDIR/no-tty"
  run doctor
  [ "$status" -eq 0 ]
  [ -z "$(grep '^gum' "$STUB_LOG")" ]
}

@test "move aside renames and sets up" {
  own_nvim
  gum_answers move
  run doctor
  [ "$status" -eq 0 ]
  [ "$(<"$HOME/.config/nvim.bak-$(date +%Y%m%d)/init.lua")" = mine ]
  [ -e "$HOME/.config/nvim/lua/plugins/omamac.lua" ]
  [ ! -e "$HOME/.config/nvim.bak-$(date +%Y%m%d)/lua/plugins/omamac.lua" ]
}

@test "move aside when the backup name is taken" {
  own_nvim
  mkdir "$HOME/.config/nvim.bak-$(date +%Y%m%d)"
  echo older > "$HOME/.config/nvim.bak-$(date +%Y%m%d)/old"
  gum_answers move
  run doctor
  [ "$status" -eq 0 ]
  [ "$(<"$HOME/.config/nvim.bak-$(date +%Y%m%d)/old")" = older ]
  [ "$(ls -d "$HOME"/.config/nvim.bak-"$(date +%Y%m%d)"-?????? | wc -l)" -eq 1 ]
  [ "$(<"$HOME"/.config/nvim.bak-"$(date +%Y%m%d)"-??????/init.lua)" = mine ]
  [ -e "$HOME/.config/nvim/lua/plugins/omamac.lua" ]
}

@test "move aside, clone fails" {
  own_nvim
  export OMAMAC_TEST_LAZYVIM_URL="file://$BATS_TEST_TMPDIR/no-such-repo"
  gum_answers move
  run doctor
  [ "$status" -eq 1 ]
  [ "$(<"$HOME/.config/nvim.bak-$(date +%Y%m%d)/init.lua")" = mine ]
  [ ! -e "$HOME/.config/nvim" ]
  [[ "$output" == *"nvim.bak-$(date +%Y%m%d)"* ]]
  [[ "$output" == *"Run the one-liner again"* ]]
}

@test "a dangling neovim symlink counts as the user's own" {
  healthy_mac
  gum_answers leave
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
  [[ "$output" == *"ℹ Your tools — skipped, your saved answers can't be read"* ]]
}

# Both settings answers yes, and the macOS values omamac wants.
settings_set() {
  choose desktops yes
  choose window_margins yes
  defaults write com.apple.dock mru-spaces -bool false
  defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool true
  defaults write com.apple.universalaccess reduceMotion -bool true
  defaults write com.apple.Accessibility ReduceMotionEnabled -int 1
  defaults write com.apple.WindowManager EnableTiledWindowMargins -bool true
}

@test "settings: both answers yes and all set: ✓" {
  healthy_mac
  settings_set
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Desktops as workspaces"* ]]
  [[ "$output" == *"✓ Window margins"* ]]
}

@test "settings: a key changed since omamac set it: ✗ with the fix" {
  healthy_mac
  settings_set
  defaults write com.apple.dock mru-spaces -bool true
  expect_fail "Desktops as workspaces" "omamac update"
  [[ "$output" == *"Spaces order was changed since omamac set it"* ]]
  [[ "$output" == *"✓ Window margins"* ]]
}

@test "settings: a key that is gone: ✗" {
  healthy_mac
  settings_set
  defaults delete com.apple.WindowManager EnableTiledWindowMargins
  expect_fail "Window margins" "omamac update"
}

@test "settings: Reduce motion refused: ℹ with the click" {
  healthy_mac
  settings_set
  export T_DEFAULTS_REFUSE=com.apple.universalaccess
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Desktops as workspaces"*"search for Reduce motion in System Settings"* ]]
}

@test "settings: Spaces setting refused for reading: ✗ naming it" {
  healthy_mac
  settings_set
  export T_DEFAULTS_REFUSE=com.apple.universalaccess
  defaults write com.apple.dock mru-spaces -bool true
  expect_fail "Desktops as workspaces" "omamac update"
  [[ "$output" == *"Spaces order was changed"* ]]
}

@test "settings: both answers no: no settings lines" {
  healthy_mac
  run doctor
  [[ "$output" != *"Desktops as workspaces"* ]]
  [[ "$output" != *"Window margins"* ]]
}

@test "without saved answers the settings are skipped" {
  healthy_mac
  rm "$CHOICES_FILE"
  run doctor
  [[ "$output" == *"ℹ macOS settings — skipped, your saved answers can't be read"* ]]
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
  [[ "$output" == *"✓ Your tools"* ]]
  [ -z "$(grep '^gum' "$STUB_LOG")" ]
}

@test "mise missing: chosen languages skipped" {
  healthy_mac
  choose languages go
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  run doctor
  [[ "$output" == *"ℹ Your tools — skipped, mise can't list what's installed"* ]]
  [[ "$output" != *"✗ Go"* ]]
}

@test "mise fails: chosen languages skipped" {
  healthy_mac
  choose languages go
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  printf '#!/bin/bash\nexit 1\n' > "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  chmod +x "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  run doctor
  [[ "$output" == *"ℹ Your tools — skipped, mise can't list what's installed"* ]]
  [[ "$output" != *"✗ Go"* ]]
}

@test "Homebrew can't list: chosen CLIs skipped" {
  healthy_mac
  choose cloud_clis gh
  T_BREW_LIST_FAIL=1 run doctor
  [[ "$output" == *"ℹ Your tools — skipped, Homebrew can't list what's installed"* ]]
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

# Ghostty the way install leaves it: from Homebrew, with omamac's file and its line.
healthy_ghostty() {
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask ghostty
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/Ghostty.app" "$HOME/.config/ghostty"
  echo 'config-file = ?~/.config/omamac/ghostty.conf' > "$HOME/.config/ghostty/config.ghostty"
  : > "$HOME/.config/omamac/ghostty.conf"
}

@test "Ghostty from Homebrew with its line" {
  healthy_mac
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Ghostty"$'\n'* ]]
  [[ "$output" == *"✓ Ghostty line"* ]]
  [[ "$output" == *"✓ App Management"* ]]
}

@test "Ghostty by hand" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/ghostty"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Ghostty — installed by hand"* ]]
  [[ "$output" != *"App Management"* ]]
}

@test "Ghostty missing" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/ghostty" "$OMAMAC_TEST_APPLICATIONS/Ghostty.app"
  expect_fail "Ghostty" "brew install --cask ghostty"
}

@test "Ghostty listed by Homebrew but its app gone" {
  healthy_mac
  rm -r "$OMAMAC_TEST_APPLICATIONS/Ghostty.app"
  expect_fail "Ghostty" "brew reinstall --cask ghostty"
}

@test "Ghostty line missing" {
  healthy_mac
  : > "$HOME/.config/ghostty/config.ghostty"
  expect_fail "Ghostty line" "Run the one-liner again"
}

@test "omamac's Ghostty file missing" {
  healthy_mac
  rm "$HOME/.config/omamac/ghostty.conf"
  expect_fail "omamac's Ghostty file" "omamac update"
}

@test "App Management refused is info" {
  healthy_mac
  stub touch 'case "$1" in *.omamac-write-test) echo "touch: $1: Operation not permitted" >&2; exit 1 ;; esac; exec /usr/bin/touch "$@"'
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ App Management"* ]]
  [[ "$output" == *"System Settings → Privacy & Security → App Management"* ]]
}

# colima the way install leaves it: the five formulas, the two links, the service and its marker.
healthy_colima() {
  choose docker colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install colima docker docker-compose docker-buildx lazydocker
  mkdir -p "$HOME/.docker/cli-plugins"
  for p in docker-compose docker-buildx; do
    ln -s "$OMAMAC_TEST_BREW_PREFIX/opt/$p/bin/$p" "$HOME/.docker/cli-plugins/$p"
  done
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" services start colima
  : > "$HOME/.local/state/omamac/colima-service"
  : > "$STUB_LOG" # the tests look only at doctor's own calls
}

@test "doctor: colima with everything in place is ✓" {
  healthy_mac
  healthy_colima
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Your tools"* ]]
  [[ "$output" == *"✓ docker-compose"* ]]
  [[ "$output" == *"✓ docker-buildx"* ]]
  [[ "$output" == *"✓ colima's service"* ]]
  [ -z "$(printf '%s\n' "$output" | grep -E '^(✗|ℹ)')" ]
}

@test "doctor: a missing colima formula is ✗ under Your tools" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall docker lazydocker
  gum_answers leave
  expect_fail "colima — you chose it, but Homebrew no longer has docker, lazydocker" \
    "omamac update puts it back; omamac uninstall colima drops it"
  [ "$(printf '%s\n' "$output" | grep -c '^✗ colima')" -eq 1 ]
}

@test "doctor: without the colima formula, no line for its service" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall colima
  gum_answers leave
  expect_fail "colima — you chose it, but Homebrew no longer has colima" \
    "omamac update puts it back; omamac uninstall colima drops it"
  [[ "$output" != *"colima's service"* ]]
}

@test "doctor: Homebrew can't list: colima skipped, said once" {
  healthy_mac
  healthy_colima
  choose cloud_clis gh
  T_BREW_LIST_FAIL=1 run doctor
  [ "$(printf '%s\n' "$output" | grep -c "ℹ Your tools — skipped, Homebrew can't list")" -eq 1 ]
  [[ "$output" != *"✗ colima"* ]]
}

@test "doctor: a missing plugin link is ✗" {
  healthy_mac
  healthy_colima
  rm "$HOME/.docker/cli-plugins/docker-buildx"
  expect_fail "docker-buildx — docker can't find buildx" "omamac update"
}

@test "doctor: a dangling plugin link is ✗" {
  healthy_mac
  healthy_colima
  rm -r "$OMAMAC_TEST_BREW_PREFIX/opt/docker-compose"
  expect_fail "docker-compose — docker can't find compose" "omamac update"
}

@test "doctor: a user's own plugin is ℹ, not ✗" {
  healthy_mac
  healthy_colima
  rm "$HOME/.docker/cli-plugins/docker-compose"
  : > "$HOME/.docker/cli-plugins/docker-compose"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ docker-compose — your own file in ~/.docker/cli-plugins is kept, and docker uses it"* ]]
}

@test "doctor: a user's link that points at nothing is ✗, and stays" {
  healthy_mac
  healthy_colima
  rm "$HOME/.docker/cli-plugins/docker-compose"
  ln -s /Applications/Docker.app/Contents/Resources/cli-plugins/docker-compose "$HOME/.docker/cli-plugins/docker-compose"
  expect_fail "docker-compose — your link in ~/.docker/cli-plugins points at nothing" "Remove it, then run omamac update"
  [ -L "$HOME/.docker/cli-plugins/docker-compose" ]
}

@test "doctor: an unregistered service is ℹ with the command" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" services stop colima
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ colima's service — colima doesn't start at login. To start it: brew services start colima"* ]]
  [ -z "$(grep 'services start' "$STUB_LOG")" ]
}

@test "doctor: a service in error is ℹ naming its log" {
  healthy_mac
  healthy_colima
  echo error > "$OMAMAC_TEST_BREW_PREFIX/services/colima"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ colima's service — colima didn't start; see $OMAMAC_TEST_BREW_PREFIX/var/log/colima.log"* ]]
}

@test "doctor: Homebrew can't say how the service is: ℹ skipped" {
  healthy_mac
  healthy_colima
  T_BREW_SERVICES_INFO_FAIL=1 run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ colima's service — skipped, Homebrew can't say whether it's registered"* ]]
}

@test "doctor: offers to reinstall colima" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall lazydocker
  gum_answers reinstall
  run doctor
  [ "$status" -eq 1 ]
  grep -qx 'gum choose --header colima is gone. What should omamac do? --label-delimiter=: Leave it:leave Reinstall it:reinstall' "$STUB_LOG"
  grep -qx 'brew install lazydocker' "$STUB_LOG"
  [ -e "$OMAMAC_TEST_BREW_PREFIX/Cellar/lazydocker" ]
  grep -qx 'docker=colima' "$CHOICES_FILE"
}

@test "doctor: Leave it keeps colima as it is" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall lazydocker
  gum_answers leave
  run doctor
  [ "$status" -eq 1 ]
  [ -z "$(grep '^brew install' "$STUB_LOG")" ]
  grep -qx 'docker=colima' "$CHOICES_FILE"
}

@test "doctor: with none, a user's own docker isn't reported" {
  healthy_mac
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install docker docker-compose
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *docker* ]]
  [[ "$output" != *colima* ]]
}

# Docker Desktop the way install leaves it: lazydocker and the cask with its app.
healthy_desktop() {
  choose docker docker-desktop
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install lazydocker
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask docker-desktop
  : > "$STUB_LOG" # the tests look only at doctor's own calls
}

@test "doctor: Docker Desktop with everything in place is ✓" {
  healthy_mac
  healthy_desktop
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Your tools"* ]]
  [ -z "$(printf '%s\n' "$output" | grep -E '^(✗|ℹ)')" ]
}

@test "doctor: a gone Docker Desktop app is ✗ under Your tools" {
  healthy_mac
  healthy_desktop
  rm -r "$OMAMAC_TEST_APPLICATIONS/Docker.app"
  gum_answers leave
  expect_fail "Docker Desktop — you chose it, but Homebrew no longer has Docker Desktop" \
    "omamac update puts it back; omamac uninstall docker-desktop drops it"
  [ "$(printf '%s\n' "$output" | grep -c '^✗ Docker Desktop')" -eq 1 ]
}

@test "doctor: a gone lazydocker is ✗, one Docker Desktop entry" {
  healthy_mac
  healthy_desktop
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall lazydocker
  gum_answers leave
  expect_fail "Docker Desktop — you chose it, but Homebrew no longer has lazydocker" \
    "omamac uninstall docker-desktop drops it"
  [ "$(printf '%s\n' "$output" | grep -c '^✗ Docker Desktop')" -eq 1 ]
}

@test "doctor: a hand-installed Docker Desktop is ℹ" {
  healthy_mac
  healthy_desktop
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/docker-desktop"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Docker Desktop — installed by hand, so omamac won't update it"* ]]
}

@test "doctor: offers to reinstall Docker Desktop" {
  healthy_mac
  healthy_desktop
  rm -r "$OMAMAC_TEST_APPLICATIONS/Docker.app"
  gum_answers reinstall
  run doctor
  [ "$status" -eq 1 ]
  grep -qx 'gum choose --header Docker Desktop is gone. What should omamac do? --label-delimiter=: Leave it:leave Reinstall it:reinstall' "$STUB_LOG"
  grep -qx 'brew reinstall --cask docker-desktop' "$STUB_LOG"
  # The password step runs in the open, so a prompt shows.
  [ -z "$(grep '^gum spin' "$STUB_LOG")" ]
  grep -qx 'docker=docker-desktop' "$CHOICES_FILE"
}

# Apps the way install leaves them: chosen, and Homebrew has each with its app.
healthy_apps() {
  local id
  for id in "$@"; do
    case $id in
      wispr-flow) choose wispr_flow yes ;;
      zoom) choose apps_communication zoom ;;
      *) choose apps_media "$id" ;;
    esac
    "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask "$id"
  done
  : > "$STUB_LOG"
}

@test "doctor: chosen apps all there is ✓" {
  healthy_mac
  healthy_apps vlc
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Your apps"* ]]
}

@test "doctor: no apps chosen, no Your apps line" {
  healthy_mac
  run doctor
  [[ "$output" != *"Your apps"* ]]
}

@test "doctor: a gone app is ✗ and its id is offered" {
  healthy_mac
  healthy_apps vlc
  rm -r "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  gum_answers leave
  expect_fail "VLC — you chose it, but it's gone from Applications" \
    "omamac update puts it back; omamac uninstall vlc drops it"
  grep -qx 'gum choose --header VLC is gone. What should omamac do? --label-delimiter=: Leave it:leave Reinstall it:reinstall Remove it from my answers:drop' "$STUB_LOG"
}

@test "doctor: a hand-installed app is ℹ, exit 0" {
  healthy_mac
  healthy_apps vlc
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/vlc"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ VLC — installed by hand, so omamac won't update it"* ]]
}

@test "doctor: Homebrew can't list: Your apps skipped" {
  healthy_mac
  healthy_apps vlc
  T_BREW_LIST_FAIL=1 run doctor
  [[ "$output" == *"ℹ Your apps — skipped, Homebrew can't list what's installed"* ]]
}

@test "doctor: Reinstall for an app Homebrew doesn't list runs brew install --cask" {
  healthy_mac
  healthy_apps vlc
  rm -r "$OMAMAC_TEST_APPLICATIONS/VLC.app" "$OMAMAC_TEST_BREW_PREFIX/Caskroom/vlc"
  gum_answers reinstall
  run doctor
  [ "$status" -eq 1 ]
  grep -qx 'brew install --cask vlc' "$STUB_LOG"
  [ -e "$OMAMAC_TEST_APPLICATIONS/VLC.app" ]
}

@test "doctor: Reinstall for an app Homebrew lists runs brew reinstall --cask" {
  healthy_mac
  healthy_apps vlc
  rm -r "$OMAMAC_TEST_APPLICATIONS/VLC.app"
  gum_answers reinstall
  run doctor
  grep -qx 'brew reinstall --cask vlc' "$STUB_LOG"
  [ -e "$OMAMAC_TEST_APPLICATIONS/VLC.app" ]
}

@test "doctor: Reinstall for a password app runs without a spinner" {
  healthy_mac
  healthy_apps zoom
  rm -r "$OMAMAC_TEST_APPLICATIONS/zoom.us.app"
  gum_answers reinstall
  run doctor
  grep -qx 'brew reinstall --cask zoom' "$STUB_LOG"
  [ -z "$(grep '^gum spin' "$STUB_LOG")" ]
  [[ "$output" == *"Homebrew asks for your password for: Zoom."* ]]
}

@test "doctor: Remove it from my answers drops the app" {
  healthy_mac
  healthy_apps wispr-flow
  rm -r "$OMAMAC_TEST_APPLICATIONS/Wispr Flow.app"
  gum_answers drop
  run doctor
  [ "$status" -eq 1 ]
  grep -qx 'wispr_flow=no' "$CHOICES_FILE"
}

@test "doctor: with colima, a Docker Desktop app isn't reported" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask docker-desktop
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *"Docker Desktop"* ]]
}
