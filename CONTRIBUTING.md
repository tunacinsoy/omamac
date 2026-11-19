# Contributing

## The flow

1. Work on a branch and push it.
2. Open a pull request into `main`.
3. CI runs `bats`: shellcheck, then the bats suite.
4. Run `test/vm.sh <branch> <fixture>` on the PR's head commit. It posts the `vm` status.
5. The agent merges once `bats` and `vm` are green and review findings are fixed.

Never run omamac on the development Mac. It runs only inside test VMs.

## The merge gate

`main` takes changes only through pull requests, and only when `bats` and `vm` both passed on the PR's exact head commit, with the branch up to date with `main`. No one can bypass this, admins and agents included. `bats` counts only when GitHub Actions posts it.

Never post `vm` by hand. Only `test/vm.sh` posts it, on a pass or a fail. Only a pass posts success.

Gate files (the ruleset, the CI workflow, `test/vm.sh`, `test/vm.exp`, `test/fingerprint.sh`, `test/image.sh`) are written and changed by the agent, but only in a PR whose purpose is the gate itself, never to turn a red check green. CI flags every PR that touches them, and the agent names them when it reports to Tuna. The agent merges a PR once `bats` and `vm` are green and review findings are fixed; anything that needs Tuna's judgment is raised to Tuna first.

**Trust model.** GitHub can't prove a VM ran, or that the fixture covers what the PR touched. The gate stops accidental merges (stale commits, unpushed changes, a forgotten VM run), not deliberate fakes.

## Tools on the development Mac

```
brew install bash openai/tools/tart bats-core shellcheck gh
gh auth login
```

If brew asks you to trust the tap first, run `brew trust --formula openai/tools/softnet openai/tools/tart`, then install again. Tart moved from Cirrus Labs to OpenAI; its macOS images still come from ghcr.io/cirruslabs.

## Running the tests

Shellcheck and the bats suite, as CI runs them:

```
# CI's shellcheck line skips bin/omamac-herdr-mode; test/hygiene.bats checks it.
git ls-files '*.sh' '*.bash' bin/omamac bin/omamac-herdr-mode test/helpers/fake-* | xargs shellcheck
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

Tests that need mise use a fake, `test/helpers/fake-mise`. Its `T_*` knobs (for example `T_MISE_KEEP`) set what it reports and which tools it keeps.

A change to languages or CLIs runs the `bare`, `languages` and `cloud` fixtures. A change to the macOS settings runs `bare` and `desktop`. A change to Docker runs `bare`, `colima` and `docker-desktop`. A change to apps runs `bare`, `apps`, `adopt` and `docker-desktop`.

A fixture may have a `<name>.brew-passwords`, one digit: how many more times per command Homebrew itself asks for the password. Homebrew resets sudo before a cask step that needs it (Docker Desktop's links in `/usr/local`, Zoom's and Google Drive's installers), so omamac's one prompt doesn't cover it. `test/vm.sh` lets the one-liner and the steps type that many more.

A fixture may have a `<name>.before.sh`. It runs in the VM before the first run, in `zsh -eux` with stdin closed and no Homebrew yet, to set the VM up like a used Mac: an app installed by hand, or a Dock saved to compare with later.

A fixture may have a `<name>.steps.sh`. Its commands run in the VM after the two runs, in `zsh -eux` with stdin closed. Each distinct "Remove …?", "Let Homebrew take over …?" and "Also remove …?" prompt is answered y; any other prompt fails the run. Put every command that prompts before any `zsh -ic`: an interactive zsh takes the terminal and doesn't give it back, so a later prompt can't read the keyboard. Remove an app's quarantine (`xattr -dr com.apple.quarantine <app>`) before opening it: a quarantined app waits on macOS's "Open?" dialog, which nobody can click over SSH, and hangs.

A steps file may use test-only stand-ins for what the VM can't do, each with a comment saying what real hardware or the user does instead: removing the quarantine stands in for the user's Open click, colima runs under emulation because the VM has no nested virtualization.

## Themes

The 13 themes in `themes/` come from [omawsl](https://github.com/tunacinsoy/omawsl)'s themes, which are MIT-licensed through Omarchy (see `themes/LICENSE.omarchy`). Each `ghostty.conf` was converted once from omawsl's terminal palette: `background`, `foreground`, `cursor-color`, `selection-background` and `palette` 0 to 15. ristretto's `neovim.lua` uses the original loctvl842/monokai-pro.nvim, because the fork omawsl names is gone.

## Questions and fixtures

The first-run questions live in one table, `lib/questions.sh`: one `question` line each, with its key, kind, text and options. Each key is a line in `choices.env`; values are ids that later code relies on, so never rename one.

Adding a question means one line in the table and an answer for it in every `test/fixtures/*.env`. The bats suite fails on a fixture with a missing or wrong answer; in the VM, a missing answer would leave a question waiting until the run times out.

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
