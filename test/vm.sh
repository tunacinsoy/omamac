#!/opt/homebrew/bin/bash
# test/vm.sh <branch> <fixture>: prove a pushed commit in a throwaway Tart VM,
# running the one-liner exactly as a stranger would, then post the `vm` commit
# status the merge rule requires. Runs on the dev Mac; exits 0 on pass, 1 on fail.
set -Eeuo pipefail

REPO=tunacinsoy/omamac
IMAGE=omamac-clean
TEST_DIR="$(cd "$(dirname "$0")" && pwd -P)"
VM_EXP="$TEST_DIR/vm.exp"

info() { echo "ℹ $*" >&3; }
refuse() {
  echo "✗ $*" >&2
  exit 1
}
vm() { "$VM_EXP" "$ip" "$1"; }

[ $# -eq 2 ] || refuse "usage: test/vm.sh <branch> <fixture>"
branch=$1 fixture=$2

# 1. Refuse to start unless everything is in place. Nothing is created or posted yet.
command -v tart >/dev/null || refuse "Tart is missing: brew install openai/tools/tart"
command -v gh >/dev/null || refuse "gh is missing: brew install gh"
gh auth status >/dev/null 2>&1 || refuse "gh isn't logged in: gh auth login"
[ -x /usr/bin/expect ] || refuse "expect is missing"
tart get "$IMAGE" >/dev/null 2>&1 || refuse "$IMAGE is missing: run test/image.sh first"
# Both go into a shell command in the VM, so keep them to plain characters.
[[ $branch =~ ^[A-Za-z0-9._/-]+$ ]] || refuse "'$branch' isn't a plain branch name"
[[ $fixture =~ ^[A-Za-z0-9_-]+$ ]] || refuse "'$fixture' isn't a plain fixture name"
[ -f "$TEST_DIR/fixtures/$fixture.env" ] || refuse "No fixture '$fixture': test/fixtures/$fixture.env is missing"
# Homebrew resets sudo before a cask step that needs it, then asks for the
# password itself. A fixture whose casks do that says how often per command.
brew_passwords=0
if [ -f "$TEST_DIR/fixtures/$fixture.brew-passwords" ]; then
  brew_passwords=$(<"$TEST_DIR/fixtures/$fixture.brew-passwords")
  [[ $brew_passwords =~ ^[0-9]$ ]] || refuse "test/fixtures/$fixture.brew-passwords must hold one digit"
fi
# All of steps.sh is one vm.exp call, so uninstalling several password apps
# adds up. A separate count keeps the first run's limit tight.
steps_passwords=$brew_passwords
if [ -f "$TEST_DIR/fixtures/$fixture.steps-passwords" ]; then
  steps_passwords=$(<"$TEST_DIR/fixtures/$fixture.steps-passwords")
  [[ $steps_passwords =~ ^[0-9]$ ]] || refuse "test/fixtures/$fixture.steps-passwords must hold one digit"
fi
cd "$TEST_DIR/.."
changes=$(git status --porcelain)
[ -z "$changes" ] || refuse "The working tree has changes; commit or stash them first:
$changes"
sha=$(git rev-parse HEAD)
remote=$(git ls-remote origin "refs/heads/$branch" | cut -f1) || refuse "Couldn't reach origin"
[ -n "$remote" ] || refuse "'$branch' isn't on GitHub: push first"
[ "$sha" = "$remote" ] || refuse "HEAD ($sha) isn't origin/$branch ($remote): push first"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
# The fixture keeps two runs of one commit, started in the same second, apart.
vm_name="omamac-test-${sha:0:7}-$fixture-$stamp"
raw="https://raw.githubusercontent.com/$REPO/$sha"
logs="$TEST_DIR/logs"
log="$logs/$stamp-${branch//\//-}-$fixture.log"
mkdir -p "$logs"
# Progress lines go to the terminal (fd 3); everything else goes to the log.
exec 3>&1 >"$log" 2>&1
echo "Testing $branch at $sha with fixture $fixture"

step=boot
ip=''

# 7, 8. However the script ends: copy the VM's omamac logs out, post the status,
# and stop and delete the VM.
finish() {
  local status=$? state description previous
  set +e
  if [ -n "$ip" ]; then
    echo "--- omamac's logs in the VM"
    OMAMAC_VM_TIMEOUT=60 vm 'cat ~/.local/state/omamac/logs/*.log'
  fi
  tart stop "$vm_name" >/dev/null 2>&1
  tart delete "$vm_name" >/dev/null 2>&1
  # One `vm` status per commit, and the last post wins: a pass of one fixture
  # must not cover another fixture's fail on the same commit.
  if [ "$status" -eq 0 ]; then
    if ! previous=$(gh api "repos/$REPO/commits/$sha/status" \
      --jq '.statuses[] | select(.context == "vm") | .state'); then
      status=1 step="reading the commit's vm status"
    elif [ "$previous" = failure ]; then
      status=1 step='an earlier run on this commit, which failed (push a new commit to run again)'
    fi
  fi
  if [ "$status" -eq 0 ]; then
    state=success description="$fixture: passed"
  else
    state=failure description="$fixture: failed at $step"
  fi
  if ! gh api -X POST "repos/$REPO/statuses/$sha" -f state="$state" -f context=vm \
    -f description="$description" >/dev/null; then
    echo "✗ Couldn't post the vm status" >&3
    # Without the status the merge rule can't see a pass, so it isn't one.
    [ "$status" -ne 0 ] || { status=1 step='posting the vm status'; }
  fi
  if [ "$status" -eq 0 ]; then
    echo "✓ $branch ($fixture) passed at ${sha:0:7}. Log: $log" >&3
  else
    echo "✗ $branch ($fixture) failed at $step. Log: $log" >&3
    status=1
  fi
  exit "$status"
}
trap finish EXIT

# 2. Clone and boot.
info "Booting $vm_name"
tart clone "$IMAGE" "$vm_name"
tart run --no-graphics "$vm_name" &
ip=$(tart ip --wait 120 "$vm_name")
# The IP shows up before SSH listens.
for _ in $(seq 60); do
  if OMAMAC_VM_TIMEOUT=30 vm true; then break; fi
  sleep 5
done
OMAMAC_VM_TIMEOUT=30 vm true

# 3. The fixture, where install.sh reads it.
step=fixture
vm "mkdir -p ~/.local/state/omamac && curl -fsSL $raw/test/fixtures/$fixture.env -o ~/.local/state/omamac/choices.env"

# The fixture's before-steps, if it has any: they set the VM up like a used
# Mac (an app installed by hand, a Dock to compare with later). No Homebrew yet.
before="test/fixtures/$fixture.before.sh"
if [ -f "$before" ]; then
  step='before the first run'
  info "Running $before"
  vm "set -o pipefail; f=\$(mktemp) && curl -fsSL $raw/$before -o \$f && zsh -eux -o pipefail \$f </dev/null"
fi

# 4. The one-liner, in an interactive login shell: .zshrc loads as in a Terminal
# window (zsh -lc skips it). zsh has no pipefail by default: without it a
# failed fetch feeds bash nothing, and bash exits 0.
one_liner="zsh -lic 'set -o pipefail; curl -fsSL $raw/boot.sh | OMAMAC_REF=$branch bash'"
# Two password prompts: the ssh login and omamac's one sudo prompt, plus the
# fixture's Homebrew prompts. One more fails.
run_one_liner() { OMAMAC_VM_MAX_PASSWORDS=$((2 + brew_passwords)) vm "$one_liner"; }
step='first run'
info "Running the one-liner"
run_one_liner

# 5. The checkout is the tested commit, and a new Terminal window finds omamac.
step='checks after the first run'
vm "[ \"\$(git -C ~/.local/share/omamac rev-parse HEAD)\" = $sha ]"
vm "zsh -lic 'omamac doctor'"

# 6. A second run changes nothing. The markers cut out ssh's own lines; the
# whole output also goes to the log (stderr), so a failure there shows why.
# Requiring the checkout line rejects an empty record and proves the checkout
# is still the tested commit.
fingerprint() {
  vm "set -o pipefail; echo fingerprint-begin && curl -fsSL $raw/test/fingerprint.sh | /bin/bash && echo fingerprint-end" |
    tr -d '\r' | tee /dev/stderr | sed -n '/^fingerprint-begin$/,/^fingerprint-end$/p' >"$1"
  grep -qx fingerprint-end "$1"
  grep -qx "checkout: $sha" "$1"
}
step=fingerprint
fingerprint "${log%.log}-before.txt"
step='second run'
info "Running the one-liner again"
run_one_liner
step='fingerprint after the second run'
fingerprint "${log%.log}-after.txt"
step='comparing fingerprints'
echo "--- fingerprint diff (before, after)"
# Shown on the terminal too: it is the reason for the failure.
diff "${log%.log}-before.txt" "${log%.log}-after.txt" | tee /dev/fd/3
step='doctor after the second run'
vm "zsh -lic 'omamac doctor'"

# 9. The fixture's own steps (update, uninstall...), if it has any.
steps="test/fixtures/$fixture.steps.sh"
if [ -f "$steps" ]; then
  step=steps
  info "Running $steps"
  OMAMAC_VM_MAX_PASSWORDS=$((1 + steps_passwords)) vm "set -o pipefail; f=\$(mktemp) && curl -fsSL $raw/$steps -o \$f && zsh -lic \"zsh -eux -o pipefail \$f </dev/null\""
  step='doctor after the steps'
  vm "zsh -lic 'omamac doctor'"
fi
