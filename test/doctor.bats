load helpers/common

load helpers/dock
load helpers/hotkeys
bats_require_minimum_version 1.5.0

setup() { setup_sandbox; }

doctor() { "$BASH5" "$REPO_ROOT/bin/omamac" doctor "$@"; }

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
    for lib in paths ui questions choices herdr ghostty neovim theme vscode languages apply; do source \"$REPO_ROOT/lib/\$lib.sh\"; done
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

# expect_fail <what> <fix>: doctor exits 1 and prints a ✗ line with the fix,
# under its area. expect_fail_all: the same with --all, the ✗ line unindented.
expect_fail() {
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *$'\n'"  ✗ $1"* ]]
  [[ "$output" == *"Fix: "*"$2"* ]]
}
expect_fail_all() {
  run doctor --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ $1"* ]]
  [[ "$output" == *"Fix: "*"$2"* ]]
}

@test "healthy Mac: every check passes" {
  healthy_mac
  run doctor --all
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
  expect_fail "bash for omamac" "brew install bash"
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
  PATH=/usr/bin:/bin expect_fail "Homebrew in your shell" "Run the one-liner again"
}

@test "checkout missing" {
  healthy_mac
  rm -rf "$HOME/.local/share/omamac"
  expect_fail "omamac's files" "Run the one-liner"
}

@test "checkout with another origin" {
  healthy_mac
  git -C "$CHECKOUT" remote set-url origin https://example.com/other
  expect_fail "omamac's files" "Run the one-liner"
}

@test "checkout has local changes" {
  healthy_mac
  echo a > "$CHECKOUT/tracked"
  git -C "$CHECKOUT" add tracked
  git -C "$CHECKOUT" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m tracked
  echo b > "$CHECKOUT/tracked"
  expect_fail "omamac's files unchanged" "git -C ~/.local/share/omamac status"
}

@test "an untracked file in the checkout still passes" {
  healthy_mac
  : > "$CHECKOUT/.DS_Store"
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ omamac's files unchanged"* ]]
}

@test "Homebrew line missing" {
  healthy_mac
  : > "$HOME/.zprofile"
  expect_fail "Homebrew in your shell" "Run the one-liner again"
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
  expect_fail "omamac in your shell" "Run the one-liner again"
}

@test "omamac's zsh file missing" {
  healthy_mac
  rm "$HOME/.config/omamac/zshrc"
  expect_fail "omamac's shell settings" "Run the one-liner again"
}

@test "core formula missing" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Cellar/eza"
  expect_fail "Everyday tools" "brew install eza"
}

@test "core formulas missing are all named" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Cellar/eza" "$OMAMAC_TEST_BREW_PREFIX/Cellar/bat"
  expect_fail "Everyday tools" "brew install eza bat"
}

@test "core check is skipped when Homebrew is missing" {
  healthy_mac
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
  run doctor --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"ℹ Everyday tools — skipped"* ]]
  [[ "$output" == *"Code editor (neovim)"* ]]
}

@test "core check is skipped when brew can't list" {
  healthy_mac
  T_BREW_LIST_FAIL=1 run doctor
  [[ "$output" == *"ℹ Everyday tools — skipped"* ]]
}

@test "user's own neovim config is kept" {
  healthy_mac
  gum_answers leave
  rm "$HOME/.config/nvim/lua/plugins/omamac.lua"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Code editor (neovim) — your own neovim config is kept"* ]]
}

@test "own starship config is info" {
  healthy_mac
  : > "$HOME/.config/starship.toml"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Prompt colours (starship) — your own starship config is kept, so themes don't reach the prompt"* ]]
}

@test "own STARSHIP_CONFIG is info" {
  healthy_mac
  STARSHIP_CONFIG="$BATS_TEST_TMPDIR/mine.toml" run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Prompt colours (starship) — your own starship config is kept"* ]]
}

@test "STARSHIP_CONFIG naming omamac's file is ok" {
  healthy_mac
  STARSHIP_CONFIG="$HOME/.config/omamac/starship.toml" run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Prompt colours (starship)"* ]]
}

@test "own btop config is info" {
  healthy_mac
  mkdir -p "$HOME/.config/btop"
  : > "$HOME/.config/btop/btop.conf"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ System monitor colours (btop) — your own btop config is kept, so themes don't reach btop"* ]]
}

# vscode_app: VS Code is installed, with the fake code command in it.
vscode_app() {
  local bin="$OMAMAC_TEST_APPLICATIONS/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$bin"
  ln -sf "$HELPERS_DIR/fake-code" "$bin/code"
}

@test "no VS Code: no VS Code line" {
  healthy_mac
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" != *"VS Code"* ]]
}

@test "VS Code with omamac's theme is ok" {
  healthy_mac
  vscode_app
  omamac_lib vscode_theme_install
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ VS Code colours — VS Code follows your theme"* ]]
}

@test "VS Code without omamac's theme is a fail" {
  healthy_mac
  vscode_app
  expect_fail "VS Code colours" "omamac update"
  [[ "$output" == *"VS Code doesn't have omamac's theme"* ]]
}

@test "VS Code with omamac's theme from before the watch is a fail" {
  healthy_mac
  vscode_app
  omamac_lib vscode_theme_install
  local pkg="$HOME/.vscode/extensions/omamac.omamac-theme-1.0.0/package.json"
  jq 'del(.contributes.themes[0]._watch)' "$pkg" > "$BATS_TEST_TMPDIR/old.json"
  mv "$BATS_TEST_TMPDIR/old.json" "$pkg"
  expect_fail "VS Code colours" "omamac update"
}

@test "own VS Code theme is info" {
  healthy_mac
  vscode_app
  mkdir -p "$HOME/Library/Application Support/Code/User"
  echo '{ "workbench.colorTheme": "Solarized Light" }' > "$HOME/Library/Application Support/Code/User/settings.json"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ VS Code colours — your own VS Code theme is kept, so themes don't reach VS Code"* ]]
}

@test "a missing theme file is a fail" {
  healthy_mac
  rm "$HOME/.config/omamac/starship.toml"
  expect_fail "Theme colours" "omamac update"
}

@test "own nvim: info says themes don't reach neovim" {
  healthy_mac
  gum_answers leave
  rm "$HOME/.config/nvim/lua/plugins/omamac.lua"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Code editor (neovim) — your own neovim config is kept, so themes don't reach neovim"* ]]
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
  [[ "$output" == *"ℹ Code editor (neovim)"* ]]
}

@test "neovim config missing" {
  healthy_mac
  rm -r "$HOME/.config/nvim"
  expect_fail "Code editor (neovim)" "Run the one-liner again"
}

@test "herdr: omamac's config" {
  healthy_mac
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ herdr settings"* ]]
}

@test "herdr: the user's own config" {
  healthy_mac
  mkdir -p "$HOME/.config/herdr"
  echo mine > "$HOME/.config/herdr/config.toml"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ herdr settings — your own herdr config is kept, so omamac's key bindings and themes don't reach herdr"* ]]
}

@test "herdr: herdr's own onboarding file is not the user's" {
  healthy_mac
  mkdir -p "$HOME/.config/herdr"
  printf 'onboarding = false\n' > "$HOME/.config/herdr/config.toml"
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ herdr settings"* ]]
}

@test "herdr: changed in herdr is still omamac's" {
  healthy_mac
  echo '# changed' >> "$HOME/.config/omamac/herdr.toml"
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ herdr settings"* ]]
}

@test "herdr: omamac's file missing" {
  healthy_mac
  rm "$HOME/.config/omamac/herdr.toml"
  expect_fail "herdr settings" "omamac update"
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
  expect_fail "Your answers" "Run the one-liner"
}

@test "saved answers invalid" {
  healthy_mac
  echo 'colour=red' >> "$CHOICES_FILE"
  expect_fail "Your answers" "Delete that line"
  [[ "$output" == *"line 21"* ]]
}

@test "saved answers incomplete" {
  healthy_mac
  sed -i '' '/^docker=/d' "$CHOICES_FILE"
  expect_fail "Your answers" "Run omamac install docker"
}

@test "saved answers incomplete: one omamac install for every name, the theme apart" {
  healthy_mac
  sed -i '' -e '/^theme=/d' -e '/^apps_media=/d' -e '/^apps_ai=/d' -e '/^desktop_widgets=/d' "$CHOICES_FILE"
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ Your answers — some questions have no answer yet. Fix: Run omamac theme, then omamac install apps desktop-widgets"* ]]
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
  expect_fail "Languages list" "omamac update"
  [[ "$output" == *"~/.config/mise/conf.d/omamac.toml doesn't match your answers"* ]]
}

@test "mise drop-in edited" {
  healthy_mac
  echo 'go = "latest"' >> "$HOME/.config/mise/conf.d/omamac.toml"
  expect_fail "Languages list" "omamac update"
}

@test "without saved answers the drop-in and chosen tools are skipped" {
  healthy_mac
  rm "$CHOICES_FILE"
  run doctor
  [[ "$output" == *"ℹ Languages list — skipped, your saved answers can't be read"* ]]
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
  local i
  for i in "${!HOTKEY_IDS[@]}"; do
    hotkey_seed "${HOTKEY_IDS[$i]}" '{"enabled":true,"value":{"parameters":[65535,'"${HOTKEY_CODES[$i]}"',262144],"type":"standard"}}'
  done
}

@test "settings: both answers yes and all set: ✓" {
  healthy_mac
  settings_set
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Desktops as workspaces"* ]]
  [[ "$output" == *"✓ Window margins"* ]]
}

@test "settings: a key changed since omamac set it: ✗ with the fix" {
  healthy_mac
  settings_set
  defaults write com.apple.dock mru-spaces -bool true
  expect_fail_all "Desktops as workspaces" "omamac update"
  [[ "$output" == *"Spaces order was changed since omamac set it"* ]]
  [[ "$output" == *"✓ Window margins"* ]]
}

@test "settings: a Ctrl 1–6 shortcut turned off: ✗ naming it" {
  healthy_mac
  settings_set
  hotkey_seed 122 '{"enabled":false,"value":{"parameters":[65535,23,262144],"type":"standard"}}'
  expect_fail "Desktops as workspaces" "omamac update"
  [[ "$output" == *"Ctrl 1–6 was changed since omamac set it"* ]]
}

@test "settings: desktop widgets shown again: ✗ naming them" {
  healthy_mac
  choose desktop_widgets yes
  defaults write com.apple.WindowManager StandardHideWidgets -bool true
  defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
  run doctor --all
  [[ "$output" == *"✓ Desktop widgets"* ]]
  defaults write com.apple.WindowManager StandardHideWidgets -bool false
  expect_fail_all "Desktop widgets" "omamac update"
  [[ "$output" == *"Desktop widgets was changed since omamac set it"* ]]
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

@test "a chosen coding agent gone: ✗, and dropping it changes only its own answer" {
  healthy_mac
  choose cloud_clis gh
  choose coding_agents 'antigravity-cli opencode'
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/Cellar/gh" "$OMAMAC_TEST_BREW_PREFIX/Cellar/opencode"
  gum_answers drop
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"Antigravity CLI — you chose it, but Homebrew no longer has it"* ]]
  [[ "$output" == *"omamac uninstall antigravity-cli drops it"* ]]
  [[ "$output" == *"✓ Antigravity CLI is dropped from your answers"* ]]
  grep -qx 'coding_agents=opencode' "$CHOICES_FILE"
  grep -qx 'cloud_clis=gh' "$CHOICES_FILE"
}

@test "chosen tools there: ✓ and no prompt" {
  healthy_mac
  choose languages go
  choose cloud_clis gh
  mise_has go
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/Cellar/gh"
  gum_answers
  run doctor --all
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

@test "a broken offer prompt says to run omamac doctor again" {
  healthy_mac
  choose languages go
  gum_answers "exit 2"
  run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"Run omamac doctor again."* ]]
  [[ "$output" != *"one-liner again"* ]]
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
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Ghostty — the terminal app omamac sets up"$'\n'* ]]
  [[ "$output" == *"✓ omamac in Ghostty"* ]]
  [[ "$output" == *"✓ Permission to update apps"* ]]
}

@test "Ghostty by hand" {
  healthy_mac
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/ghostty"
  run doctor --all
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF "ℹ Ghostty — installed by hand, so omamac won't update it. To let Homebrew take it over: brew install --cask --adopt ghostty"
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
  expect_fail "omamac in Ghostty" "Run the one-liner again"
}

@test "omamac's Ghostty file missing" {
  healthy_mac
  rm "$HOME/.config/omamac/ghostty.conf"
  expect_fail "omamac's Ghostty settings" "omamac update"
}

@test "App Management refused is info" {
  healthy_mac
  stub touch 'case "$1" in *.omamac-write-test) echo "touch: $1: Operation not permitted" >&2; exit 1 ;; esac; exec /usr/bin/touch "$@"'
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Permission to update apps"* ]]
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
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Your tools"* ]]
  [[ "$output" == *"✓ Docker Compose"* ]]
  [[ "$output" == *"✓ Docker Buildx"* ]]
  [[ "$output" == *"✓ colima at login"* ]]
  [ -z "$(printf '%s\n' "$output" | grep -E '^(✗|ℹ)')" ]
}

@test "doctor: a missing colima formula is ✗ under Your tools" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall docker lazydocker
  gum_answers leave
  expect_fail_all "colima — you chose it, but Homebrew no longer has docker, lazydocker" \
    "omamac update puts it back; omamac uninstall colima drops it"
  [ "$(printf '%s\n' "$output" | grep -c '^✗ colima')" -eq 1 ]
}

@test "doctor: without the colima formula, no line for its service" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall colima
  gum_answers leave
  expect_fail_all "colima — you chose it, but Homebrew no longer has colima" \
    "omamac update puts it back; omamac uninstall colima drops it"
  [[ "$output" != *"colima at login"* ]]
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
  expect_fail "Docker Buildx — docker can't find buildx" "omamac update"
}

@test "doctor: a dangling plugin link is ✗" {
  healthy_mac
  healthy_colima
  rm -r "$OMAMAC_TEST_BREW_PREFIX/opt/docker-compose"
  expect_fail "Docker Compose — docker can't find compose" "omamac update"
}

@test "doctor: a user's own plugin is ℹ, not ✗" {
  healthy_mac
  healthy_colima
  rm "$HOME/.docker/cli-plugins/docker-compose"
  : > "$HOME/.docker/cli-plugins/docker-compose"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ Docker Compose — your own file in ~/.docker/cli-plugins is kept, and docker uses it"* ]]
}

@test "doctor: a user's link that points at nothing is ✗, and stays" {
  healthy_mac
  healthy_colima
  rm "$HOME/.docker/cli-plugins/docker-compose"
  ln -s /Applications/Docker.app/Contents/Resources/cli-plugins/docker-compose "$HOME/.docker/cli-plugins/docker-compose"
  expect_fail "Docker Compose — your link in ~/.docker/cli-plugins points at nothing" "Remove it, then run omamac update"
  [ -L "$HOME/.docker/cli-plugins/docker-compose" ]
}

@test "doctor: an unregistered service is ℹ with the command" {
  healthy_mac
  healthy_colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" services stop colima
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ colima at login — colima doesn't start at login. To start it: brew services start colima"* ]]
  [ -z "$(grep 'services start' "$STUB_LOG")" ]
}

@test "doctor: a service in error is ℹ naming its log" {
  healthy_mac
  healthy_colima
  echo error > "$OMAMAC_TEST_BREW_PREFIX/services/colima"
  run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ colima at login — colima didn't start; see $OMAMAC_TEST_BREW_PREFIX/var/log/colima.log"* ]]
}

@test "doctor: Homebrew can't say how the service is: ℹ skipped" {
  healthy_mac
  healthy_colima
  T_BREW_SERVICES_INFO_FAIL=1 run doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ colima at login — skipped, Homebrew can't say whether it's registered"* ]]
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
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Your tools"* ]]
  [ -z "$(printf '%s\n' "$output" | grep -E '^(✗|ℹ)')" ]
}

@test "doctor: a gone Docker Desktop app is ✗ under Your tools" {
  healthy_mac
  healthy_desktop
  rm -r "$OMAMAC_TEST_APPLICATIONS/Docker.app"
  gum_answers leave
  expect_fail_all "Docker Desktop — you chose it, but Homebrew no longer has Docker Desktop" \
    "omamac update puts it back; omamac uninstall docker-desktop drops it"
  [ "$(printf '%s\n' "$output" | grep -c '^✗ Docker Desktop')" -eq 1 ]
}

@test "doctor: a gone lazydocker is ✗, one Docker Desktop entry" {
  healthy_mac
  healthy_desktop
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" uninstall lazydocker
  gum_answers leave
  expect_fail_all "Docker Desktop — you chose it, but Homebrew no longer has lazydocker" \
    "omamac uninstall docker-desktop drops it"
  [ "$(printf '%s\n' "$output" | grep -c '^✗ Docker Desktop')" -eq 1 ]
}

@test "doctor: a hand-installed Docker Desktop is ℹ" {
  healthy_mac
  healthy_desktop
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/docker-desktop"
  run doctor --all
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF "ℹ Docker Desktop — installed by hand, so omamac won't update it"
  [[ "$output" != *"--adopt"* ]]
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
  run doctor --all
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
  run doctor --all
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF "ℹ VLC — installed by hand, so omamac won't update it. To let Homebrew take it over: brew install --cask --adopt vlc"
}

@test "doctor: a hand-installed VS Code names its cask in the adopt command" {
  healthy_mac
  choose apps_developer vscode
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask visual-studio-code
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/visual-studio-code"
  omamac_lib vscode_theme_install
  run doctor --all
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF "ℹ VS Code — installed by hand, so omamac won't update it. To let Homebrew take it over: brew install --cask --adopt visual-studio-code"
}

@test "doctor: a hand-installed Zoom keeps today's line, no adopt command" {
  healthy_mac
  healthy_apps zoom
  rm -r "$OMAMAC_TEST_BREW_PREFIX/Caskroom/zoom"
  run doctor --all
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF "ℹ Zoom — installed by hand, so omamac won't update it"
  [[ "$output" != *"--adopt"* ]]
}

@test "doctor: Homebrew can't list: Your apps skipped" {
  healthy_mac
  healthy_apps vlc
  T_BREW_LIST_FAIL=1 run doctor
  [[ "$output" == *"ℹ Your apps — skipped, Homebrew can't list what's installed"* ]]
}

@test "doctor: Homebrew can't list partway through: an earlier ✗ still counts" {
  # The second app's list fails after the first app was found gone.
  run "$BASH5" -c "set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    for lib in paths ui questions choices core apps doctor; do source \"$REPO_ROOT/lib/\$lib.sh\"; done
    DOCTOR_HAS_CHOICES=1 DOCTOR_GONE=()
    CHOICES[apps_media]='spotify vlc'
    core_cask_state() { [ \"\$1\" = spotify ] && echo missing; }
    DOCTOR_ALL=1 r=0
    doctor_check_apps || r=\$?
    doctor_print
    echo rc=\$r"
  [[ "$output" == *"✗ Spotify — you chose it, but it's gone from Applications"* ]]
  [[ "$output" == *"ℹ Your apps — skipped, Homebrew can't list what's installed"* ]]
  [[ "$output" == *"rc=1" ]]
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

# dock_record: the copy omamac keeps of the Dock it cleaned.
dock_record() { plutil -create xml1 "$HOME/.local/state/omamac/dock-before.plist"; }

@test "dock: record and Recents off: ✓" {
  healthy_mac
  choose dock yes
  dock_record
  defaults write com.apple.dock show-recents -bool false
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Dock cleanup"* ]]
}

@test "dock: no record: ✗" {
  healthy_mac
  choose dock yes
  defaults write com.apple.dock show-recents -bool false
  expect_fail "Dock cleanup" "omamac update"
  [[ "$output" == *"omamac hasn't cleaned the Dock"* ]]
}

@test "dock: Recents back on: ✗ naming it" {
  healthy_mac
  choose dock yes
  dock_record
  defaults write com.apple.dock show-recents -bool true
  expect_fail "Dock cleanup" "omamac update"
  [[ "$output" == *"Suggested and recent apps was changed since omamac set it"* ]]
}

@test "dock auto-hide: changed: ✗" {
  healthy_mac
  choose dock_autohide yes
  defaults write com.apple.dock autohide -bool false
  expect_fail "Dock auto-hide" "omamac update"
}

@test "dock auto-hide: set: ✓" {
  healthy_mac
  choose dock_autohide yes
  defaults write com.apple.dock autohide -bool true
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Dock auto-hide"* ]]
}

@test "dock no: no Dock line" {
  healthy_mac
  run doctor
  [[ "$output" != *"Dock"* ]]
}

# Your tools and apps (#46's picks 2A 3B 4B): after the checks, a group per
# kind, each tool with its version and whether a newer one is out, then the
# apps with the version each reports.

# app_version <bundle> <version>: the app's Info.plist reports that version.
app_version() {
  mkdir -p "$OMAMAC_TEST_APPLICATIONS/$1/Contents"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>%s</string></dict></plist>\n' \
    "$2" > "$OMAMAC_TEST_APPLICATIONS/$1/Contents/Info.plist"
}

# have <group>: doctor's plain list from that group's line on.
have() { printf '%s\n' "$output" | sed -n "/^$1\$/,\$p"; }

@test "doctor lists your tools after the checks, by kind, with versions" {
  healthy_mac
  choose languages 'go rust'
  choose cloud_clis gh
  mise_has go
  echo 1.88.0 > "$OMAMAC_TEST_BREW_PREFIX/mise/rust"
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gh
  echo 2.83.1_1 > "$OMAMAC_TEST_BREW_PREFIX/Cellar/gh/.version"
  run doctor
  [ "$status" -eq 0 ]
  [ "$(have Languages)" = "Languages
    Go 1.0 (latest)
    Rust 1.88.0 (latest)
Cloud CLIs
    GitHub CLI 2.83.1 (latest)" ]
  [[ "$output" != *"Coding agents"* ]]
  [[ "$output" != *"waiting"* ]]
}

@test "doctor's list leaves out what's gone; the ✗ line names it" {
  healthy_mac
  choose languages 'go rust'
  mise_has go
  gum_answers leave
  run doctor
  [ "$status" -eq 1 ]
  [ "$(have Languages)" = "Languages
    Go 1.0 (latest)" ]
  [[ "$output" == *"✗ Rust — you chose it, but mise no longer has it"* ]]
}

@test "doctor says which newer versions are out, and that omamac update brings them" {
  healthy_mac
  choose languages 'node python'
  choose coding_agents claude-code
  echo 24.11.1 > "$OMAMAC_TEST_BREW_PREFIX/mise/node"
  echo 3.14.0 > "$OMAMAC_TEST_BREW_PREFIX/mise/python"
  echo '{"python":{"name":"python","requested":"latest","current":"3.14.0","latest":"3.14.2"}}' \
    > "$OMAMAC_TEST_BREW_PREFIX/mise-outdated.json"
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask claude-code
  echo 2.1.0 > "$OMAMAC_TEST_BREW_PREFIX/Caskroom/claude-code/.version"
  echo '{"formulae":[],"casks":[{"name":"claude-code","installed_versions":["2.1.0"],"current_version":"2.2.0,abc"}]}' \
    > "$OMAMAC_TEST_BREW_PREFIX/outdated.json"
  : > "$STUB_LOG"
  run doctor
  [ "$status" -eq 0 ]
  [ "$(have Languages)" = "Languages
    Node.js 24.11.1 (latest)
    Python 3.14.0 (3.14.2 is out)
Coding agents
    Claude Code CLI 2.1.0 (2.2.0 is out)
ℹ 2 updates waiting: omamac update" ]
  # Each lookup once, and Homebrew isn't updated first.
  [ "$(grep -c '^brew outdated' "$STUB_LOG")" -eq 1 ]
  grep -qx 'brew outdated --greedy --json=v2' "$STUB_LOG"
  grep -qx 'brew-env outdated HOMEBREW_NO_AUTO_UPDATE=1' "$STUB_LOG"
  [ "$(grep -c '^mise outdated' "$STUB_LOG")" -eq 1 ]
}

@test "doctor: a pinned formula isn't an update waiting" {
  healthy_mac
  choose cloud_clis gh
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gh
  echo '{"formulae":[{"name":"gh","installed_versions":["1.0"],"current_version":"2.0","pinned":true,"pinned_version":"1.0"}],"casks":[]}' \
    > "$OMAMAC_TEST_BREW_PREFIX/outdated.json"
  run doctor
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF '    GitHub CLI 1.0 (latest)'
}

@test "doctor: a failed lookup shows versions only, and doctor's status stays its own" {
  healthy_mac
  choose languages go
  choose cloud_clis gh
  mise_has go
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gh
  T_MISE_OUTDATED_FAIL=1 T_BREW_OUTDATED_FAIL=1 run doctor
  [ "$status" -eq 0 ]
  [ "$(have Languages)" = "Languages
    Go 1.0
Cloud CLIs
    GitHub CLI 1.0" ]
  # Output it can't read is a failed lookup too.
  echo 'not json' > "$OMAMAC_TEST_BREW_PREFIX/outdated.json"
  run doctor
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qxF '    Go 1.0 (latest)'
  printf '%s\n' "$output" | grep -qxF '    GitHub CLI 1.0'
  # A ✗ elsewhere keeps doctor's 1.
  rm "$HOME/.config/omamac/starship.toml"
  T_BREW_OUTDATED_FAIL=1 run doctor
  [ "$status" -eq 1 ]
}

@test "doctor: a slow lookup is cut short; its rows show versions only" {
  healthy_mac
  choose languages go
  choose cloud_clis gh
  mise_has go
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gh
  SECONDS=0
  OMAMAC_TEST_DOCTOR_WAIT=1 T_BREW_OUTDATED_SLEEP=30 run doctor
  [ "$status" -eq 0 ]
  [ "$SECONDS" -lt 15 ]
  printf '%s\n' "$output" | grep -qxF '    Go 1.0 (latest)'
  printf '%s\n' "$output" | grep -qxF '    GitHub CLI 1.0'
}

@test "doctor lists colima's formulas under Docker" {
  healthy_mac
  healthy_colima
  run doctor
  [ "$status" -eq 0 ]
  [ "$(have Docker)" = "Docker
    colima 1.0 (latest)
    docker 1.0 (latest)
    docker-compose 1.0 (latest)
    docker-buildx 1.0 (latest)
    lazydocker 1.0 (latest)" ]
}

@test "doctor lists Docker Desktop with the version the app reports, no newer column" {
  healthy_mac
  healthy_desktop
  app_version Docker.app 4.52.0
  run doctor
  [ "$status" -eq 0 ]
  [ "$(have Docker)" = "Docker
    Docker Desktop 4.52.0
    lazydocker 1.0 (latest)" ]
}

@test "doctor lists your apps one per line, in the catalog's order, with their versions" {
  healthy_mac
  healthy_apps vlc wispr-flow
  choose apps_browsers firefox
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask firefox
  app_version VLC.app 3.0.21
  app_version Firefox.app 145.0.1
  : > "$STUB_LOG"
  run doctor
  [ "$status" -eq 0 ]
  # This Wispr Flow reports no version.
  [ "$(have Apps)" = "Apps
    Firefox 145.0.1
    VLC 3.0.21
    Wispr Flow" ]
  # Apps update themselves: no lookup for them.
  [ -z "$(grep outdated "$STUB_LOG")" ]
}

# The report by area (#46, made short): by default one line per area (omamac,
# Terminal, Theme, macOS), each problem with its fix and each note under its
# area, then Your tools and apps, then the count line. --all shows every
# check, with what it is and where it lives. The same checks and exit codes.

# shown: $output without its colour codes.
shown() { printf '%s\n' "$output" | uncoloured; }

@test "plain text: a healthy Mac is four area lines, then the groups" {
  healthy_mac
  choose languages go
  mise_has go
  run doctor
  [ "$status" -eq 0 ]
  [ "$output" = "✓ omamac — working
✓ Terminal — working
✓ Theme — Tokyo Night
✓ macOS — nothing picked
Languages
    Go 1.0 (latest)" ]
}

@test "plain text: a problem and a note sit under their areas" {
  healthy_mac
  : > "$HOME/.zprofile"
  mkdir -p "$HOME/.config/btop"
  echo mine > "$HOME/.config/btop/btop.conf"
  run doctor
  [ "$status" -eq 1 ]
  [ "$output" = "✗ omamac — 1 problem
  ✗ Homebrew in your shell — ~/.zprofile does not put Homebrew on PATH. Fix: Run the one-liner again
✓ Terminal — working
✓ Theme — Tokyo Night
  ℹ System monitor colours (btop) — your own btop config is kept, so themes don't reach btop
✓ macOS — nothing picked" ]
}

@test "plain text --all: every check by area, its name, what it is and where" {
  healthy_mac
  run doctor --all
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | sed -n 1,5p)" = "omamac
✓ Homebrew — the app store for command-line tools; omamac installs everything with it
    See: $OMAMAC_TEST_BREW_PREFIX/bin/brew
✓ bash for omamac — omamac's own scripts run in bash; your shell stays zsh
    See: $OMAMAC_TEST_BREW_PREFIX/bin/bash" ]
  printf '%s\n' "$output" | grep -qxF 'Terminal'
  printf '%s\n' "$output" | grep -qxF 'Theme · Tokyo Night'
  printf '%s\n' "$output" | grep -qxF 'macOS'
  printf '%s\n' "$output" | grep -qxF '    See: ~/.zprofile'
  [ "$(printf '%s\n' "$output" | tail -n 2)" = "How omamac does each of these:
github.com/tunacinsoy/omamac#what-it-changes" ]
}

@test "--all's README link names a heading the README has" {
  grep -qx '## What it changes' "$REPO_ROOT/README.md"
}

@test "doctor with an unknown argument: usage, exit 2" {
  healthy_mac
  run doctor --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: omamac <command>"* ]]
  [[ "$output" == *"doctor --all"* ]]
  run doctor --all extra
  [ "$status" -eq 2 ]
}

@test "terminal look: a healthy Mac is four area rows, the tools sheet, the count line" {
  healthy_mac
  healthy_apps vlc
  app_version VLC.app 3.0.21
  terminal_look
  run doctor
  [ "$status" -eq 0 ]
  [ "$(shown)" = "  ✓ omamac          working
  ✓ Terminal        working
  ✓ Theme           Tokyo Night
  ✓ macOS           nothing picked
Your tools and apps
╭──────┬────────╮
│ Apps │        │
│ VLC  │ 3.0.21 │
╰──────┴────────╯
22 fine" ]
  [[ "$output" == *$'\e[2mworking\e[0m'* ]]
  [[ "$output" == *$'\e[2mTokyo Night\e[0m'* ]]
  [[ "$output" != *"To fix"* ]]
}

@test "terminal look: a problem with its fix and a note under their areas" {
  healthy_mac
  : > "$HOME/.zprofile"
  mkdir -p "$HOME/.config/btop"
  echo mine > "$HOME/.config/btop/btop.conf"
  terminal_look
  run doctor
  [ "$status" -eq 1 ]
  [ "$(shown)" = "  ✗ omamac          1 problem
    ✗ Homebrew in your shell — ~/.zprofile does not put Homebrew on PATH
      Fix: Run the one-liner again
  ✓ Terminal        working
  ✓ Theme           Tokyo Night
    ℹ System monitor colours (btop) — your own btop config is kept, so themes
      don't reach btop
  ✓ macOS           nothing picked
1 problem · 1 note · 19 fine" ]
  [[ "$output" == *$'\e[31mHomebrew in your shell — ~/.zprofile does not put Homebrew on PATH\e[0m'* ]]
}

@test "terminal look: two problems in one area, and a gone pick's two ways out" {
  healthy_mac
  rm "$HOME/.config/omamac/starship.toml"
  choose languages "go rust"
  mise_has go
  gum_answers leave
  terminal_look
  run doctor
  [ "$status" -eq 1 ]
  [[ "$(shown)" == *"  ✗ omamac          1 problem
    ✗ Rust — you chose it, but mise no longer has it
      Fix: omamac update puts it back; omamac uninstall rust drops it
"* ]]
  [[ "$(shown)" == *"  ✗ Theme           1 problem
    ✗ Theme colours — .config/omamac/starship.toml missing
      Fix: omamac update
"* ]]
  shown | grep -qxF '2 problems · 19 fine'
}

@test "terminal look --all: every check under its area, with what it is and where" {
  healthy_mac
  terminal_look
  run doctor --all
  [ "$status" -eq 0 ]
  [[ "$(shown)" == "omamac
  ✓ Homebrew
    the app store for command-line tools; omamac installs everything with it
    See:"* ]]
  [[ "$(shown)" == *"Theme · Tokyo Night
  ✓ Code editor (neovim)
    its setup, LazyVim, follows your theme
    See: ~/.config/nvim
"* ]]
  [[ "$output" == *$'\e[2momamac\'s own scripts run in bash; your shell stays zsh\e[0m'* ]]
  [ "$(shown | grep -c '^  ✓ ')" -eq 21 ]
  shown | grep -qxF '21 fine'
  [ "$(shown | tail -n 2)" = "How omamac does each of these:
github.com/tunacinsoy/omamac#what-it-changes" ]
}

@test "terminal look --all: a ✗ shows its problem, red, and its fix" {
  healthy_mac
  : > "$HOME/.zprofile"
  terminal_look
  run doctor --all
  [ "$status" -eq 1 ]
  [[ "$(shown)" == *"  ✗ Homebrew in your shell
    ~/.zprofile does not put Homebrew on PATH
    Fix: Run the one-liner again
    See: ~/.zprofile
"* ]]
  [[ "$output" == *$'\e[31m~/.zprofile does not put Homebrew on PATH\e[0m'* ]]
}

# everything: a Mac with every check there is to show.
everything() {
  healthy_mac
  healthy_colima
  healthy_apps vlc
  vscode_app
  omamac_lib vscode_theme_install
  settings_set
  choose desktop_widgets yes
  defaults write com.apple.WindowManager StandardHideWidgets -bool true
  defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
  choose dock_autohide yes
  defaults write com.apple.dock autohide -bool true
}

@test "every fine check has a name and says what it is, in one line" {
  everything
  terminal_look
  run doctor --all
  [ "$status" -eq 0 ]
  [ "$(shown | grep -c '^  ✓ ')" -ge 29 ]
  # Each ✓ is followed by its dim explanation, never empty.
  [ -z "$(shown | grep -A1 '^  ✓ ' | grep -vE '^(  ✓ |    [^ S]|--)')" ]
  [ "$(shown | widest)" -le 80 ]
}

@test "every check in doctor's table has a name and an explanation that fits" {
  run "$BASH5" -c "source '$REPO_ROOT/lib/doctor.sh'
    for id in \"\${DOCTOR_CHECKS[@]}\"; do
      n=\${DOCTOR_NAME[\$id]} v=\${DOCTOR_ABOUT[\$id]}
      [ -n \"\$n\" ] && [ -n \"\$v\" ] && [ \"\${#v}\" -le 76 ] || echo \"\$id: \$n: \$v\"
    done"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "every check doctor reports is in its table" {
  # The ids in doctor_report calls that aren't a variable (a pick's own name).
  run bash -c "grep -hoE 'doctor_report (ok|fail|info) [a-z_]+' '$REPO_ROOT/lib/doctor.sh' '$REPO_ROOT/lib/docker.sh' | awk '{print \$3}' | sort -u"
  local id
  for id in $output; do
    grep -qE "^doctor_check $id " "$REPO_ROOT/lib/doctor.sh" || { echo "$id"; return 1; }
  done
  # And those that are: the variables hold ids from the table.
  for id in homebrew bash checkout checkout_clean zprofile_line zshrc_line core neovim herdr ghostty choices mise_dropin macos_settings your_tools your_apps docker_compose docker_buildx desktops window_margins desktop_widgets dock dock_autohide; do
    grep -qE "^doctor_check $id " "$REPO_ROOT/lib/doctor.sh" || { echo "$id"; return 1; }
  done
}

@test "every See path exists after a healthy install" {
  everything
  run doctor --all
  [ "$status" -eq 0 ]
  local line path n=0
  while IFS= read -r line; do
    path=${line#    See: }
    case $path in
      '~'*) path=$HOME${path#\~} ;;
      /*) ;;
      *) continue ;;
    esac
    [ -e "$path" ] || { echo "missing: $path"; return 1; }
    n=$((n + 1))
  done < <(printf '%s\n' "$output" | grep '^    See: ')
  [ "$n" -ge 18 ]
}

@test "terminal look: a broken Mac's report fits 80 columns, short and --all" {
  everything
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/brew"
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/btop"
  echo mine > "$HOME/.config/btop/btop.conf"
  terminal_look
  run doctor
  [ "$status" -eq 1 ]
  [ "$(shown | widest)" -le 80 ]
  [[ "$(shown)" == *"Fix: Run the one-liner"* ]]
  run doctor --all
  [ "$status" -eq 1 ]
  [ "$(shown | widest)" -le 80 ]
}

@test "terminal look: Your tools and apps is one sheet, a group per kind, with versions" {
  healthy_mac
  choose languages 'go python'
  mise_has go
  echo 3.14.0 > "$OMAMAC_TEST_BREW_PREFIX/mise/python"
  echo '{"python":{"name":"python","requested":"latest","current":"3.14.0","latest":"3.14.2"}}' \
    > "$OMAMAC_TEST_BREW_PREFIX/mise-outdated.json"
  healthy_apps vlc wispr-flow
  app_version VLC.app 3.0.21
  app_version "Wispr Flow.app" 1.4.2
  terminal_look
  run doctor
  [ "$status" -eq 0 ]
  shown | grep -qxF '22 fine · 1 update waiting: omamac update'
  [[ "$output" == *$'\e[33m1 update waiting: omamac update\e[0m'* ]]
  [ "$(shown | sed -n '/^Your tools and apps$/,/╯/p')" = "Your tools and apps
╭────────────┬────────┬───────────────╮
│ Languages  │        │               │
│ Go         │ 1.0    │ latest        │
│ Python     │ 3.14.0 │ 3.14.2 is out │
│ Apps       │        │               │
│ VLC        │ 3.0.21 │               │
│ Wispr Flow │ 1.4.2  │               │
╰────────────┴────────┴───────────────╯" ]
  [[ "$output" == *$'\e[1mYour tools and apps\e[0m'* ]]
  [[ "$output" == *$'\e[1mLanguages\e[0m'* ]]
  [[ "$output" == *$'\e[33m3.14.2 is out\e[0m'* ]]
  [[ "$output" == *$'\e[2mlatest\e[0m'* ]]
}

@test "terminal look: only apps, no newer column" {
  healthy_mac
  healthy_apps vlc
  app_version VLC.app 3.0.21
  terminal_look
  run doctor
  [ "$status" -eq 0 ]
  [ "$(shown | sed -n '/^Your tools and apps$/,/╯/p')" = "Your tools and apps
╭──────┬────────╮
│ Apps │        │
│ VLC  │ 3.0.21 │
╰──────┴────────╯" ]
}
