# Phase 1: foundations — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The public one-liner takes a fresh macOS 27 Apple Silicon Mac to Homebrew, bash 5, gum, omamac's checkout and a working `omamac doctor`, proven idempotent in a throwaway Tart VM, behind an enforced merge gate.

**Architecture:** `boot.sh` (bash 3.2, arrives through `curl | bash`) checks the Mac, activates sudo, installs Homebrew, bash and gum, clones the checkout and `exec`s `install.sh` under bash 5. `install.sh` and `bin/omamac` share small `lib/` files. bats tests run every script in a sandbox `HOME` with stub commands; `test/vm.sh` proves the real thing in a Tart VM and posts the `vm` status that a GitHub ruleset requires.

**Tech Stack:** bash 3.2 (`boot.sh` only), bash 5 (everything else), gum, bats-core, shellcheck, Tart, expect, `gh`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-16-phase-1-foundations-design.md` (the why: `vision.md`). Read both before any task.

## Global Constraints

- `boot.sh` runs under `/bin/bash` 3.2: no associative arrays, `${v,,}`, `mapfile`, `[[ -v ]]`, `declare -n`. No sourced-vs-executed guard. Prompts read `/dev/tty`. No `git` call before Homebrew's installer has run.
- Everything else starts `#!/opt/homebrew/bin/bash` (scripts users run) or is sourced by such a script, and uses `set -Eeuo pipefail`.
- omamac's paths: checkout `~/.local/share/omamac`, generated files `~/.config/omamac/`, state `~/.local/state/omamac/`, logs `~/.local/state/omamac/logs/<UTC timestamp>.log` (newest 10 kept).
- Repo URL `https://github.com/tunacinsoy/omamac`; default ref `main`; `OMAMAC_REF` overrides it.
- The two user-file lines, exactly:
  - `~/.zprofile`: `eval "$(/opt/homebrew/bin/brew shellenv)" # added by omamac` (skipped if any line contains `brew shellenv`)
  - `~/.zshrc`: `[[ -r ~/.config/omamac/zshrc ]] && source ~/.config/omamac/zshrc # added by omamac`
- Nothing users see (README, CONTRIBUTING, `boot.sh`, `install.sh`, `bin/`, `lib/`) contains the words apt, Windows or WSL.
- Never write to: `~/.ssh/**`, `~/.gitconfig`, `~/.npmrc`, `~/.m2/settings.xml`, `~/.curlrc`, `/etc/hosts`, `/etc/resolver/*`, anything else under `/etc` or `/Library`.
- No test touches the real `HOME`, the network or the real Homebrew. omamac never runs on the development Mac outside a VM.
- Test seams are env vars named `OMAMAC_TEST_*`, undocumented for users.
- Gate files: `.github/rulesets/main.json`, `.github/workflows/bats.yml`, `test/vm.sh`, `test/vm.exp`, `test/fingerprint.sh`, `test/image.sh`.
- Output: fewest plain words; gum-drawn after `boot.sh`; ✓ ✗ ℹ markers.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Review Focus

1. **Interrupted run, then re-run.** Ctrl-C during the clone can leave `~/.local/share/omamac` empty. A re-run must treat an empty folder as missing and clone, not stop with "not a git checkout". Test in Task 7.
2. **Unwritable dotfile.** A root-owned or read-only `~/.zshrc` (left by an old `sudo` install) must stop the run with the file's name and a fix, never a half-written file. Test in Task 2.
3. **Wrong password three times.** `sudo -v` fails: stop with "omamac needs your admin password", nothing installed. Test in Task 7.
4. **No network.** The Homebrew installer download or the clone fails: show omamac's network help, not curl's or git's raw error. Test in Task 7.
5. **`OMAMAC_REF` names a branch that doesn't exist.** Say which ref wasn't found on GitHub, change nothing. Test in Task 7.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `LICENSE`, `.gitignore` | MIT; ignore `test/logs/` | 1 |
| `test/helpers/common.bash` | sandbox `HOME`, stub dir, `stub`, `stub_calls`, `BASH5` | 1 |
| `test/helpers/fake-brew`, `test/helpers/fake-gum` | stand-ins for brew and gum | 1 |
| `test/hygiene.bats` | no apt/Windows/WSL; shell files parse | 1 |
| `.github/workflows/bats.yml` | CI: shellcheck, bats, gate-file flag | 1 |
| `lib/paths.sh` | every path and line constant | 2 |
| `lib/lines.sh` | guarded-line helper | 2 |
| `lib/ui.sh` | gum output wrappers and `ui_run` | 3 |
| `bin/omamac` | command dispatch | 3 |
| `lib/doctor.sh` | doctor checks | 4 |
| `install.sh` | bash 5 install steps | 5 |
| `boot.sh` | preflight (Task 6), install path (Task 7) | 6, 7 |
| `README.md` | user docs | 7 |
| `test/vm.exp` | one SSH command in a VM, password typed | 8 |
| `test/image.sh` | the clean image | 8 |
| `test/fingerprint.sh`, `test/vm.sh`, `test/fixtures/bare.env` | the VM loop | 9 |
| `.github/rulesets/main.json`, `CONTRIBUTING.md` | the gate and its docs | 10 |

---

### Task 0: Bring-up

**Files:** none new (commits `vision.md`, the spec and this plan).

- [ ] **Step 1: Install dev tools on the development Mac**

Run: `brew install bash bats-core shellcheck`
Expected: `/opt/homebrew/bin/bash --version` prints 5.x; `bats --version` and `shellcheck --version` work. (These are dev tools; omamac itself is not run.)

- [ ] **Step 2: Create `main` on GitHub with the vision only**

```bash
git add vision.md
git commit -m "docs: add the omamac vision"   # + Co-Authored-By trailer
git push -u origin main
```
Expected: `gh repo view tunacinsoy/omamac --json defaultBranchRef` shows `main`.

- [ ] **Step 3: Branch and commit the spec and plan**

```bash
git switch -c phase-1-foundations
git add docs/
git commit -m "docs: add the Phase 1 design and plan"
```

---

### Task 1: Test harness, CI, licence

**Files:**
- Create: `LICENSE`, `.gitignore`, `test/helpers/common.bash`, `test/helpers/fake-brew`, `test/helpers/fake-gum`, `test/hygiene.bats`, `.github/workflows/bats.yml`

**Interfaces:**
- Produces (in `common.bash`, loaded with `load helpers/common` in each `.bats` file):
  - `setup_sandbox`: sets `HOME=$BATS_TEST_TMPDIR/home` (created), `STUB_DIR=$BATS_TEST_TMPDIR/stubs` prepended to `PATH`, `STUB_LOG=$BATS_TEST_TMPDIR/stub.log`, `OMAMAC_TEST_BREW_PREFIX=$BATS_TEST_TMPDIR/opt/homebrew`, `REPO_ROOT` (the repo checkout), `BASH5` (`/opt/homebrew/bin/bash`, fails the test if missing or < 5). Puts `fake-gum` on `PATH` as `gum`.
  - `stub <name> [<bash body>]`: writes `$STUB_DIR/<name>`, an executable `#!/bin/bash` script that appends `<name> <args>` to `$STUB_LOG` then runs the body (default: `exit 0`).
  - `stub_calls`: prints `$STUB_LOG`.
  - `install_fake_brew`: copies `fake-brew` to `$OMAMAC_TEST_BREW_PREFIX/bin/brew`.
- `fake-brew` behaviour: logs to `$STUB_LOG`; `shellenv` prints `export PATH="<prefix>/bin:$PATH"`; `list --formula <f>` exits 0 iff `<prefix>/Cellar/<f>` exists; `list --versions` prints one `<f> 1.0` line per Cellar entry; `install <f>` creates `<prefix>/Cellar/<f>`, and for `bash` symlinks `<prefix>/bin/bash` → `$BASH5`, for `gum` symlinks `<prefix>/bin/gum` → `fake-gum`.
- `fake-gum` behaviour: `style … <text…>` prints the text args; `spin … -- <cmd…>` runs the command; anything else prints its args.

- [ ] **Step 1: Write `test/hygiene.bats`**

```bash
@test "users never see apt, Windows or WSL" {
  run grep -rniwE 'apt|windows|wsl' "$REPO_ROOT"/{README.md,CONTRIBUTING.md,boot.sh,install.sh,bin,lib} 2>/dev/null
  [ "$status" -eq 1 ]   # grep found nothing
}
@test "boot.sh parses under macOS's bash 3.2" {
  [ ! -e "$REPO_ROOT/boot.sh" ] || /bin/bash -n "$REPO_ROOT/boot.sh"
}
@test "every bash 5 script parses" {
  for f in "$REPO_ROOT"/install.sh "$REPO_ROOT"/bin/omamac "$REPO_ROOT"/lib/*.sh; do
    [ ! -e "$f" ] || "$BASH5" -n "$f"
  done
}
@test "stub records its calls" {
  stub hello 'echo hi'
  run hello there
  [ "$output" = "hi" ]
  grep -qx 'hello there' "$STUB_LOG"
}
```
Missing files are skipped, so later tasks make these bite. `grep` over missing paths exits 2; the first test must treat only "no match" (1) as pass, so create the files list from those that exist.

- [ ] **Step 2: Run, expect failure:** `bats test/` → FAIL (`common.bash` missing).

- [ ] **Step 3: Write the helpers, `LICENSE` (MIT, "Copyright (c) 2026 Tuna Cinsoy"), `.gitignore` (`test/logs/`).**

- [ ] **Step 4: Run:** `bats test/` → all pass.

- [ ] **Step 5: Write `.github/workflows/bats.yml`**

```yaml
name: bats
on: [push, pull_request]
jobs:
  bats:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - run: brew install bash bats-core shellcheck
      - run: git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck
      - run: bats test/
      - name: Flag gate changes
        if: github.event_name == 'pull_request'
        run: |
          gate='^(\.github/rulesets/main\.json|\.github/workflows/bats\.yml|test/(vm\.sh|vm\.exp|fingerprint\.sh|image\.sh))$'
          files=$(git diff --name-only "origin/${{ github.base_ref }}...HEAD" | grep -E "$gate" | paste -sd ' ' - || true)
          [ -z "$files" ] || echo "::warning::This PR changes the merge gate: $files"
```
The job id `bats` is the required check's name. Shellcheck runs locally too: `git ls-files … | xargs shellcheck` → no output.

- [ ] **Step 6: Commit:** `git add -A && git commit -m "test: add the bats harness, CI and licence"`

---

### Task 2: Paths and the guarded-line helper

**Files:**
- Create: `lib/paths.sh`, `lib/lines.sh`, `test/lines.bats`

**Interfaces:**
- Produces in `lib/paths.sh` (plain variables, read at source time from `HOME`):
  `OMAMAC_REPO_URL=https://github.com/tunacinsoy/omamac`, `OMAMAC_BREW_PREFIX=${OMAMAC_TEST_BREW_PREFIX:-/opt/homebrew}`, `OMAMAC_USR_LOCAL_BREW=${OMAMAC_TEST_USR_LOCAL_BREW:-/usr/local/bin/brew}`, `OMAMAC_HOME=$HOME/.local/share/omamac`, `OMAMAC_CONFIG_DIR=$HOME/.config/omamac`, `OMAMAC_STATE_DIR=$HOME/.local/state/omamac`, `OMAMAC_ZSH_FILE=$OMAMAC_CONFIG_DIR/zshrc`, `OMAMAC_ZPROFILE_LINE`, `OMAMAC_ZSHRC_LINE` (exact strings from Global Constraints).
- Produces in `lib/lines.sh`:
  - `lines_add <file> <line> [<present_pattern>]` → 0 when the line is there afterwards; non-zero with `omamac can't write <file>: <reason>. Fix: <cmd>` on stderr when the file or its folder isn't writable (the file is not touched). `<present_pattern>` is a fixed string; if any line contains it, nothing is added.
  - `lines_has <file> <fixed_string>` → 0 if any line contains it, 1 otherwise (also 1 if the file is missing).

- [ ] **Step 1: Write `test/lines.bats`**

Tests (each in a sandbox):
- `creates a missing file holding only the line` — `lines_add "$HOME/.zshrc" "L"` → file content is exactly `L\n`; parent folders created for `~/.config/x/y`.
- `appends to an existing file and changes nothing else` — file `a\nb\n`, add `L` → exactly `a\nb\nL\n`.
- `adds a newline first when the file lacks one` — file `a` (no newline) → `a\nL\n`.
- `second call changes nothing` — add twice → content and `shasum` identical.
- `a present pattern skips the add` — file has `eval "$(brew shellenv)"`; `lines_add f "$OMAMAC_ZPROFILE_LINE" "brew shellenv"` → file unchanged.
- `follows a symlinked file` — `~/.zshrc` → `~/dotfiles/zshrc`; after add, `~/.zshrc` is still a symlink and the target holds the line.
- `unwritable file stops with its name` (Review Focus 2) — `chmod 444 ~/.zshrc`; `run lines_add …` → status ≠ 0, output contains `.zshrc` and `Fix:`, content unchanged.
- `lines_has finds and misses` — 0 on a match, 1 on no match, 1 on a missing file.

- [ ] **Step 2: Run:** `bats test/lines.bats` → FAIL (lib missing).
- [ ] **Step 3: Implement `lib/paths.sh` and `lib/lines.sh`.** Use `grep -qF --`; resolve symlinks by writing through the link with `>>` (appending through a symlink keeps it); check `-w` on the file (or its folder when missing) before writing.
- [ ] **Step 4: Run:** `bats test/` → all pass; shellcheck clean.
- [ ] **Step 5: Commit:** `feat: add omamac's paths and the guarded-line helper`

---

### Task 3: Output helpers and the `omamac` command

**Files:**
- Create: `lib/ui.sh`, `bin/omamac` (mode 755), `test/omamac.bats`

**Interfaces:**
- Produces in `lib/ui.sh`: `ui_step <text>` (a step heading), `ui_ok <text>` (`✓ text`), `ui_fail <text>` (`✗ text` to stderr), `ui_info <text>` (`ℹ text`), `ui_box <line>…` (a bordered summary), `ui_run <title> <cmd…>` (runs cmd under `gum spin --title <title>`, stdout+stderr appended to `$OMAMAC_LOG`; on failure prints the last 20 log lines and `Log: $OMAMAC_LOG` via `ui_fail`, returns the command's status). `OMAMAC_LOG` defaults to `/dev/null` when unset.
- Produces `bin/omamac`: resolves its checkout (`$(cd "$(dirname "$0")/.." && pwd -P)`), sources `lib/paths.sh`, `lib/lines.sh` and `lib/ui.sh` (Task 4 adds `lib/doctor.sh`), defines `omamac_main "$@"`.

- [ ] **Step 1: Write `test/omamac.bats`** (run as `"$BASH5" "$REPO_ROOT/bin/omamac" …`)
- `no args prints usage` → status 0, output contains `install`, `update`, `theme`, `doctor`, `uninstall`.
- `help, -h and --help print the same usage` → status 0, same output as no args.
- `commands not built yet say so` — for each of install update theme uninstall: status 1, output `omamac <cmd> isn't available yet.`
- `unknown command` → status 2, output contains `Unknown command: frob` and the usage.
- `ui_run logs output and returns the status` — source `lib/ui.sh`, `OMAMAC_LOG=$BATS_TEST_TMPDIR/l`; `ui_run t bash -c 'echo out; exit 3'` → status 3, log contains `out`, output contains `Log:`.

- [ ] **Step 2: Run:** FAIL. **Step 3: Implement.** Usage text, exactly:
```
Usage: omamac <command>

  install     Add tools and apps
  update      Update omamac and what it installed
  theme       Switch the theme everywhere
  doctor      Check that everything is healthy
  uninstall   Remove one thing omamac installed
```
- [ ] **Step 4: Run:** `bats test/` → pass. **Step 5: Commit:** `feat: add the omamac command and output helpers`

---

### Task 4: `omamac doctor`

**Files:**
- Create: `lib/doctor.sh`, `test/doctor.bats`
- Modify: `bin/omamac` (source `lib/doctor.sh`; `doctor)` calls `doctor_run`)

**Interfaces:**
- Consumes: `lib/paths.sh` variables, `lines_has`, `ui_ok`/`ui_fail`/`ui_info`.
- Produces: `doctor_run` → prints one line per check in the spec's table order, returns 0 if no ✗, else 1. `doctor_report <ok|fail|info> <what> [<why>] [<fix>]` prints `✓ what`, or `✗ what — why. Fix: fix`, or `ℹ what — why`.
- Test helper (in `doctor.bats`): `healthy_mac` builds a sandbox where every check passes: fake brew installed with Cellar `bash` and `gum`, `<prefix>/bin/bash` → `$BASH5`, a real git clone at `~/.local/share/omamac` whose `origin` is `$OMAMAC_REPO_URL` (`git init` + `git remote add origin`), both lines present, `~/.config/omamac/zshrc` present.

- [ ] **Step 1: Write `test/doctor.bats`**
- `healthy Mac: every check passes` → status 0, 8 lines starting `✓`.
- One test per check, each breaking one thing in `healthy_mac` and asserting status 1, the `✗` line, and its fix text from the spec's table:
  no `<prefix>/bin/brew`; `/usr/local/bin/brew` present (`OMAMAC_TEST_USR_LOCAL_BREW` pointing at a file that exists) → fix names `https://docs.brew.sh/Installation`; `<prefix>/bin/bash` → `/bin/bash` (3.2) → `brew install bash`; no Cellar `gum` → `brew install gum`; checkout folder missing; `origin` another URL; a stray file in the checkout → fix `git -C ~/.local/share/omamac status`; zprofile line removed; zshrc line removed; zsh file removed → `Run the one-liner again`.
- `doctor is read-only` — `shasum` of every file under `$HOME` before and after a failing run are equal.
- [ ] **Step 2: Run:** FAIL. **Step 3: Implement.** Bash version check: `"$OMAMAC_BREW_PREFIX/bin/bash" -c 'echo ${BASH_VERSINFO[0]}'` ≥ 5.
- [ ] **Step 4: Run:** pass. **Step 5: Commit:** `feat: add omamac doctor`

---

### Task 5: `install.sh`

**Files:**
- Create: `install.sh`, `test/install.bats`

**Interfaces:**
- Consumes: `lib/paths.sh`, `lines_add`, `ui_*`. Reads `OMAMAC_LOG` (exported by `boot.sh`).
- Produces: `install_main` (called at the bottom of the file) running, in order, `install_zsh_file`, `install_lines`, `install_summary`. An `ERR` trap prints via `ui_fail`: `omamac stopped while <step>. Log: $OMAMAC_LOG` and `Fix the problem and run the one-liner again; it picks up where it stopped.`, then exits 1. The current step's name is kept in `OMAMAC_STEP`.

- [ ] **Step 1: Write `test/install.bats`** (run as `"$BASH5" "$REPO_ROOT/install.sh"` in a sandbox with fake brew/gum)
- `stops under bash 3.2` — `/bin/bash install.sh` → status 1, output contains `needs bash 5`.
- `fresh Mac: writes the zsh file and both lines` — `~/.config/omamac/zshrc` equals the spec's two lines exactly; `~/.zprofile` is exactly `$OMAMAC_ZPROFILE_LINE\n`; `~/.zshrc` exactly `$OMAMAC_ZSHRC_LINE\n`.
- `used Mac: appends and keeps the user's lines` — pre-existing `~/.zshrc` `alias x=y\n` → `alias x=y\n$OMAMAC_ZSHRC_LINE\n`.
- `an existing brew shellenv line is respected` — `~/.zprofile` with `eval "$(/opt/homebrew/bin/brew shellenv)"` → unchanged.
- `second run changes nothing` — run twice; `shasum` of every file under `$HOME` (excluding `~/.local/state/omamac/logs`) identical, including the zsh file's mtime (written only when content differs: compare `stat -f %m`).
- `the zsh file puts omamac on the PATH once` — `zsh -c "source $HOME/.config/omamac/zshrc; source $HOME/.config/omamac/zshrc; echo \$PATH"` contains `.local/share/omamac/bin` exactly once.
- `never-touch list stays untouched` — after a run, none of `~/.ssh`, `~/.gitconfig`, `~/.npmrc`, `~/.m2/settings.xml`, `~/.curlrc` exists in the sandbox; and `grep -rnE '/etc/|/Library/' install.sh lib/` finds nothing but comments.
- `a failing step names itself and the log` (Review Focus 2 end-to-end) — `chmod 444 ~/.zshrc` → status 1, output contains `.zshrc`, `Log:` and `run the one-liner again`.
- `summary tells the user what to do next` — output contains `Open a new terminal window, then run omamac`.
- [ ] **Step 2: Run:** FAIL. **Step 3: Implement.** Zsh file content is the spec's two lines verbatim; write to `mktemp` in the same folder, `cmp -s` against the current file, `mv` only if different.
- [ ] **Step 4: Run:** pass. **Step 5: Commit:** `feat: add install.sh`

---

### Task 6: `boot.sh` preflight

**Files:**
- Create: `boot.sh`, `test/boot_preflight.bats`

**Interfaces:**
- `boot.sh` is self-contained (it can't source `lib/`; it arrives alone through the pipe). It defines its own copies of the constants it needs, with the same seams: `OMAMAC_TEST_BREW_PREFIX`, `OMAMAC_TEST_USR_LOCAL_BREW`, `OMAMAC_TEST_TTY` (default `/dev/tty`), `OMAMAC_TEST_BREW_INSTALLER_URL` (default `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`), `OMAMAC_TEST_REPO_URL` (default `https://github.com/tunacinsoy/omamac`).
- Produces: `boot_banner`, `boot_preflight` (each failed check: `boot_die <message>` prints `omamac: <message>` to stderr, exits 1), `boot_main` (Task 6: banner + preflight only; Task 7 adds the rest). Last line of the file: `boot_main`.
- Commands it reads facts from (all stubbed in tests): `id -u`, `id -Gn`, `sysctl -in hw.optional.arm64`, `sysctl -in sysctl.proc_translated`, `sw_vers -productVersion`, `dscl . -read "/Users/$USER" UserShell`.

- [ ] **Step 1: Write `test/boot_preflight.bats`** (always run as `cat "$REPO_ROOT/boot.sh" | /bin/bash`, with stubs for a healthy Mac set in `setup`: uid 501, groups `staff admin`, arm64 1, translated 0, macOS `27.1`, shell `UserShell: /bin/zsh`, `OMAMAC_TEST_TTY` → a readable file, `/usr/local` brew path → nonexistent)
- `a healthy Mac passes preflight` — status 0 under the Task 6 `boot_main` (Task 7 changes this test to stop at sudo).
- One test per failure, each asserting status 1, its message, and that `stub_calls` contains no `sudo`, `curl`, `brew` or `git`:
  - root (`id -u` → 0) → `Run this as your normal user, not as root.`
  - Intel (arm64 → 0) → `omamac needs a Mac with Apple Silicon.`
  - Rosetta (translated → 1) → `Terminal is running under Rosetta.`
  - macOS 26.4 → `omamac needs macOS 27 or later. This Mac has 26.4.`
  - not admin (groups `staff`) → `omamac needs an administrator account.`
  - `/usr/local` Homebrew present → contains `https://docs.brew.sh/Installation`
  - login shell `/bin/bash` → contains `chsh -s /bin/zsh`
  - no terminal (`OMAMAC_TEST_TTY` → nonexistent) → `omamac needs a terminal to ask for your password.`
- `banner says what will happen and how to stop` — output contains `Ctrl-C`.
- [ ] **Step 2: Run:** FAIL. **Step 3: Implement** (bash 3.2 only; `set -euo pipefail`). macOS major: `${version%%.*}`.
- [ ] **Step 4: Run:** `bats test/` → pass (hygiene's 3.2 parse test now bites). **Step 5: Commit:** `feat: add boot.sh preflight checks`

---

### Task 7: `boot.sh` install path and README

**Files:**
- Modify: `boot.sh`
- Create: `test/boot_install.bats`, `README.md`
- Modify: `test/boot_preflight.bats` (healthy-Mac test now asserts preflight passed and `sudo -v` was called)

**Interfaces:**
- Consumes: `install.sh` at `$OMAMAC_HOME/install.sh` (exec'd as `"$prefix/bin/bash" "$OMAMAC_HOME/install.sh"`), `OMAMAC_LOG` exported to it.
- Produces in `boot.sh`: `boot_log_start` (creates `~/.local/state/omamac/logs/<UTC %Y%m%dT%H%M%SZ>.log`, deletes all but the newest 10, exports `OMAMAC_LOG`), `boot_sudo`, `boot_homebrew`, `boot_formulas`, `boot_checkout`, `boot_network_help`. `boot_main` order: banner → preflight → log → sudo → Homebrew → formulas → checkout → `exec`.
- Test fixture: `setup` creates a bare repo `$BATS_TEST_TMPDIR/remote.git` with branches `main` and `feature`, each holding an `install.sh` that writes `ran-<branch>` to `$BATS_TEST_TMPDIR/ran`; `OMAMAC_TEST_REPO_URL` points at it. `curl` stub prints a script that installs fake brew at `$OMAMAC_TEST_BREW_PREFIX`; `sudo` stub exits 0.

- [ ] **Step 1: Write `test/boot_install.bats`**
- `fresh Mac: everything in order` — `stub_calls` shows, in order: `sudo -v`, `curl … <installer url>`, `brew install bash`, `brew install gum`, then the clone; `$BATS_TEST_TMPDIR/ran` holds `ran-main`; `$HOME/.local/state/omamac/logs/` has one log; status 0.
- `no git before Homebrew` — a `git` stub on PATH that fails if `<prefix>/bin/brew` doesn't exist yet; run passes.
- `re-run: no installer, no installs, fast-forward` — run twice; second run's calls contain no `curl` and no `brew install`; a new commit on remote `main` between runs is present in the checkout after run 2.
- `OMAMAC_REF picks the branch` — `OMAMAC_REF=feature` → `ran-feature`.
- `unknown ref stops untouched` (Review Focus 5) — `OMAMAC_REF=nope` → status 1, output contains `nope` and `isn't on GitHub`, no checkout folder.
- `empty checkout folder is treated as missing` (Review Focus 1) — `mkdir -p ~/.local/share/omamac` → clones, status 0.
- `foreign checkout stops untouched` — folder with a git repo whose `origin` is another URL → status 1, message names the folder; folder unchanged. Same for a non-empty non-git folder.
- `wrong password stops before anything` (Review Focus 3) — `sudo` stub: `-v` exits 1 → status 1, `omamac needs your admin password`, no `curl` call.
- `no network: omamac's help, not curl's` (Review Focus 4) — `curl` stub exits 6 → status 1, output contains `couldn't reach` and `githubstatus.com`.
- `Command Line Tools missing after Homebrew stops` — fake installer that doesn't make `git` work (`git` stub `--version` exits 1) → `Apple's Command Line Tools didn't install.`
- `keeps only the newest 10 logs` — 12 old logs present → 10 left after a run, the oldest gone.
- `sudo keep-alive ends with the run` — after `boot.sh` exits, no process whose command line contains `sudo -n true` and the run's PID remains (`pgrep -f`).
- [ ] **Step 2: Run:** FAIL. **Step 3: Implement.** Installer: `NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$url")"` with output to the log; the screen shows `Installing Homebrew and Apple's Command Line Tools (this can take 10 minutes)…`. Ref check before cloning: `git ls-remote --exit-code --heads "$repo" "$ref"` (after Homebrew, so git exists). Keep-alive loop body: `while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done &` with a comment that `exec` keeps `$$`.
- [ ] **Step 4: Run:** `bats test/` → pass; shellcheck clean.
- [ ] **Step 5: Write `README.md`** per the spec's Docs section. The one-liner, exactly:
```
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/main/boot.sh | bash
```
"Testing a branch": `curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/<branch>/boot.sh | OMAMAC_REF=<branch> bash`. Link omawsl: `https://github.com/tunacinsoy/omawsl`. Then update `vision.md`'s settled decision "Testing a branch uses `OMAMAC_REF=<branch>` on the same one-liner" to the README form, and add "Logs live in `~/.local/state/omamac/logs/` (newest 10)" under Settled decisions.
- [ ] **Step 6: Run:** `bats test/hygiene.bats` → pass. **Step 7: Commit:** `feat: add boot.sh's install path and the README`
- [ ] **Step 8: Push** `git push -u origin phase-1-foundations`, open the PR (`gh pr create --base main`, title `Phase 1: foundations`, body: what it adds, Gate A pending). Expected: the `bats` check runs and passes.

---

### Task 8: SSH helper and the clean image

**Files:**
- Create: `test/vm.exp` (755), `test/image.sh` (755)

**Interfaces:**
- Produces `test/vm.exp <ip> <command>`: `ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@<ip> <command>`; on every `[Pp]assword:` prompt sends `$OMAMAC_VM_PASSWORD` (default `admin`, the Cirrus image's public default, not a secret); on any `(y/n)` or `[y/N]` prompt fails with `unexpected prompt`; overall timeout `$OMAMAC_VM_TIMEOUT` (default 2700 s); exits with the remote command's exit status.
- Produces `test/image.sh` (no args): base `ghcr.io/cirruslabs/macos-golden-gate-vanilla:latest` (one constant at the top), builds `omamac-clean` per the spec's three steps.

- [ ] **Step 1: Install Tart:** `brew install cirruslabs/cli/tart`. Expected: `tart --version`.
- [ ] **Step 2: Write both files.** shellcheck `image.sh`.
- [ ] **Step 3: Run:** `test/image.sh` (the base download is large; run in the background and wait). Expected last line `✓ omamac-clean is ready`; `tart list` shows `omamac-clean` and no `omamac-clean-new`.
- [ ] **Step 4: Verify the image behaves like a fresh Mac:** clone it, boot, and through `vm.exp` check `command -v brew` fails, `sudo -k; sudo -n true` fails, `spctl --status` prints `assessments enabled`; delete the clone. Record anything surprising (e.g. Command Line Tools present in the base image) in the spec.
- [ ] **Step 5: Commit and push:** `test: add the clean-image builder and the VM SSH helper`

---

### Task 9: The VM loop

**Files:**
- Create: `test/fingerprint.sh` (755), `test/fixtures/bare.env`, `test/vm.sh` (755)

**Interfaces:**
- Consumes: `test/vm.exp`, image `omamac-clean`.
- Produces `test/fingerprint.sh` (runs inside the VM, under `/bin/bash`): prints, sorted, `brew list --versions`; `shasum -a 256` of `~/.zprofile`, `~/.zshrc` and every file under `~/.config/omamac/`; `git -C ~/.local/share/omamac rev-parse HEAD`.
- Produces `test/vm.sh <branch> <fixture>` per the spec's 8 steps. Status description: `<fixture>: passed` or `<fixture>: failed at <step name>`.
- `bare.env`: one comment line, `# Phase 1: no choices.`

- [ ] **Step 1: Write the three files.** All VM commands run through `test/vm.exp "$ip" "<cmd>"`. Raw URLs use the SHA: `https://raw.githubusercontent.com/tunacinsoy/omamac/$sha/…`. Fingerprints are saved to the dev Mac's log folder and compared with `diff`.
- [ ] **Step 2: Refusal checks run locally:** with uncommitted changes → refuses, names them; with an unpushed commit → refuses with `push first`; unknown fixture → refuses. No VM is created (`tart list` unchanged).
- [ ] **Step 3: Commit and push**, then **run** `test/vm.sh phase-1-foundations bare`. Debug in VMs until it ends `✓`. Each fix is its own commit, pushed, and the run repeated on the new head. Expected: `gh api repos/tunacinsoy/omamac/commits/<sha>/statuses` shows `vm` `success`; `tart list` has no `omamac-test-*`; a log in `test/logs/`.
- [ ] **Step 4: Prove the check bites:** on a throwaway local commit that appends `echo changed >> ~/.zshrc` to `install.sh`'s summary, push to a scratch branch `vm-selftest`, run `test/vm.sh vm-selftest bare` → ends `✗` with the fingerprint diff naming `~/.zshrc`; delete the scratch branch locally and on GitHub.

---

### Task 10: The merge gate

**Files:**
- Create: `.github/rulesets/main.json`, `CONTRIBUTING.md`

**Interfaces:**
- Consumes: the `bats` job from Task 1, the `vm` status from Task 9.

- [ ] **Step 1: Write `.github/rulesets/main.json`**
```json
{
  "name": "main: bats and a fresh-VM run",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false, "require_last_push_approval": false,
        "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "bats", "integration_id": 15368 },
          { "context": "vm" } ] } }
  ]
}
```
- [ ] **Step 2: Write `CONTRIBUTING.md`** per the spec's Docs section, including the gate-file rule exactly as in `vision.md` and the apply command.
- [ ] **Step 3: Run:** `bats test/` → pass. Commit `docs: add the merge gate and CONTRIBUTING`, push.
- [ ] **Step 4: Apply the ruleset:** `gh api -X POST repos/tunacinsoy/omamac/rulesets --input .github/rulesets/main.json`. Expected: `gh api repos/tunacinsoy/omamac/rulesets` lists it with `enforcement: active`.
- [ ] **Step 5: Prove the gate bites:** `gh pr view --json mergeStateStatus` on the PR shows `BLOCKED` (the new head has no `vm` yet).
- [ ] **Step 6: Gate A:** `test/vm.sh phase-1-foundations bare` on the final head → `✓`; `bats` green. `gh pr view --json mergeStateStatus` → `CLEAN`. Comment on the PR with the run's summary (fixture, duration, the two fingerprints matched). Tuna merges.

---

## Self-review notes

- Spec coverage: boot steps 1–7 (Tasks 6–7), log (7), seams (6), install steps (5), lines helper (2), omamac table (3), doctor table (4), ui (3), bats sections (1–7), CI + gate flag (1), image (8), VM loop 1–8 (9), ruleset (10), bring-up (0, 7, 10), docs (7, 10), vision updates (7), licence (1).
- Doctor's offer-to-fix is deferred to Phase 2 by the spec; no task.
