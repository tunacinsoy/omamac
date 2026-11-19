# Phase 6b: adopting hand-installed apps — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A chosen catalog app found in Applications but not in Homebrew is offered to Homebrew before the summary, at the first run and in `omamac install`. Yes → `brew install --cask --adopt`, the app left in place. No → the app leaves the picks. Installer-package apps (Zoom, Google Drive) aren't asked; they leave the picks. doctor's ℹ for a hand-installed app (and Ghostty) shows the adopt command.

**Architecture:** One new function in `lib/apps.sh`, `apps_ask_adopt <id>…`, asks and fills `APPS_ADOPT` (this run's yeses); on no, or for an installer-package app, it calls `apps_drop`. `install_questions` calls it for every chosen app; `add_run` calls it right after each app question, while `CHOICES[key]` holds the new picks. `apps_install` adopts a `hand` app that is in `APPS_ADOPT`. doctor appends the command to its ℹ lines.

**Tech Stack:** bash 5, Homebrew casks, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-19-phase-6-apps-and-dock-design.md`: "Constraints" (Adoption facts), "Approaches" (Adopting, App Management for adopting), "Adoption (6b)", "bats" and "Docs". The why: `vision.md`, "Installed by hand, outside Homebrew". Read both before any task. 6a's `lib/apps.sh` is the pattern.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, never source `.bats` files outside bats, and **never run `brew install`, `brew uninstall`, `brew upgrade`, `brew reinstall`, `brew services`, `colima` or `sudo` on this Mac**. Tests use fake-brew and stubs.
- Exact copy:
  - help line: "<Label> is already installed, but not through Homebrew. Homebrew can take it over, so it's updated and managed like your other apps."
  - question: `Let Homebrew take over <Label>?` (`ask_yes`, Enter alone is no).
  - on no: "omamac leaves <Label> as it is and drops it from your picks."
  - installer-package app: "<Label> is already installed, not through Homebrew. Homebrew can only take it over by installing it again, so omamac leaves it."
  - apply: `ui_run "Handing <Label> to Homebrew" brew install --cask --adopt <cask>`, `OMAMAC_STEP="handing <Label> to Homebrew"`.
  - doctor ℹ, non-password app: "installed by hand, so omamac won't update it. To let Homebrew take it over: brew install --cask --adopt <cask>". Ghostty the same with `ghostty`. Password apps and Docker Desktop keep today's line.
- No printed line may contain `Install?`, or match vm.exp's `(Remove|Let Homebrew take over|Also remove) [^?\r\n]*\?` other than the question itself.
- `--adopt` only in `lib/apps.sh` (and doctor's message text); never for a `password=yes` app; never `--force`.
- No App Management check before adopting (spec, Approaches).
- `update.sh` asks nothing: an app still `hand` there gets 6a's hand line.
- Gate files are not changed (PR #17 made the gate changes: vm.exp answers the question, vm.sh runs `before.sh`).
- Run tests as `(trap '' PIPE; bats test/)`, about 4 minutes, in the background or with a long timeout. The `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`, and `zsh -n` on fixture `.sh` files. Fixture scripts match strings with `[[ … ]]`, never `| grep -q`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **"No" then "Install?" no:** nothing is saved, so the next run asks again. Test in Task 1.
2. **The run stops after "Install?" yes but before `apps_install`:** the answers are saved with the app still picked; the next run asks again (still `hand`) and adopts. Test in Task 1.
3. **Adopting fails** (fake-brew fails `--adopt`): the run stops with "omamac stopped while handing VLC to Homebrew." and the app is untouched. Test in Task 1.
4. **`omamac install` with every new pick answered no:** "Nothing picked, so nothing changed." and nothing saved. Test in Task 2.
5. **An app that turns `hand` after the questions** (dragged in mid-run, or in `omamac update`): the hand line, no adopt. Test in Task 1.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/apps.sh` | `APPS_ADOPT`, `apps_ask_adopt`, adopt in `apps_install` | 1 |
| `test/helpers/fake-brew` | `install --cask --adopt`: records the cask, leaves the app as it is; `T_BREW_FAIL_CASK` fails it too | 1 |
| `install.sh` | `install_questions` calls `apps_ask_adopt` | 1 |
| `lib/add.sh` | asks it after each app question | 2 |
| `lib/doctor.sh` | the adopt command in the ℹ lines | 3 |
| `test/fixtures/adopt.*`, `test/hygiene.bats`, `README.md`, `CONTRIBUTING.md` | VM fixture, hygiene, docs | 4 |

### Task 1: Asking and adopting at the first run

**Files:** Modify `lib/apps.sh`, `install.sh`, `test/helpers/fake-brew`. Test: `test/apps.bats`, `test/install.bats`.

**Interfaces:**
- `APPS_ADOPT=()` (global, declared in `lib/apps.sh`).
- `apps_ask_adopt <id>…`: for each id in `core_cask_state` `hand`: password app → the installer-package line, `apps_drop`; else help line, `ask_yes "Let Homebrew take over <Label>?"`, yes → `APPS_ADOPT+=(id)`, no → the no line, `apps_drop`. Other states: nothing. Returns non-zero if Homebrew can't list. Not run in `$(…)` (it asks).
- `install_questions`: after `ask_missing`, before `ask_summary`: `mapfile -t ids < <(apps_chosen)`, then `apps_ask_adopt "${ids[@]}"` when any. `OMAMAC_STEP` stays 'asking the questions'.
- `apps_install`, `hand` branch: in `APPS_ADOPT` → the adopt `ui_run`; else 6a's hand line.

- [ ] **Step 1: Write the failing tests.**
  - `apps.bats`: VLC `hand` → help line, the question, yes → `APPS_ADOPT` is `vlc`, picks unchanged; no → the no line, `apps_media` loses `vlc`, others unchanged; Zoom `hand` → the installer-package line, no question asked (fake-gum records none), `apps_communication` loses `zoom`; Wispr Flow `hand`, no → `wispr_flow=no`; `brew` and `missing` apps → nothing printed, nothing asked; `apps_install` with VLC `hand` in `APPS_ADOPT` → one `brew install --cask --adopt vlc`, the app's marker file unchanged; not in `APPS_ADOPT` → the hand line, no brew call; adopt fails → status non-zero, `OMAMAC_STEP` is "handing VLC to Homebrew"; after adopting, `core_cask_state vlc` is `brew`.
  - `install.bats`: a one-liner run with VLC `hand`: the question comes before the summary box, yes → choices.env keeps `vlc` and fake-brew saw `--adopt vlc`; no → the summary box shows `Media: none`, choices.env has `apps_media=` after "Install?" yes, and no brew call names `vlc`; no to the adoption then no to "Install?" → choices.env unchanged and the next run asks again; a second run after adopting asks nothing new; "omamac stopped while handing VLC to Homebrew." on a failed adopt, and a re-run asks again.
- [ ] **Step 2: Run the two files;** expected: the new tests fail.
- [ ] **Step 3: Implement** fake-brew's `--adopt` (shift it off, `fake_cask` without recreating an app that exists), then the interfaces above.
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: offer a hand-installed app to Homebrew at the first run".

### Task 2: `omamac install` asks it too

**Files:** Modify `lib/add.sh`. Test: `test/add.bats`.

**Interfaces:**
- In `add_run`'s first loop, while `CHOICES[key]` holds the new picks (before the saved answer is put back): for an `apps_*` key, `apps_ask_adopt` over the new picks, then `picks[key]=${CHOICES[$key]}` (may be empty; the second loop skips empty); for `wispr_flow`, when the answer is yes, `apps_ask_adopt wispr-flow` before reading it.
- `apply_all` (unchanged) then adopts through `apps_install`.

- [ ] **Step 1: Write the failing tests:** VLC `hand`, picked in `omamac install`, yes → the box names VLC and fake-brew saw `--adopt vlc`; no → the box doesn't name VLC, choices.env has no `vlc`; VLC no and VS Code picked → the box names only VS Code; every pick answered no → "Nothing picked, so nothing changed.", exit 0, choices.env unchanged; Wispr Flow `hand`, no → `wispr_flow=no` stays; a `brew` or `missing` app is asked nothing.
- [ ] **Step 2: Run `test/add.bats`;** expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: omamac install offers a hand-installed app to Homebrew".

### Task 3: doctor shows the adopt command

**Files:** Modify `lib/doctor.sh`. Test: `test/doctor.bats`.

- [ ] **Step 1: Write the failing tests:** VLC `hand` → the exact ℹ line with `brew install --cask --adopt vlc`; VS Code `hand` → `… --adopt visual-studio-code`; Zoom `hand` → today's line, no command; Ghostty `hand` → `… --adopt ghostty`; Docker Desktop `hand` → today's line; all still exit 0.
- [ ] **Step 2: Run `test/doctor.bats`;** expected: the new tests fail.
- [ ] **Step 3: Implement** in `doctor_check_apps` and `doctor_check_ghostty`.
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: doctor shows how to hand an app to Homebrew".

### Task 4: The `adopt` fixture, hygiene and docs

**Files:** Create `test/fixtures/adopt.env`, `adopt.before.sh`, `adopt.steps.sh`. Modify `test/hygiene.bats`, `README.md`, `CONTRIBUTING.md`.

- [ ] **Step 1: `adopt.env`:** `bare.env` with `apps_media=vlc`. No `.brew-passwords` (VLC asks nothing).
- [ ] **Step 2: `adopt.before.sh`** (zsh, no Homebrew yet): read `url` and `sha256` from `https://formulae.brew.sh/api/cask/vlc.json` with `/usr/bin/jq` (fail if `/usr/bin/jq` is missing or either is empty); download into `mktemp -d`; check the sha256 with `shasum -a 256 -c`; `hdiutil attach -nobrowse -readonly -mountpoint <dir>`; `ditto` `VLC.app` into `/Applications`; detach; mark it downloaded, as a browser would: `xattr -w com.apple.quarantine "0081;$(printf %x "$(date +%s)");Safari;" /Applications/VLC.app`; save `stat -f %i /Applications/VLC.app` to `~/vlc-inode`. A comment says the quarantine is test-only, to look like a real download.
- [ ] **Step 3: `adopt.steps.sh`:** Homebrew lists `vlc`; `stat -f %i /Applications/VLC.app` equals `~/vlc-inode`; choices.env still has `apps_media=vlc`; `omamac update` twice with fingerprints compared (as `apps.steps.sh`); `omamac uninstall vlc` (vm.exp answers yes to the data question): VLC.app is gone and Homebrew no longer lists `vlc`; `omamac doctor`. Both scripts pass `zsh -n`.
- [ ] **Step 4: Hygiene:** `--adopt` appears in `bin`, `lib`, `install.sh`, `update.sh` only in `lib/apps.sh` and in `lib/doctor.sh`'s message text; the fixture-answer test still passes for `adopt.env`.
- [ ] **Step 5: README:** "What it changes": an app you installed by hand is offered to Homebrew ("Let Homebrew take over …?"); yes keeps the app where it is and Homebrew updates it from then on; no leaves it and drops it from your picks; Zoom and Google Drive installed by hand are left alone and dropped, since Homebrew would install them again; `omamac doctor` shows the command for an app installed later, and for Ghostty. Replace "An app you installed by hand is used as is and not updated." accordingly; keep Ghostty's line, adding the doctor hint. CONTRIBUTING: "A change to apps runs `bare`, `apps`, `adopt` and `docker-desktop`."
- [ ] **Step 6: Run shellcheck and the whole suite;** expected: clean, all pass, counts equal.
- [ ] **Step 7: Commit** "test: adopt fixture; docs: adoption".

### Task 5: Review, VM runs, PR, merge (controller)

- [ ] Whole-branch review by a fresh reviewer; fix the findings.
- [ ] Push, then `test/vm.sh phase-6b-adoption adopt`, `apps` and `bare`, from a worktree that isn't switched during the runs (`adopt` and `apps` may run at once: two VMs is the Mac's limit).
- [ ] Open the PR with the result comment ("Phase 6b: passed", the VM facts, bats counts, and "Left for later phases" carried from PR #18 minus 6b's item), and merge once `bats` and `vm` are green.
