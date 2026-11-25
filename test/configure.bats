load helpers/common
load helpers/dock

bats_require_minimum_version 1.5.0

# The formulas a finished first run has: the core, then bash and gum.
OMAMAC_FORMULAS='starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq bash gum'

setup() {
  setup_sandbox
  install_fake_brew
  export TMPDIR="$BATS_TEST_TMPDIR"
  # shellcheck disable=SC2086 # one formula per word
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install $OMAMAC_FORMULAS
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask ghostty
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  # Only the run's own calls.
  : > "$STUB_LOG"
}

# omamac_configure: omamac configure, only ever in the sandbox, never on the real Mac.
omamac_configure() {
  if [ -z "${BATS_TEST_TMPDIR:-}" ] || [[ $HOME != "$BATS_TEST_TMPDIR"/* ]]; then
    echo "configure.bats: HOME isn't the sandbox; not running omamac configure" >&2
    return 1
  fi
  "$BASH5" "$REPO_ROOT/bin/omamac" configure "$@"
}

# choose <key> <value>: set one saved answer.
choose() { sed -i '' "s/^$1=.*/$1=$2/" "$CHOICES_FILE"; }

prompts() { grep -E '^gum (choose|confirm)' "$STUB_LOG" || true; }

# The choices file's checksum and mtime.
choices_stamp() { echo "$(shasum < "$CHOICES_FILE") $(stat -f %m "$CHOICES_FILE")"; }

REC() { echo "$HOME/.local/state/omamac/macos-settings.tsv"; }

# settings_on <answer> [<code>]: what a first run with that answer yes left.
# The code sets more answers.
settings_on() {
  "$BASH5" -c "
    set -Eeuo pipefail
    OMAMAC_CHECKOUT='$REPO_ROOT'
    for f in paths ui questions choices core apps settings dock; do source '$REPO_ROOT/lib/'\$f.sh; done
    CHOICES[$1]=yes; ${2:-:}; settings_apply" > /dev/null
  choose "$1" yes
  : > "$STUB_LOG"
}

# desktops_on: what a first run with desktops=yes left, Reduce motion off before.
desktops_on() {
  defaults write com.apple.Accessibility ReduceMotionEnabled -int 0
  settings_on desktops
}

DOCK_RECORD_REL=.local/state/omamac/dock-before.plist

# vm_exp_safe: no line of the output holds a prompt test/vm.exp would answer
# or fail on, so configure's on and off run in the VM with none.
vm_exp_safe() {
  run ! grep -E '(Remove|Let Homebrew take over|Also remove) [^?]*\?|Install\?|[Pp]assword:|\([yY]/[nN]\)|\[[yY]/[nN]\]' <<< "$(printf '%s\n' "$output" | uncoloured)"
}

@test "no setting: the menu shows each setting with its state" {
  choose window_margins yes
  choose dock yes
  gum_answers window-margins no
  run omamac_configure
  [ "$status" -eq 0 ]
  [ "$(prompts | sed -n 1p)" = "gum choose --header What do you want to change? --label-delimiter=: Desktops as workspaces (off):desktops Window margins (on):window-margins Desktop widgets (off):desktop-widgets Dock cleanup (on):dock Dock auto-hide (off):dock-autohide Tap to click (off):tap-to-click Three-finger drag (off):three-finger-drag" ]
  [ "$(prompts | sed -n 2p)" = "gum confirm --default=false Turn off Window margins?" ]
  [[ "$output" == *"Nothing changed."* ]]
  grep -qx 'window_margins=yes' "$CHOICES_FILE"
}

@test "no setting: a setting with no answer shows off" {
  sed -i '' '/^dock_autohide=/d' "$CHOICES_FILE"
  gum_answers "exit 130"
  run omamac_configure
  [ "$status" -eq 130 ]
  [[ "$(prompts)" == *"Dock auto-hide (off):dock-autohide "* ]]
}

@test "no setting: Esc stops, nothing changed" {
  before=$(choices_stamp)
  gum_answers "exit 1"
  run omamac_configure
  [ "$status" -eq 130 ]
  [ "$(choices_stamp)" = "$before" ]
}

@test "dock-autohide on: no question, the setting is set and saved" {
  gum_answers
  run omamac_configure dock-autohide on
  [ "$status" -eq 0 ]
  [ -z "$(prompts)" ]
  [[ "$output" == *"✓ Dock auto-hide is on"* ]]
  [ "$(defaults read com.apple.dock autohide)" = 1 ]
  grep -qx 'dock_autohide=yes' "$CHOICES_FILE"
  grep -q $'^com.apple.dock\tautohide\tabsent$' "$(REC)"
  grep -qx 'killall Dock' "$STUB_LOG"
  vm_exp_safe
}

@test "dock-autohide on sets only that setting" {
  # A setting already yes that the user changed by hand is left to update.
  settings_on window_margins
  defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
  gum_answers
  run omamac_configure dock-autohide on
  [ "$status" -eq 0 ]
  [ "$(defaults read com.apple.WindowManager EnableTiledWindowMargins)" = 0 ]
  [[ "$output" != *"Window margins"* ]]
}

@test "dock-autohide by question: what changes, Turn on?, then set" {
  gum_answers yes
  run omamac_configure dock-autohide
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock auto-hide: the Dock hides when you're not using it."* ]]
  [ "$(prompts)" = "gum confirm --default=false Turn on Dock auto-hide?" ]
  [ "$(defaults read com.apple.dock autohide)" = 1 ]
  grep -qx 'dock_autohide=yes' "$CHOICES_FILE"
}

@test "dock-autohide by question, no: nothing changes" {
  before=$(choices_stamp)
  gum_answers no
  sleep 1.1
  run omamac_configure dock-autohide
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing changed."* ]]
  [ "$(choices_stamp)" = "$before" ]
  run ! grep -q '^defaults write' "$STUB_LOG"
}

@test "Ctrl-C at Turn on?: exit 130, nothing changed" {
  before=$(choices_stamp)
  gum_answers "exit 130"
  run omamac_configure desktops
  [ "$status" -eq 130 ]
  [ "$(choices_stamp)" = "$before" ]
  run ! grep -q '^defaults write' "$STUB_LOG"
}

@test "already on: says so, changes nothing" {
  settings_on dock_autohide
  before=$(choices_stamp)
  gum_answers
  sleep 1.1
  run omamac_configure dock-autohide on
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock auto-hide is already on."* ]]
  [ "$(choices_stamp)" = "$before" ]
  run ! grep -q '^defaults write' "$STUB_LOG"
}

@test "already off: says so, changes nothing" {
  before=$(choices_stamp)
  gum_answers
  sleep 1.1
  run omamac_configure desktops off
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktops as workspaces is already off."* ]]
  [ "$(choices_stamp)" = "$before" ]
  [ -z "$(prompts)" ]
}

@test "desktops on: every key, Ctrl 1–6 reloaded" {
  gum_answers
  run omamac_configure desktops on
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Desktops as workspaces is on"* ]]
  [ "$(defaults read com.apple.dock mru-spaces)" = 0 ]
  [ "$(defaults read NSGlobalDomain AppleSpacesSwitchOnActivate)" = 1 ]
  grep -qx 'activateSettings -u' "$STUB_LOG"
  grep -qx 'desktops=yes' "$CHOICES_FILE"
}

@test "desktops by question: the box says what changes" {
  gum_answers yes
  run omamac_configure desktops
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktops as workspaces: desktops keep their order, switching to an app goes to its desktop, Ctrl 1–6 jump to desktops 1 to 6, and Reduce motion turns on."* ]]
}

@test "desktops off by question: puts every key back" {
  desktops_on
  gum_answers yes
  run omamac_configure desktops
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktops as workspaces: your earlier Spaces, app-switching, Ctrl 1–6 and Reduce motion settings."* ]]
  [ "$(prompts)" = "gum confirm --default=false Turn off Desktops as workspaces?" ]
  [[ "$output" == *"✓ Desktops as workspaces is off"* ]]
  grep -qx 'desktops=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
  run defaults read com.apple.dock mru-spaces
  [ "$status" -ne 0 ]
  # The clean Mac had no Ctrl 1–6 entries; none is left, and macOS reloads.
  [ "$(plutil -extract AppleSymbolicHotKeys raw "$T_DEFAULTS_DIR/com.apple.symbolichotkeys.plist")" = "" ]
  grep -qx 'activateSettings -u' "$STUB_LOG"
  [ "$(defaults read com.apple.Accessibility ReduceMotionEnabled)" = 0 ]
}

@test "window-margins off: no question, the earlier value back" {
  settings_on window_margins
  gum_answers
  run omamac_configure window-margins off
  [ "$status" -eq 0 ]
  [ -z "$(prompts)" ]
  [[ "$output" == *"✓ Window margins is off"* ]]
  grep -qx 'window_margins=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
  run defaults read com.apple.WindowManager EnableTiledWindowMargins
  [ "$status" -ne 0 ]
  vm_exp_safe
}

@test "desktop-widgets off: both keys back to what they were" {
  choose desktop_widgets yes
  defaults write com.apple.WindowManager StandardHideWidgets -bool true
  defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
  mkdir -p "$(dirname "$(REC)")"
  printf 'com.apple.WindowManager\tStandardHideWidgets\tabsent\ncom.apple.WindowManager\tStageManagerHideWidgets\tboolean\tfalse\n' > "$(REC)"
  gum_answers
  run omamac_configure desktop-widgets off
  [ "$status" -eq 0 ]
  grep -qx 'desktop_widgets=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
  run defaults read com.apple.WindowManager StandardHideWidgets
  [ "$status" -ne 0 ]
  [ "$(defaults read com.apple.WindowManager StageManagerHideWidgets)" = 0 ]
}

@test "off, then on again: the setting is back" {
  settings_on window_margins
  gum_answers
  run omamac_configure window-margins off
  [ "$status" -eq 0 ]
  run omamac_configure window-margins on
  [ "$status" -eq 0 ]
  [ "$(defaults read com.apple.WindowManager EnableTiledWindowMargins)" = 1 ]
  grep -qx 'window_margins=yes' "$CHOICES_FILE"
}

@test "a failed restore leaves the answer yes and the rest recorded" {
  desktops_on
  gum_answers
  T_DEFAULTS_FAIL=NSGlobalDomain:AppleSpacesSwitchOnActivate run omamac_configure desktops off
  [ "$status" -ne 0 ]
  [[ "$output" == *"Fix the problem and run omamac configure desktops off again."* ]]
  grep -qx 'desktops=yes' "$CHOICES_FILE"
  [[ "$(cat "$(REC)")" != *mru-spaces* ]]
  grep -q '^killall Dock' "$STUB_LOG"
  [[ "$(cat "$(REC)")" == *AppleSpacesSwitchOnActivate* ]]
  [[ "$(cat "$(REC)")" == *ReduceMotionEnabled* ]]
  run omamac_configure desktops off
  [ "$status" -eq 0 ]
  grep -qx 'desktops=no' "$CHOICES_FILE"
  [ ! -e "$(REC)" ]
}

@test "a failure while turning on: saved yes, update finishes it" {
  gum_answers
  T_DEFAULTS_FAIL=com.apple.dock:autohide run omamac_configure dock-autohide on
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while setting autohide in com.apple.dock."* ]]
  [[ "$output" == *"Fix the problem and run omamac update."* ]]
  grep -qx 'dock_autohide=yes' "$CHOICES_FILE"
}

@test "dock on: the cleanup runs, show-recents off, the Dock from before kept" {
  dock_seed file:///System/Applications/Mail.app/ file:///Applications/Things.app/ \
    -- "file://$HOME/Downloads/"
  gum_answers
  run omamac_configure dock on
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Dock cleanup is on"* ]]
  [ "$(dock_urls persistent-apps)" = "file:///Applications/Things.app/
file://${OMAMAC_TEST_APPLICATIONS// /%20}/Ghostty.app/" ]
  [ -z "$(dock_urls persistent-others)" ]
  [ "$(defaults read com.apple.dock show-recents)" = 0 ]
  [ -f "$HOME/$DOCK_RECORD_REL" ]
  grep -qx 'dock=yes' "$CHOICES_FILE"
}

@test "dock off by question: the Dock and show-recents go back" {
  dock_seed file:///System/Applications/Mail.app/ file:///Applications/Things.app/ \
    -- "file://$HOME/Downloads/"
  apps=$(dock_urls persistent-apps)
  others=$(dock_urls persistent-others)
  settings_on dock
  [ "$(defaults read com.apple.dock show-recents)" = 0 ]
  gum_answers yes
  run omamac_configure dock
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dock cleanup: your Dock as it was before omamac cleaned it; changes you made to it since are undone."* ]]
  [ "$(prompts)" = "gum confirm --default=false Turn off Dock cleanup?" ]
  [[ "$output" == *"✓ Dock cleanup is off"* ]]
  [ "$(dock_urls persistent-apps)" = "$apps" ]
  [ "$(dock_urls persistent-others)" = "$others" ]
  run defaults read com.apple.dock show-recents
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/$DOCK_RECORD_REL" ]
  grep -qx 'dock=no' "$CHOICES_FILE"
}

@test "dock off by question, no: nothing changes" {
  dock_seed file:///System/Applications/Mail.app/
  settings_on dock
  cp "$T_DEFAULTS_DIR/com.apple.dock.plist" "$BATS_TEST_TMPDIR/after.plist"
  gum_answers no
  run omamac_configure dock
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing changed."* ]]
  cmp "$T_DEFAULTS_DIR/com.apple.dock.plist" "$BATS_TEST_TMPDIR/after.plist"
  [ "$(defaults read com.apple.dock show-recents)" = 0 ]
  [ -f "$HOME/$DOCK_RECORD_REL" ]
  grep -qx 'dock=yes' "$CHOICES_FILE"
}

@test "dock off with no record puts show-recents back only" {
  settings_on dock
  rm "$HOME/$DOCK_RECORD_REL"
  gum_answers
  run omamac_configure dock off
  [ "$status" -eq 0 ]
  run ! grep -q '^defaults import' "$STUB_LOG"
  run defaults read com.apple.dock show-recents
  [ "$status" -ne 0 ]
  grep -qx 'dock=no' "$CHOICES_FILE"
}

@test "dock-autohide off: the setting goes back" {
  settings_on dock_autohide
  gum_answers
  run omamac_configure dock-autohide off
  [ "$status" -eq 0 ]
  run defaults read com.apple.dock autohide
  [ "$status" -ne 0 ]
  grep -qx 'dock_autohide=no' "$CHOICES_FILE"
}

# update names a question added after the first run, and sends the user here.
@test "a new setting answered no: the no is saved, nothing set" {
  sed -i '' '/^desktop_widgets=/d' "$CHOICES_FILE"
  gum_answers no
  run omamac_configure desktop-widgets
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "gum confirm --default=false Turn on Desktop widgets?" ]
  grep -qx 'desktop_widgets=no' "$CHOICES_FILE"
  run ! grep -q '^defaults write' "$STUB_LOG"
}

@test "a new setting with off: the no is saved" {
  sed -i '' '/^desktop_widgets=/d' "$CHOICES_FILE"
  gum_answers
  run omamac_configure desktop-widgets off
  [ "$status" -eq 0 ]
  [[ "$output" == *"Desktop widgets is already off."* ]]
  grep -qx 'desktop_widgets=no' "$CHOICES_FILE"
}

@test "an unknown name lists the settings" {
  gum_answers
  run --separate-stderr omamac_configure nope
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"omamac doesn't know 'nope'. Settings: desktops, window-margins, desktop-widgets, dock, dock-autohide, tap-to-click, three-finger-drag."* ]]
  [ -z "$(prompts)" ]
}

@test "a software name points to install and uninstall" {
  gum_answers
  for name in go vlc docker-desktop wispr-flow; do
    run --separate-stderr omamac_configure "$name"
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"$name isn't a setting: run omamac install $name or omamac uninstall $name."* ]]
  done
  [ -z "$(prompts)" ]
}

@test "a third word other than on or off, or a fourth: usage, exit 2" {
  gum_answers
  run --separate-stderr omamac_configure dock maybe
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Usage: omamac <command>"* ]]
  run --separate-stderr omamac_configure dock on now
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Usage: omamac <command>"* ]]
  [ -z "$(prompts)" ]
}

@test "no saved answers: stops with the fix" {
  rm "$CHOICES_FILE"
  gum_answers
  run omamac_configure dock on
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac doesn't know your answers. Fix: run the one-liner."* ]]
  [ ! -e "$CHOICES_FILE" ]
}

@test "every setting name is a question key with dashes, and none is an install name" {
  run "$BASH5" -c "OMAMAC_CHECKOUT='$REPO_ROOT'
    for lib in paths ui questions choices log core apps clis settings ask add configure; do source '$REPO_ROOT/lib/'\$lib.sh; done
    for k in \"\${SETTINGS_ANSWERS[@]}\"; do
      [ \"\${QUESTION_KIND[\$k]}\" = yesno ] || echo \"not yes/no: \$k\"
      [ \"\$(configure_key \"\${k//_/-}\")\" = \"\$k\" ] || echo \"no name: \$k\"
      ! add_id_key \"\${k//_/-}\" > /dev/null || echo \"also an install name: \$k\"
    done"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# The terminal look (#46): a yellow box with what changes, the same question,
# then one result row.

# shown: $output without its colour codes.
shown() { printf '%s\n' "$output" | uncoloured; }

@test "terminal look: desktops off names what it puts back" {
  desktops_on
  gum_answers yes
  terminal_look
  run omamac_configure desktops
  [ "$status" -eq 0 ]
  [[ "$(shown)" == "╭ Turns off "*"│ Setting    Desktops as workspaces "*"│ Puts back  your earlier Spaces, app-switching, Ctrl 1–6 and Reduce motion "* ]]
  [ "$(shown | tail -1)" = "  ✓ Desktops as workspaces off" ]
  [ "$(shown | widest)" -le 80 ]
}

@test "terminal look: on and off with no question print nothing vm.exp answers" {
  dock_seed file:///System/Applications/Mail.app/
  settings_on dock
  desktops_on
  gum_answers
  terminal_look
  for args in "dock off" "desktops off" "dock-autohide on" "window-margins on" "window-margins off"; do
    # shellcheck disable=SC2086 # two words
    run omamac_configure $args
    [ "$status" -eq 0 ]
    vm_exp_safe
  done
  [ -z "$(prompts)" ]
}

@test "terminal look: dock-autohide on says what changes, then one row" {
  gum_answers yes
  terminal_look
  run omamac_configure dock-autohide
  [ "$status" -eq 0 ]
  [ "$(shown)" = "╭ Turns on ────────────────────────────────────────╮
│ Setting  Dock auto-hide                          │
│ Changes  the Dock hides when you're not using it │
╰──────────────────────────────────────────────────╯
  ✓ Dock auto-hide  on" ]
}
