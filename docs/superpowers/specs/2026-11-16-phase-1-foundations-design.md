# Phase 1: foundations — design

Status: draft · 2026-11-16 · Source of truth for the why: [`vision.md`](../../../vision.md)

## Intent

Phase 1 builds the ground every later phase stands on: the one-liner that takes a fresh Mac from nothing to Homebrew, bash 5, `gum` and an omamac checkout; a bare `omamac` command with a working `doctor`; the bats suite; the throwaway-VM test loop; and the merge gate that keeps `main` releasable. Nothing a user would call "the setup" (shell config, Ghostty, apps, questions) is in this phase.

It is done at **Gate A**: in a fresh VM, the public one-liner succeeds, `omamac doctor` passes, and a second run changes nothing.

## Goals

- `curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/main/boot.sh | bash` on a fresh Mac (macOS 27+, Apple Silicon, admin account) ends with Homebrew, Homebrew bash 5, `gum`, the checkout at `~/.local/share/omamac`, and `omamac` on the PATH of a new terminal window.
- Running it again is safe: it updates the checkout and changes nothing else.
- Every failure stops the run with one clear message and the next step.
- `test/vm.sh <branch> <fixture>` proves all of the above in a throwaway VM with nobody at the keyboard, and posts the `vm` status.
- GitHub refuses to merge into `main` without green `bats` and `vm` on the exact head commit of an up-to-date branch.

## Non-goals (later phases)

- First-run questions, `choices.env` being read, "Install? (y/n)" (Phase 2).
- Any real content in `~/.config/omamac/zshrc` beyond the PATH line; starship, neovim, herdr, mise (Phase 3).
- Ghostty, themes, macOS settings (Phase 4). Docker (5). Apps, Dock (6).
- `omamac install`, `update`, `theme`, `uninstall` beyond a "not yet" message.
- Migrations and `~/.local/state/omamac/version`.
- doctor *offering* fixes as y/n questions. In Phase 1 it reports the fix; the offer arrives with the question machinery in Phase 2.

## Anti-goals

Failure even if it technically works:

- The one-liner needs anyone to press a key after typing the password.
- A second run changes a file, a package or the checkout.
- omamac writes anything outside its own folders except the two guarded lines (`~/.zprofile`, `~/.zshrc`), or touches anything on the never-touch list.
- Anything users see mentions apt, Windows or WSL.
- A test is run on the development Mac instead of a VM, or a test VM survives its run.
- The gate can be passed by accident: a stale commit, an unpushed change, or a status from another commit.

## Constraints

- `boot.sh` arrives through a pipe and runs on macOS's `/bin/bash` 3.2: no associative arrays, no `${var,,}`, no `mapfile`, no `[[ -v ]]`. Stdin is the script, so any prompt reads `/dev/tty`. It has no sourced-vs-executed guard: `BASH_SOURCE` is empty when piped and `set -u` would abort (a lesson from omawsl).
- On a fresh Mac `/usr/bin/git` is a stub that opens Apple's install dialog. `boot.sh` must not call `git` before the Command Line Tools exist.
- Homebrew's installer, run with `NONINTERACTIVE=1`, never prompts for sudo: it runs `sudo -n` and skips the Command Line Tools install or aborts if sudo isn't already active. So omamac activates sudo first and keeps it alive.
- Homebrew lives at `/opt/homebrew` (enforced by the preflight check), so omamac may use absolute paths `/opt/homebrew/bin/brew` and `/opt/homebrew/bin/bash`.
- Everything after `boot.sh` requires bash 5.
- macOS limits a host to two running macOS VMs; `test/vm.sh` runs one.
- Tart's licence is free for personal workstation use, which covers Tuna's Mac.

## Approaches

| Approach | Trade-off | Verdict |
| --- | --- | --- |
| **Plain bash: a bash 3.2 `boot.sh` that restarts under Homebrew bash 5; bats; Tart VMs over SSH + `expect`** | Least machinery; the same model omawsl proved; real password prompt in tests | **Chosen** |
| A setup framework (nix-darwin, Ansible, chezmoi) | A second record of what's installed beside Homebrew and a tool the user must learn; breaks "Homebrew is the only record" and "simplicity first" | Dropped |
| One bash 3.2 script for everything | Every later phase stuck on 2007-era bash | Dropped (vision settled the restart) |
| GitHub macOS runners, Anka or UTM for installs | Runners come with Homebrew, so not a fresh Mac; Anka is paid; UTM has no clean headless loop | Dropped (vision settled Tart) |
| `tart exec` instead of SSH + `expect` | Skips the real password prompt a user sees | Dropped |

Tuna handed the how to Claude once the vision was agreed; this design is Claude's call throughout, within what `vision.md` settles.

## Design

### Repo layout

```
boot.sh                    the one-liner's target (bash 3.2)
install.sh                 everything after the restart (bash 5)
bin/omamac                 the command
lib/ui.sh                  gum-drawn output: step, ok, fail, info, summary
lib/lines.sh               the guarded-line helper
lib/doctor.sh              doctor's checks
test/*.bats                the bats suite
test/helpers/              stubs and a sandbox-HOME helper
test/fixtures/bare.env     Phase 1's only fixture: no choices
test/image.sh              builds the clean Tart image      (gate file)
test/vm.sh                 the VM test loop                  (gate file)
test/vm.exp                runs one command in a VM over SSH, typing its password (gate file)
test/fingerprint.sh        runs in the VM: prints what a second run must not change (gate file)
.github/workflows/bats.yml bats + shellcheck                 (gate file)
.github/rulesets/main.json the merge rule                    (gate file)
README.md
CONTRIBUTING.md
LICENSE                    MIT, copyright Tuna Cinsoy
.gitignore                 test/logs/
```

The checkout's files are committed with their executable bit (`bin/omamac`, `test/*.sh`). `boot.sh` still runs `install.sh` with an explicit interpreter, so a lost bit can't break the run.

### `boot.sh` (bash 3.2)

In order. Each step that fails prints one plain-text message (gum isn't there yet) saying what's wrong and what to do, and exits 1. Nothing is changed before step 4.

1. **Banner.** A few plain lines: what omamac is about to do (install Homebrew and a few tools, then the omamac command), that it asks for the password once, and "Press Ctrl-C to stop."
2. **Preflight checks.**
   - Not running as root.
   - Apple Silicon: `sysctl -in hw.optional.arm64` is `1`, and not translated (`sysctl -in sysctl.proc_translated` isn't `1`). A Terminal running under Rosetta gets its own message.
   - macOS 27 or later: major version of `sw_vers -productVersion` ≥ 27.
   - The user is in the `admin` group (`id -Gn`).
   - No Homebrew in `/usr/local` (`/usr/local/bin/brew` exists → stop and point to Homebrew's migration instructions: https://docs.brew.sh/Installation).
   - The login shell is zsh (`dscl . -read "/Users/$USER" UserShell`). omamac sets up zsh, so on another shell the run would succeed but `omamac` wouldn't be found in a new window. Stop and show `chsh -s /bin/zsh`. *(Claude's call, from the builder check.)*
   - A terminal is attached: `/dev/tty` is readable. Otherwise stop: "omamac needs a terminal to ask for your password."
3. **Password.** `sudo -v` (sudo reads the password from the terminal itself, never from the pipe). Then a background loop refreshes it with `sudo -n true` every 60 seconds and exits as soon as the omamac process is gone (`kill -0 $$`). Because `boot.sh` later `exec`s into `install.sh`, `$$` stays the same process for the whole run; a comment says so. The password is never stored or logged.
4. **Homebrew.** If `/opt/homebrew/bin/brew` is missing, run the official installer from `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` with `NONINTERACTIVE=1`. It brings the Command Line Tools and git. Its output goes to the run's log (below); the screen shows one line: "Installing Homebrew and Apple's Command Line Tools (this can take 10 minutes)…". On failure, print the last 20 log lines and the log's path. Then `eval "$(/opt/homebrew/bin/brew shellenv)"` for the rest of the run, and check that `git --version` works; if not, stop with "Apple's Command Line Tools didn't install."
5. **bash and gum.** For each of `bash` and `gum`: if `brew list --formula <name>` fails, `brew install <name>`. Same logging.
6. **Checkout.** `OMAMAC_REF` defaults to `main`; `OMAMAC_HOME` is `~/.local/share/omamac`.
   - Missing: `git clone --branch "$OMAMAC_REF" https://github.com/tunacinsoy/omamac "$OMAMAC_HOME"`.
   - Present and a git checkout of that URL: `git fetch origin "$OMAMAC_REF"`, `git switch "$OMAMAC_REF"` (creates the tracking branch when needed), `git merge --ff-only "origin/$OMAMAC_REF"`.
   - Present but not a git checkout, or `origin` is another URL: stop, change nothing, and say what's there.
   - Before cloning or fetching, `git ls-remote --exit-code --heads <url> refs/heads/<ref>` checks that the branch exists. The full name matters: a bare `nope` would also match `x/nope`. No such branch: stop with "'<ref>' isn't on GitHub. The checkout wasn't changed."
   - `GIT_TERMINAL_PROMPT=0` for the whole run, so a renamed or private repo fails instead of asking for a username.
   - Network failures: stop with omawsl's style of help (no internet, network blocking github.com, GitHub status page). A failed switch or fast-forward stops with "local changes or a diverged history?" and the log tail.
7. **Restart.** `exec /opt/homebrew/bin/bash "$OMAMAC_HOME/install.sh"`.

**The log.** Every run writes `~/.local/state/omamac/logs/<UTC timestamp>.log` (mkdir -p first, after step 2). Only the newest 10 logs are kept. `boot.sh` starts the log; `install.sh` appends to the same file, whose path it gets in `OMAMAC_LOG`.

**Test seams.** Every absolute path and URL `boot.sh` checks or fetches (`/opt/homebrew`, `/usr/local/bin/brew`, `/dev/tty`, the Homebrew installer URL, the repo URL) can be overridden by an undocumented `OMAMAC_TEST_*` variable, so bats can run it under `/bin/bash` with stubs and a sandbox `HOME`. They are not in the README.

### `install.sh` (bash 5)

`set -Eeuo pipefail`, sources `lib/*.sh`, and stops at once if `BASH_VERSINFO[0]` < 5. An `ERR` trap prints, with gum: which step failed and "Fix the problem and run the one-liner again; it picks up where it stopped."

Steps, each a `ui` step line with a ✓ when done:

1. **omamac's zsh file.** Write `~/.config/omamac/zshrc` with exactly:
   ```zsh
   # Generated by omamac. Changes here are overwritten; put your own in ~/.zshrc.
   [[ ":$PATH:" == *":$HOME/.local/share/omamac/bin:"* ]] || export PATH="$HOME/.local/share/omamac/bin:$PATH"
   ```
   Written to a temp file and moved into place only if the content differs, so a second run doesn't touch it.
2. **Homebrew on the PATH.** In `~/.zprofile`, if no line contains `brew shellenv`, append
   `eval "$(/opt/homebrew/bin/brew shellenv)" # added by omamac`.
3. **omamac's include.** In `~/.zshrc`, if the exact line isn't there, append at the end
   `[[ -r ~/.config/omamac/zshrc ]] && source ~/.config/omamac/zshrc # added by omamac`.
4. **Summary.** A short gum-styled block: what's installed (Homebrew, bash, gum, omamac), where the log is, and "Open a new terminal window, then run `omamac`."

**`lib/lines.sh`, the guarded-line helper** used by steps 2 and 3: `lines_add <file> <line> [<present-if-pattern>]`.
- Creates the parent folder and the file if missing (the file then holds only the line).
- Does nothing if the line (or the pattern) is already there.
- Otherwise appends, first adding a newline if the file doesn't end with one. Nothing else in the file changes.
- Follows a symlinked `~/.zshrc` (dotfile managers) and writes to its target, never replacing the link.
- The trailing `# added by omamac` lets a later uninstall find exactly its own line.

### `bin/omamac`

Shebang `#!/opt/homebrew/bin/bash`, `set -Eeuo pipefail`, finds its checkout from its own path, sources `lib/`.

| Call | Does | Exit |
| --- | --- | --- |
| `omamac`, `omamac help`, `-h`, `--help` | Short usage: the five subcommands, one line each | 0 |
| `omamac doctor` | The checks below | 0, or 1 if any ✗ |
| `omamac install` / `update` / `theme` / `uninstall` | "`omamac <cmd>` isn't available yet." | 1 |
| anything else | "Unknown command" and the usage, on stderr | 2 |

### `omamac doctor` (Phase 1 checks)

One line per check, ✓ / ✗ / ℹ. A ✗ says what it found, why it matters, and the one fix. Read-only.

| Check | ✗ when | Fix shown |
| --- | --- | --- |
| Homebrew | `/opt/homebrew/bin/brew` missing, or `/usr/local/bin/brew` present | Run the one-liner / Homebrew's migration link |
| bash 5 | `/opt/homebrew/bin/bash` missing or older than 5 | `brew install bash` |
| gum | `gum` not in `brew list --formula` | `brew install gum` |
| Checkout | `~/.local/share/omamac` not a git checkout of omamac's URL | Run the one-liner |
| Checkout is clean | `git status --porcelain` not empty: local edits would block `omamac update` | `git -C ~/.local/share/omamac status` to see them |
| Homebrew line | no `brew shellenv` line in `~/.zprofile` | Run the one-liner again |
| omamac line | omamac's include missing from `~/.zshrc` | Run the one-liner again |
| omamac's zsh file | `~/.config/omamac/zshrc` missing | Run the one-liner again |

### `lib/ui.sh`

Small wrappers over `gum style` / `gum spin` so every script prints the same way: a step line, ✓, ✗ (to stderr), ℹ, and a summary box. Long commands (`brew install`) run under `gum spin` with output sent to the log. Colours come from gum's defaults until Phase 4 brings themes. gum is called as `/opt/homebrew/bin/gum`, not by name, so doctor works when Homebrew isn't on PATH. If gum isn't there, the same text prints plainly with the same ✓ ✗ ℹ markers, so doctor can still say what's wrong.

### bats suite

- Runs with `bats test/` on the dev Mac and in CI. Every test runs with `HOME` set to a fresh folder under `$BATS_TEST_TMPDIR` and stubs on `PATH` (`sudo`, `brew`, `git`, `curl`, `sw_vers`, `sysctl`, `id`, `gum`), so no test touches the real Mac or the network.
- **`boot.sh`:** runs under `/bin/bash` (3.2) as piped (`cat boot.sh | /bin/bash`). One test per preflight failure (root, Intel, Rosetta, macOS 26, non-admin, `/usr/local` Homebrew, login shell not zsh, no terminal), each asserting the message and that nothing was installed. Fresh path: installer, `brew install bash gum`, clone, exec, in that order. Re-run path: no installer, no `brew install`, fetch + ff-merge. Checkout with a foreign `origin` stops untouched. No `git` call before the installer has run.
- **`install.sh` / `lib/lines.sh`:** a missing file is created with only the line; an existing file gets the line appended, with no other byte changed; a file without a trailing newline; an existing `brew shellenv` line means no second one; a symlinked `~/.zshrc` stays a symlink; running twice leaves every file byte-identical.
- **`omamac`:** usage, exit codes, "not yet" commands; doctor ✓ on a healthy sandbox, and one ✗ per check with its fix.
- **Never-touch list:** after `install.sh` runs in the sandbox, none of the paths on the vision's never-touch list exists or changed.
- **Users never see apt, Windows or WSL:** a test greps `README.md`, `CONTRIBUTING.md`, `boot.sh`, `install.sh`, `bin/` and `lib/` (case-insensitive, whole words) and fails on any hit. Planning docs (`vision.md`, `docs/`) are excluded.

### CI: `.github/workflows/bats.yml`

On every push and pull request, one job named `bats` on `macos-latest`: `brew install bats-core shellcheck`, `shellcheck` every shell file (`boot.sh` with `--shell=bash` and a 3.2 check by the bats tests above), then `bats test/`. The VM scripts are shellchecked but not run in CI. The job's check name is `bats`, which the ruleset requires.

### Gate-file flag

A second step in the `bats` job, on pull requests only: if the PR changes any gate file, it prints a GitHub warning annotation, "This PR changes the merge gate: <files>", which shows on the PR's checks so Tuna sees it before merging. It warns; it doesn't fail, because gate PRs are legitimate.

### The clean image: `test/image.sh`

Run on the dev Mac (by Tuna or the agent), rarely (first setup, and when a new macOS ships).

1. `tart clone ghcr.io/cirruslabs/macos-golden-gate-vanilla:latest omamac-clean-new` (macOS 27; the base name is one constant at the top, changed when the next macOS ships), then `tart set omamac-clean-new --disk-size 80`. The base's 50 GB disk is too small once macOS prepares a background OS update (about 9 GB); the guest grows into the bigger disk on its own. `tart set` refuses to shrink a disk, so a bigger base stops the script until the number is raised.
2. Boot it, and through `test/vm.exp` as Cirrus's default user (`admin` / `admin`):
   - `sudo rm /etc/sudoers.d/admin-nopasswd`, so sudo asks for the password like a real Mac;
   - `sudo spctl --global-enable` (Gatekeeper on); if macOS 27 needs a click for it, the script stops and says which.
   - Check: `brew` absent, `sudo -n true` fails, `spctl --status` says enabled, and `df -g /` shows at least 30 GB free (so a base that doesn't grow fails here).
3. Shut it down, delete the old `omamac-clean` if any, rename `omamac-clean-new` to `omamac-clean`, and `tart prune` the download cache. Exactly one clean image stays on disk.

Found when first built (macOS 27.2):
- The base image has no Command Line Tools (`xcode-select -p` fails, no CLT receipt), so `boot.sh`'s `git` stub constraint is real in the VM.
- `sudo spctl --global-enable` works over SSH with no click; `spctl --status` then says `assessments enabled`.
- Clearing the download cache is `tart prune --entries caches --space-budget 0`. After it, refreshing the image downloads the base again (about 35 GB).

### The VM loop: `test/vm.sh <branch> <fixture>`

Runs on the dev Mac. Exits 0 on pass, 1 on fail, and prints only a few progress lines and ✓ or ✗ at the end.

1. **Refuse to start** unless: `tart`, `gh` (logged in) and `expect` exist; `omamac-clean` exists (else "run `test/image.sh` first"); `test/fixtures/<fixture>.env` exists; the working tree is clean; and the local `HEAD` equals `origin/<branch>` as reported by `git ls-remote` (the commit is pushed). That commit's SHA is what gets tested and marked.
2. **Clone and boot:** `tart clone omamac-clean omamac-test-<sha7>-<timestamp>`, `tart run --no-graphics` in the background, `tart ip --wait 120`. A `trap … EXIT` stops and deletes the VM however the script ends.
3. **Fixture:** the VM fetches it by commit SHA from raw.githubusercontent.com into `~/.local/state/omamac/choices.env` (no `scp`, so no second password dance). Nothing reads it in Phase 1; the path is in place for Phase 2.
4. **First run**, driven by `test/vm.exp` over `ssh -t` (host key checks off, because the VM is new every time and only ever reached at its local IP; a comment says so). It logs in with the VM's password and runs, in a login shell:
   `curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/<sha>/boot.sh | OMAMAC_REF=<branch> bash`
   Fetching `boot.sh` by commit SHA avoids raw.githubusercontent.com serving a cached older file. `expect` types the VM's password at the ssh login and at sudo's prompt, and fails on a third password prompt (omamac asks once), a 45-minute timeout or any unexpected prompt. Every other `vm.exp` call allows only the ssh login's prompt.
5. **Checks after the first run:** the run exited 0; the checkout's `HEAD` in the VM is the tested SHA; `zsh -lic 'omamac doctor'` exits 0 (a login + interactive zsh is what a new Terminal window runs, so this proves the PATH wiring too).
6. **Fingerprint, second run, fingerprint.** `test/fingerprint.sh`, fetched by commit SHA and run in the VM, records: `brew list --versions`; `shasum -a 256` of `~/.zprofile`, `~/.zshrc` and every file under `~/.config/omamac/`; the checkout's `HEAD`. Run the one-liner again exactly as in step 4. Record again. The two records must be identical; on a difference the log shows the diff. Logs under `~/.local/state/omamac/logs/` are excluded, since every run adds one. doctor must pass again.
7. **Report:** `gh api -X POST repos/tunacinsoy/omamac/statuses/<sha> -f state=success|failure -f context=vm -f description="<fixture>: <passed|failed at step N>"`. A failure is posted too, so the PR shows it.
8. **Log:** everything above goes to `test/logs/<timestamp>-<branch>-<fixture>.log` on the dev Mac (git-ignored), including the VM's own omamac log copied out before the VM is deleted.

### The merge gate: `.github/rulesets/main.json`

On the default branch: no deletion, no force-push, changes only through pull requests (0 approvals, since Tuna is the only maintainer), and required status checks with the strict "branch must be up to date" policy:
- `bats`, pinned to the GitHub Actions app (`integration_id` 15368), so a hand-posted status doesn't count;
- `vm`, unpinned (it's posted with Tuna's own login).

No bypass actors. Applied once with `gh api -X POST repos/tunacinsoy/omamac/rulesets --input .github/rulesets/main.json`; CONTRIBUTING says how to change it.

**Trust model:** GitHub can't prove a VM ran or that the fixture covers what the PR touched. The gate stops accidental merges (stale commits, unpushed changes, a forgotten VM run), not deliberate fakes.

### Bring-up order

The repo is empty, so the first steps are a one-time bootstrap:
1. Commit `vision.md` alone on `main` and push it; this creates `main` as the default branch.
2. Phase 1 work happens on `phase-1-foundations`, pushed, with a PR into `main`.
3. Once `bats.yml` has run once on the PR (so the check exists), the agent applies the ruleset.
4. The agent installs `tart`, `bats-core` and `shellcheck` on the dev Mac, runs `test/image.sh` once, then `test/vm.sh phase-1-foundations bare`, debugging in VMs as needed. Green `bats` + `vm` = Gate A; Tuna merges.

### Docs

- **README.md:** what omamac is (one paragraph); "Before you begin" (Apple Silicon, macOS 27+, Setup Assistant done, admin account, macOS updated, internet); "Install" (the one-liner; that it asks for the password once; how long it takes); "After install" (open a new terminal window; empty otherwise for now); "Testing a branch" for contributors (the one-liner with the branch in the URL and `OMAMAC_REF=<branch>`); a link to omawsl as the sister project. No apt, Windows or WSL.
- **CONTRIBUTING.md:** the flow (branch → push → PR → `bats` in CI → `test/vm.sh` → merge by Tuna); making and refreshing the clean image; the dev-Mac tools (`brew trust --formula openai/tools/tart openai/tools/softnet`, then `brew install openai/tools/tart bats-core shellcheck`, `gh auth login`; Tart moved from Cirrus Labs to OpenAI, its images still come from ghcr.io/cirruslabs); the gate files: the agent writes and changes them only in a PR about the gate, never to turn a red check green; never posting `vm` by hand; the trust model; "never run omamac on the development Mac".

### Vision updates in this change

- "Testing a branch uses `OMAMAC_REF=<branch>` on the same one-liner" becomes: the one-liner with `<branch>` in the `boot.sh` URL and `OMAMAC_REF=<branch>`; `test/vm.sh` uses the commit SHA in the URL. Reason: `main`'s `boot.sh` can't test a branch that changes `boot.sh`, and the Phase 1 PR has no `main` `boot.sh` at all.
- Logs live in `~/.local/state/omamac/logs/` (newest 10).

## Left to the builder

- Exact wording of messages and the banner, within "fewest plain words".
- How `lib/ui.sh` styles things with gum, as long as it's consistent.
- Internal function names, the stub helper's shape, and the `OMAMAC_TEST_*` variable names.
- The `expect` script's prompt patterns, after looking at real output in a VM.
