load helpers/common

bats_require_minimum_version 1.5.0

# The formulas update may upgrade: the core, then bash and gum.
OMAMAC_FORMULAS='starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq bash gum'

setup() {
  setup_sandbox
  install_fake_brew
  # A failed pull keeps its log in TMPDIR; keep that in the sandbox too.
  export TMPDIR="$BATS_TEST_TMPDIR"
  # shellcheck disable=SC2086 # one formula per word
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install $OMAMAC_FORMULAS
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask ghostty
  CHOICES_FILE="$HOME/.local/state/omamac/choices.env"
  mkdir -p "$(dirname "$CHOICES_FILE")"
  cp "$REPO_ROOT/test/fixtures/bare.env" "$CHOICES_FILE"
  # The user's checkout is a clone of a local origin. Origin holds this tree's
  # update.sh, lib/ and config/ as they are now, so uncommitted work is tested.
  ORIGIN="$BATS_TEST_TMPDIR/origin"
  CHECKOUT="$HOME/.local/share/omamac"
  mkdir -p "$ORIGIN"
  cp -R "$REPO_ROOT/update.sh" "$REPO_ROOT/lib" "$REPO_ROOT/config" "$REPO_ROOT/themes" "$ORIGIN/"
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

@test "every formula pinned: no brew upgrade call" {
  printf '%s\n' $OMAMAC_FORMULAS > "$OMAMAC_TEST_BREW_PREFIX/pinned"
  run update
  [ "$status" -eq 0 ]
  ! grep -q '^brew upgrade' "$STUB_LOG"
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

# choose <key> <value>: set one saved answer.
choose() { sed -i '' "s/^$1=.*/$1=$2/" "$CHOICES_FILE"; }

@test "upgrades chosen cloud formulas by full name" {
  choose cloud_clis 'terraform gh'
  run update
  [ "$status" -eq 0 ]
  [ "$(grep '^brew upgrade' "$STUB_LOG")" = "brew upgrade $OMAMAC_FORMULAS gh hashicorp/tap/terraform" ]
}

@test "a pinned cloud formula is left out by its short name" {
  choose cloud_clis 'terraform gh'
  echo terraform > "$OMAMAC_TEST_BREW_PREFIX/pinned"
  run update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kept hashicorp/tap/terraform at the pinned version."* ]]
  run ! grep -E '^brew upgrade.*terraform' "$STUB_LOG"
}

@test "gcloud: one greedy cask upgrade" {
  choose cloud_clis 'gcloud'
  run update
  [ "$status" -eq 0 ]
  [ "$(grep -c '^brew upgrade --cask' "$STUB_LOG")" -eq 1 ]
  grep -qx 'brew upgrade --cask --greedy gcloud-cli' "$STUB_LOG"
}

@test "azure and gcloud: both casks in one greedy call" {
  choose cloud_clis 'azure gcloud'
  run update
  [ "$status" -eq 0 ]
  [ "$(grep -c '^brew upgrade --cask' "$STUB_LOG")" -eq 1 ]
  grep -qx 'brew upgrade --cask --greedy azure-cli gcloud-cli' "$STUB_LOG"
}

@test "no gcloud: no cask upgrade" {
  choose cloud_clis 'gh'
  run update
  [ "$status" -eq 0 ]
  run ! grep -q '^brew upgrade --cask' "$STUB_LOG"
}

@test "languages: mise upgrade, prune, then rails" {
  choose languages 'ruby go'
  run update
  [ "$status" -eq 0 ]
  up=$(grep -n '^mise upgrade ruby go$' "$STUB_LOG" | cut -d: -f1)
  pr=$(grep -n '^mise prune --tools ruby go$' "$STUB_LOG" | cut -d: -f1)
  rl=$(grep -n '^mise exec ruby -- gem list' "$STUB_LOG" | tail -1 | cut -d: -f1)
  [ -n "$up" ] && [ -n "$pr" ] && [ -n "$rl" ]
  [ "$up" -lt "$pr" ]
  [ "$pr" -lt "$rl" ]
}

@test "elixir upgrades both its tools" {
  choose languages 'elixir'
  run update
  [ "$status" -eq 0 ]
  grep -qx 'mise upgrade erlang elixir' "$STUB_LOG"
  grep -qx 'mise prune --tools erlang elixir' "$STUB_LOG"
}

@test "no languages: no mise call at all" {
  run update
  [ "$status" -eq 0 ]
  run ! grep -q '^mise' "$STUB_LOG"
}

@test "a second update changes no file, with languages chosen" {
  choose languages 'ruby go'
  run update
  [ "$status" -eq 0 ]
  first=$(snapshot)
  sleep 1.1
  run update
  [ "$status" -eq 0 ]
  [ "$(snapshot)" = "$first" ]
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

@test "a failure inside a subshell says omamac stopped once" {
  choose languages go
  T_MISE_UPGRADE_FAIL=1 run update
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while upgrading your languages."* ]]
  [ "$(grep -c 'omamac stopped' <<< "$output")" -eq 1 ]
}

@test "a failing step names itself and says to run update again" {
  rm -rf "${OMAMAC_TEST_BREW_PREFIX:?}/Cellar/eza"
  T_BREW_FAIL=1 run update
  [ "$status" -eq 1 ]
  [[ "$output" == *"omamac stopped while installing the core tools."* ]]
  [[ "$output" == *"run omamac update again"* ]]
  run ! grep -q '^brew upgrade' "$STUB_LOG"
}

# Ghostty's own app folder, writable, like a Mac that allows App Management.
ghostty_app() { mkdir -p "$OMAMAC_TEST_APPLICATIONS/Ghostty.app"; }
# deny_app_management: touch fails inside the app folder only; bats and git need the real touch.
deny_app_management() {
  stub touch 'case "$1" in *.omamac-write-test) echo "touch: $1: Operation not permitted" >&2; exit 1 ;; esac; exec /usr/bin/touch "$@"'
}
# ghostty_outdated: Homebrew says Ghostty is outdated.
ghostty_outdated() { echo ghostty > "$OMAMAC_TEST_BREW_PREFIX/outdated"; }

@test "Ghostty current: no write test, no cask upgrade" {
  ghostty_app
  stub touch
  run update
  [ "$status" -eq 0 ]
  run ! grep -q '^touch' "$STUB_LOG"
  run ! grep -q '^brew upgrade --cask' "$STUB_LOG"
}

@test "Ghostty by hand: never checked or upgraded" {
  rm -rf "${OMAMAC_TEST_BREW_PREFIX:?}/Caskroom/ghostty"
  ghostty_app
  ghostty_outdated
  run update
  [ "$status" -eq 0 ]
  run ! grep -q '^brew outdated' "$STUB_LOG"
  run ! grep -q '^brew upgrade --cask' "$STUB_LOG"
}

@test "Ghostty outdated and allowed: upgraded, without --greedy" {
  ghostty_app
  ghostty_outdated
  run update
  [ "$status" -eq 0 ]
  grep -qx 'brew upgrade --cask ghostty' "$STUB_LOG"
  grep -qx 'brew outdated --cask --quiet ghostty' "$STUB_LOG"
  run ! grep -q 'greedy.*ghostty' "$STUB_LOG"
  [ ! -e "$OMAMAC_TEST_APPLICATIONS/Ghostty.app/.omamac-write-test" ]
}

@test "Ghostty outdated, App Management missing" {
  ghostty_app
  ghostty_outdated
  deny_app_management
  stub open
  run update
  [ "$status" -eq 1 ]
  # Check the output first: a later run replaces it.
  [[ "$output" == *"System Settings → Privacy & Security → App Management"* ]]
  [[ "$output" != *"omamac stopped while"* ]]
  grep -q '^brew upgrade ' "$STUB_LOG"
  run ! grep -q '^brew upgrade --cask.*ghostty' "$STUB_LOG"
  grep -qx 'open x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles' "$STUB_LOG"
}

@test "Ghostty outdated, App Management missing: everything else still upgrades" {
  choose cloud_clis 'gcloud'
  choose languages 'go'
  ghostty_app
  ghostty_outdated
  deny_app_management
  stub open
  run update
  [ "$status" -eq 1 ]
  grep -qx 'brew upgrade --cask --greedy gcloud-cli' "$STUB_LOG"
  grep -qx 'mise upgrade go' "$STUB_LOG"
}

# update's apply_all installs a missing lazydocker first, so all five are upgraded.
@test "update upgrades colima's installed formulas by name, and nothing restarts colima" {
  choose docker colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install colima docker docker-compose docker-buildx
  # colima as install left it: its service registered and the marker written.
  mkdir -p "$OMAMAC_TEST_BREW_PREFIX/services"
  : > "$OMAMAC_TEST_BREW_PREFIX/services/colima"
  : > "$HOME/.local/state/omamac/colima-service"
  : > "$STUB_LOG"
  run update
  [ "$status" -eq 0 ]
  [ "$(grep '^brew upgrade' "$STUB_LOG")" = "brew upgrade $OMAMAC_FORMULAS colima docker docker-compose docker-buildx lazydocker" ]
  [ -z "$(grep -E '^(brew services|colima )' "$STUB_LOG")" ]
  [[ "$output" != *"first start"* ]]
}

@test "update that starts colima's service says so before the log line" {
  # The one-liner failed before the start, so this update is the first.
  choose docker colima
  : > "$STUB_LOG"
  run update
  [ "$status" -eq 0 ]
  grep -qx 'brew services start colima' "$STUB_LOG"
  [[ "$output" == *"colima starts Docker in the background now and at each login."*"The first start downloads Linux and takes a few minutes."*"Log: "* ]]
}

@test "update leaves the user's own docker alone with none" {
  choose docker none
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install docker
  : > "$STUB_LOG"
  run update
  [ "$status" -eq 0 ]
  [ "$(grep '^brew upgrade' "$STUB_LOG")" = "brew upgrade $OMAMAC_FORMULAS" ]
}

# Docker Desktop as install left it: the cask, its app and lazydocker.
desktop_installed() {
  choose docker docker-desktop
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install lazydocker
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask docker-desktop
  : > "$STUB_LOG"
}

@test "update upgrades lazydocker by name for Docker Desktop" {
  desktop_installed
  run update
  [ "$status" -eq 0 ]
  [ "$(grep '^brew upgrade' "$STUB_LOG")" = "brew upgrade $OMAMAC_FORMULAS lazydocker" ]
}

@test "Docker Desktop outdated and allowed: upgraded in the open" {
  desktop_installed
  echo docker-desktop > "$OMAMAC_TEST_BREW_PREFIX/outdated"
  run update
  [ "$status" -eq 0 ]
  grep -qx 'brew outdated --cask --quiet docker-desktop' "$STUB_LOG"
  grep -qx 'brew upgrade --cask docker-desktop' "$STUB_LOG"
  [[ "$output" == *"ℹ Homebrew asks for your password for Docker Desktop's links in /usr/local."* ]]
  run ! grep '^gum spin.*docker-desktop' "$STUB_LOG"
  run ! grep -q 'greedy.*docker-desktop' "$STUB_LOG"
}

@test "Docker Desktop current: no cask upgrade" {
  desktop_installed
  run update
  [ "$status" -eq 0 ]
  run ! grep -q '^brew upgrade --cask' "$STUB_LOG"
}

@test "Docker Desktop by hand: never upgraded" {
  desktop_installed
  rm -rf "${OMAMAC_TEST_BREW_PREFIX:?}/Caskroom/docker-desktop"
  echo docker-desktop > "$OMAMAC_TEST_BREW_PREFIX/outdated"
  run update
  [ "$status" -eq 0 ]
  run ! grep -q '^brew outdated.*docker-desktop' "$STUB_LOG"
  run ! grep -q '^brew upgrade --cask' "$STUB_LOG"
}

@test "Docker Desktop isn't upgraded unless it is the answer" {
  choose docker colima
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install colima docker docker-compose docker-buildx lazydocker
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install --cask docker-desktop
  echo docker-desktop > "$OMAMAC_TEST_BREW_PREFIX/outdated"
  : > "$STUB_LOG"
  run update
  [ "$status" -eq 0 ]
  run ! grep -q 'docker-desktop' "$STUB_LOG"
}

@test "Docker Desktop upgrade fails: update stops with the log" {
  desktop_installed
  echo docker-desktop > "$OMAMAC_TEST_BREW_PREFIX/outdated"
  export T_BREW_UPGRADE_FAIL=1
  run update
  [ "$status" -ne 0 ]
  [[ "$output" == *"Log: $OMAMAC_LOG"* ]]
}

@test "Ghostty and Docker Desktop not allowed: both named, exit 1" {
  desktop_installed
  ghostty_app
  printf 'ghostty\ndocker-desktop\n' > "$OMAMAC_TEST_BREW_PREFIX/outdated"
  deny_app_management
  stub open
  run update
  [ "$status" -eq 1 ]
  [[ "$output" == *"Ghostty and Docker Desktop are not"* ]]
  [[ "$output" == *"Docker Desktop has an update, but macOS won't let your terminal change apps."* ]]
  grep -q '^brew upgrade ' "$STUB_LOG"
  run ! grep -q '^brew upgrade --cask' "$STUB_LOG"
}
