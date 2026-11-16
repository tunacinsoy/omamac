#!/opt/homebrew/bin/bash
# test/image.sh: build omamac-clean, the image every VM test starts from. It is
# Cirrus's vanilla macOS made to behave like a fresh Mac: sudo asks for the
# password and Gatekeeper is on. Run on the dev Mac, rarely: at first setup and
# when a new macOS ships.
set -Eeuo pipefail

# Change this when the next macOS ships.
BASE=ghcr.io/cirruslabs/macos-golden-gate-vanilla:latest

IMAGE=omamac-clean
NEW=omamac-clean-new
VM_EXP="$(cd "$(dirname "$0")" && pwd -P)/vm.exp"

info() { echo "ℹ $*"; }
fail() {
  echo "✗ $*" >&2
  exit 1
}
vm() { "$VM_EXP" "$ip" "$1"; }

# Stop and delete the half-built image however the script ends.
cleanup() {
  tart stop "$NEW" >/dev/null 2>&1 || true
  tart delete "$NEW" >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v tart >/dev/null || fail "Tart is missing: brew install openai/tools/tart"
[ -x /usr/bin/expect ] || fail "expect is missing"

cleanup # a leftover from an interrupted run
info "Cloning $BASE"
tart clone "$BASE" "$NEW"
# The base's 50 GB disk has too little room for the background OS update macOS
# prepares (about 9 GB). The guest grows into the bigger disk on its own. tart
# set refuses to shrink, so a base bigger than this stops here: raise the number.
tart set "$NEW" --disk-size 80

info "Booting"
tart run --no-graphics "$NEW" >/dev/null &
ip=$(tart ip --wait 300 "$NEW") || fail "$NEW got no IP address in 5 minutes"

# The IP shows up before SSH listens.
for _ in $(seq 60); do
  if OMAMAC_VM_TIMEOUT=30 vm true >/dev/null 2>&1; then break; fi
  sleep 5
done
OMAMAC_VM_TIMEOUT=30 vm true >/dev/null 2>&1 || fail "No SSH login to $NEW at $ip in 5 minutes"

info "Making sudo ask for the password and turning Gatekeeper on"
vm 'sudo rm /etc/sudoers.d/admin-nopasswd'
vm 'sudo spctl --global-enable'

info "Checking it behaves like a fresh Mac"
vm '! command -v brew && [ ! -e /opt/homebrew ]' || fail "Homebrew is in the base image"
vm 'sudo -k; ! sudo -n true' || fail "sudo still works without a password"
vm 'spctl --status | grep -qx "assessments enabled"' ||
  fail "Gatekeeper is still off: macOS needs it turned on in System Settings > Privacy & Security"
# shellcheck disable=SC2016 # the VM's shell expands these
vm 'free=$(df -g / | awk "NR == 2 {print \$4}"); echo "Free: $free GB"; [ "$free" -ge 30 ]' ||
  fail "The VM's disk has less than 30 GB free: the guest didn't grow into the bigger disk"

info "Saving it as $IMAGE"
tart stop "$NEW"
wait || true # for tart run to exit; its status after a stop says nothing
if tart get "$IMAGE" >/dev/null 2>&1; then tart delete "$IMAGE"; fi
tart rename "$NEW" "$IMAGE"
# Exactly one image stays on disk: drop the downloaded base.
tart prune --entries caches --space-budget 0

echo "✓ $IMAGE is ready"
