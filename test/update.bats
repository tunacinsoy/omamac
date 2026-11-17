load helpers/common

bats_require_minimum_version 1.5.0

# The formulas update may upgrade: the core, then bash and gum.
OMAMAC_FORMULAS='starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli bash gum'

setup() {
  setup_sandbox
  install_fake_brew
  # A failed pull keeps its log in TMPDIR; keep that in the sandbox too.
  export TMPDIR="$BATS_TEST_TMPDIR"
  # shellcheck disable=SC2086 # one formula per word
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install $OMAMAC_FORMULAS
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  # The user's checkout is a clone of a local origin. Origin holds this tree's
  # update.sh, lib/ and config/ as they are now, so uncommitted work is tested.
  ORIGIN="$BATS_TEST_TMPDIR/origin"
  CHECKOUT="$HOME/.local/share/omamac"
  mkdir -p "$ORIGIN"
  cp -R "$REPO_ROOT/update.sh" "$REPO_ROOT/lib" "$REPO_ROOT/config" "$ORIGIN/"
  git -C "$ORIGIN" init -q -b main
  commit_all "$ORIGIN" origin
  git clone -q "$ORIGIN" "$CHECKOUT"
  # Only the update's own brew calls.
  : > "$STUB_LOG"
}

commit_all() {
  git -C "${1:?commit_all needs a folder}" add -A
  git -C "$1" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m "$2"
}

# update: omamac update, only ever in the sandbox, never on the real Mac.
update() {
  if [ -z "${BATS_TEST_TMPDIR:-}" ] || [[ $HOME != "$BATS_TEST_TMPDIR"/* ]]; then
    echo "update.bats: HOME isn't the sandbox; not running omamac update" >&2
    return 1
  fi
  "$BASH5" "$REPO_ROOT/bin/omamac" update
}

# Every file under HOME with its checksum and mtime, except the logs and
# git's own files (a pull rewrites FETCH_HEAD); the checkout's HEAD is checked apart.
snapshot() {
  (cd "$HOME" && find . -type f -not -path './.local/state/omamac/logs/*' -not -path './.local/share/omamac/.git/*' | sort |
    while read -r f; do echo "$f $(shasum < "$f") $(stat -f %m "$f")"; done)
}

@test "pulls, then runs the new update.sh" {
  echo 'echo "new code"' > "$ORIGIN/update.sh"
  commit_all "$ORIGIN" 'new code'
  run update
  [ "$status" -eq 0 ]
  [[ "$output" == *"new code"* ]]
  [ "$(git -C "$CHECKOUT" rev-parse HEAD)" = "$(git -C "$ORIGIN" rev-parse HEAD)" ]
}

@test "local edits stop it before any change" {
  echo '# mine' >> "$CHECKOUT/config/zshrc"
  run update
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ omamac's code has local edits, so update stopped. Fix: git -C ~/.local/share/omamac status, to see them."* ]]
  run ! grep -q '^brew' "$STUB_LOG"
  [ ! -e "$HOME/.config/omamac" ]
  [ ! -e "$HOME/.local/state/omamac/logs" ]
}

@test "an untracked file doesn't block it" {
  : > "$CHECKOUT/.DS_Store"
  run update
  [ "$status" -eq 0 ]
  [[ "$output" == *"omamac and your tools are up to date."* ]]
}

@test "a diverged branch stops it before any change" {
  echo '# theirs' >> "$ORIGIN/config/zshrc"
  commit_all "$ORIGIN" theirs
  echo '# mine' >> "$CHECKOUT/config/zshrc"
  commit_all "$CHECKOUT" mine
  # macOS's TMPDIR ends in a slash; the log path must not show "//".
  TMPDIR="$BATS_TEST_TMPDIR/" run update
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ omamac couldn't update its code. Fix: check your internet connection, or run git -C ~/.local/share/omamac status to see why."* ]]
  [[ "$output" == *"✗ Log: $BATS_TEST_TMPDIR/omamac-pull."* ]]
  run ! grep -q '^brew' "$STUB_LOG"
  [ ! -e "$HOME/.config/omamac" ]
}

@test "upgrades only omamac's formulas, by name" {
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install wget  # the user's own
  : > "$STUB_LOG"
  run update
  [ "$status" -eq 0 ]
  [ "$(grep '^brew upgrade' "$STUB_LOG")" = "brew upgrade $OMAMAC_FORMULAS" ]
}

@test "a pinned core formula is left out of the upgrade" {
  echo neovim > "$OMAMAC_TEST_BREW_PREFIX/pinned"
  run update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kept neovim at the pinned version."* ]]
  run ! grep -E '^brew upgrade.*neovim' "$STUB_LOG"
  grep -q '^brew upgrade starship ' "$STUB_LOG"
}

@test "asks Homebrew for its list once per step, not per formula" {
  run update
  [ "$status" -eq 0 ]
  # One for the core install, one for the upgrade.
  [ "$(grep -c '^brew list --formula' "$STUB_LOG")" -eq 2 ]
}

@test "a removed core formula comes back first" {
  rm -rf "${OMAMAC_TEST_BREW_PREFIX:?}/Cellar/eza"
  run update
  [ "$status" -eq 0 ]
  install_line=$(grep -n '^brew install eza$' "$STUB_LOG" | cut -d: -f1)
  upgrade_line=$(grep -n '^brew upgrade' "$STUB_LOG" | cut -d: -f1)
  [ -n "$install_line" ]
  [ "$install_line" -lt "$upgrade_line" ]
}

@test "writes no include line" {
  run update
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.zshrc" ]
  [ ! -e "$HOME/.zprofile" ]
}

@test "a second update changes no file" {
  run update
  [ "$status" -eq 0 ]
  first=$(snapshot)
  head=$(git -C "$CHECKOUT" rev-parse HEAD)
  sleep 1.1
  run update
  [ "$status" -eq 0 ]
  [ "$(snapshot)" = "$first" ]
  [ "$(git -C "$CHECKOUT" rev-parse HEAD)" = "$head" ]
}

@test "logs to a new file" {
  run update
  [ "$status" -eq 0 ]
  logs=("$HOME"/.local/state/omamac/logs/*.log)
  [ "${#logs[@]}" -eq 1 ]
  [ -f "${logs[0]}" ]
  [[ "$output" == *"Log: ${logs[0]}"* ]]
  [[ "$output" == *"omamac and your tools are up to date."* ]]
}

@test "keeps only the newest 10 logs" {
  local dir="$HOME/.local/state/omamac/logs" i
  mkdir -p "$dir"
  for i in $(seq 1 12); do : > "$dir/$(printf '20200101T0000%02dZ' "$i").log"; done
  run update
  [ "$status" -eq 0 ]
  [ "$(find "$dir" -type f | wc -l)" -eq 10 ]
  [ ! -e "$dir/20200101T000003Z.log" ]
  [ -e "$dir/20200101T000004Z.log" ]
}

@test "no saved answers: stops with the fix" {
  rm "$CHOICES_FILE"
  run update
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ omamac doesn't know your answers. Fix: run the one-liner."* ]]
  run ! grep -q '^brew' "$STUB_LOG"
}

@test "a failing step names itself and says to run update again" {
  rm -rf "${OMAMAC_TEST_BREW_PREFIX:?}/Cellar/eza"
  T_BREW_FAIL=1 run update
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while installing the core tools."* ]]
  [[ "$output" == *"run omamac update again"* ]]
  run ! grep -q '^brew upgrade' "$STUB_LOG"
}
