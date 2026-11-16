# Contributing

## The flow

1. Work on a branch and push it.
2. Open a pull request into `main`.
3. CI runs `bats`: shellcheck, then the bats suite.
4. Run `test/vm.sh <branch> <fixture>` on the PR's head commit. It posts the `vm` status.
5. Tuna merges. Merging stays Tuna's only.

Never run omamac on the development Mac. It runs only inside test VMs.

## The merge gate

`main` takes changes only through pull requests, and only when `bats` and `vm` both passed on the PR's exact head commit, with the branch up to date with `main`. No one can bypass this, admins and agents included. `bats` counts only when GitHub Actions posts it.

Never post `vm` by hand. Only `test/vm.sh` posts it, on a pass.

Gate files (the ruleset, the CI workflow, `test/vm.sh`, `test/vm.exp`, `test/fingerprint.sh`, `test/image.sh`) are written and changed by the agent, but only in a PR whose purpose is the gate itself, never to turn a red check green. CI flags every PR that touches them, so Tuna sees it before merging. Merging stays Tuna's only.

**Trust model.** GitHub can't prove a VM ran, or that the fixture covers what the PR touched. The gate stops accidental merges (stale commits, unpushed changes, a forgotten VM run), not deliberate fakes.

## Tools on the development Mac

```
brew install openai/tools/tart bats-core shellcheck gh
gh auth login
```

If brew asks you to trust the tap first, run `brew trust --formula openai/tools/softnet openai/tools/tart`, then install again. Tart moved from Cirrus Labs to OpenAI; its macOS images still come from ghcr.io/cirruslabs.

## Running the tests

Shellcheck and the bats suite, as CI runs them:

```
git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck
bats test/
```

No test touches your real home folder, the network or your Homebrew.

**The clean image.** Every VM test starts from `omamac-clean`: Cirrus Labs' vanilla macOS, set to ask for the sudo password and with Gatekeeper on, like a fresh Mac. Build it once:

```
test/image.sh
```

When a new macOS ships, change `BASE` in `test/image.sh` (in a PR about the gate) and run it again. It replaces the old image; only one stays on disk.

**The VM loop.** Commit and push first; it refuses a dirty tree or an unpushed commit.

```
test/vm.sh <branch> <fixture>
```

It runs the one-liner twice in a throwaway VM, checks that the second run changed nothing, and posts `vm` on the commit. Fixtures live in `test/fixtures/`. The log goes to `test/logs/`.

## Changing the ruleset

The ruleset lives in `.github/rulesets/main.json`. It was applied once with:

```
gh api -X POST repos/tunacinsoy/omamac/rulesets --input .github/rulesets/main.json
```

To change it, edit the file in a PR about the gate, then update the live ruleset with the same file:

```
id=$(gh api repos/tunacinsoy/omamac/rulesets --jq '.[] | select(.name == "main: bats and a fresh-VM run") | .id')
gh api -X PUT "repos/tunacinsoy/omamac/rulesets/$id" --input .github/rulesets/main.json
```
