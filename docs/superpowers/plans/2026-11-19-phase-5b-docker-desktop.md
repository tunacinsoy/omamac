# Phase 5b: Docker Desktop — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** With `docker=docker-desktop`, the one-liner and `omamac update` install the `docker-desktop` cask and lazydocker, `omamac update` upgrades Docker Desktop the way it upgrades Ghostty, `omamac uninstall docker-desktop` removes them but keeps the user's Docker data, and doctor reports what's gone.

**Architecture:** `lib/docker.sh` gains the Docker Desktop branch of `docker_install`, `docker_sudo` (asks for the password in the open, only when sudo isn't already valid) and `docker_uninstall_desktop`. `lib/core.sh`'s cask-to-app map becomes `CASK_APP` and learns `Docker.app`, so `core_cask_state` works for both apps. `update.sh`'s Ghostty upgrade becomes `update_upgrade_app <cask> <label>`. `lib/remove.sh` and `lib/doctor.sh` treat `docker-desktop` like `colima`.

**Tech Stack:** bash 5, Homebrew casks, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-19-phase-5-docker-design.md`, sections "Constraints", "Approaches", "Docker Desktop (5b)", "Fixtures and VM runs" (5b) and "bats". The why: `vision.md`. Read both before any task. Phase 5a's code in `lib/docker.sh` is the pattern.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, never source `.bats` files outside bats, and **never run `brew install`, `brew uninstall`, `brew upgrade`, `brew services`, `colima` or `sudo` on this Mac**. Tests use fake-brew, fake-colima and a `sudo` stub.
- The cask is `docker-desktop`; its app is `$OMAMAC_APPLICATIONS/Docker.app`. Its formula is `lazydocker` only: `docker_formulas docker-desktop` prints `lazydocker`.
- Cask states, as for Ghostty (`core_cask_state`): `missing` → `brew install --cask docker-desktop`, or `brew reinstall --cask docker-desktop` when Homebrew lists the cask; `brew` → nothing; `hand` → one ℹ line, exact: "Docker Desktop is already installed, not through Homebrew. omamac won't update it."
- Password: before every Docker Desktop cask step (install, reinstall, upgrade, uninstall), `docker_sudo`: if `sudo -n true` succeeds, nothing; else one ℹ line, exact: "Docker Desktop needs your password for its links in /usr/local.", then `sudo -v`. Call `sudo` from PATH, never `/usr/bin/sudo`, so bats can stub it. In the one-liner, boot.sh keeps sudo valid, so it never asks there.
- Summary line, exact, added to `DOCKER_NOTES` in the run that installs (or reinstalls) the cask: "Open Docker Desktop once to finish its setup."
- Upgrading Docker Desktop: only when the state is `brew` and `brew outdated --cask --quiet docker-desktop` prints it; no `--greedy`; App Management checked first with `app_management_ok`, exactly as Ghostty today.
- Uninstall box, exact: "Docker Desktop: the app and lazydocker. Your images, containers and volumes stay." Question: `Remove Docker Desktop?` (default No). Not the answer: "Docker Desktop isn't installed by omamac." and exit 0. A hand-installed app stays, with: "Docker Desktop wasn't installed by omamac, so it stays."
- omamac never uses `--zap`, never touches `~/Library/Containers/com.docker.docker`, `~/.docker` or `~/.colima`, never removes quarantine, and never starts or quits Docker Desktop itself (Homebrew's cask uninstall quits it).
- Gate files are not changed (`test/fingerprint.sh` already covers `/usr/local/bin` and `/usr/local/cli-plugins`).
- Run tests as `(trap '' PIPE; bats test/)`, about 4 minutes, so run it in the background or with a long timeout. The `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`, and `zsh -n` on steps files. Steps files match strings with `[[ … ]]`, never `| grep -q`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **No terminal for the password** (doctor's Reinstall or `omamac update` run from a script): `sudo -v` fails, and the step must stop with a clear ✗, not hang or carry on. Test in Task 1 (a `sudo` stub that fails on `-v`).
2. **A Docker Desktop the user trashed by hand** while Homebrew still lists the cask: install reinstalls it, doctor offers Reinstall, uninstall still runs `brew uninstall --cask` (it cleans Homebrew's record) without an App Management check (there's no app to test). Test in Tasks 1, 3, 4.
3. **App Management off at uninstall:** nothing changes (no brew call, answer kept), and the message says what to click. Test in Task 3.
4. **Two apps not upgraded** (Ghostty and Docker Desktop both outdated, App Management off): update upgrades everything else, names both in the closing ✗ line, exits 1. Test in Task 2.
5. **The user's own `docker` formula with Docker Desktop:** the cask installs beside it (the probe VM showed it only skips its `_docker` completion, 2026-11-19), update doesn't upgrade it, uninstall doesn't remove it. Test in Tasks 1, 2, 3.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/core.sh`, `lib/doctor.sh`, `update.sh` | `CORE_CASK_APP` → `CASK_APP`, with `[docker-desktop]=Docker.app` | 1 |
| `lib/docker.sh` | `docker_formulas docker-desktop`, `docker_sudo`, `docker_install`'s Docker Desktop branch, `docker_uninstall_desktop`, `docker_check`'s Docker Desktop lines | 1, 3, 4 |
| `test/helpers/fake-brew` | `fake_cask docker-desktop` also creates `Docker.app` | 1 |
| `install.sh`, `lib/add.sh` | name Docker in the summaries for any answer but `none` | 1 |
| `update.sh` | `update_upgrade_app`, the closing ✗ line | 2 |
| `lib/remove.sh` | `omamac uninstall docker-desktop` | 3 |
| `lib/doctor.sh` | Docker Desktop in "Your tools" and doctor's Reinstall | 4 |
| `test/fixtures/docker-desktop.env`, `test/fixtures/docker-desktop.steps.sh`, `README.md`, `CONTRIBUTING.md`, the spec | VM fixture, docs, spec facts | 4 |

### Task 1: Install Docker Desktop

**Files:** Modify `lib/core.sh`, `lib/docker.sh`, `lib/doctor.sh` and `update.sh` (the rename only), `install.sh` (`install_summary`), `lib/add.sh`, `test/helpers/fake-brew`. Test: `test/docker.bats`, `test/add.bats` (the two tests that say Docker Desktop installs nothing: line 19's comment and "install: Docker Desktop isn't named as installed yet").

**Interfaces:**
- Produces `CASK_APP` (associative, cask → app folder name): `[ghostty]=Ghostty.app [docker-desktop]=Docker.app`. `core_cask_state <cask>` and every former `CORE_CASK_APP` use read it.
- Produces `docker_formulas docker-desktop` → `lazydocker`.
- Produces `docker_sudo`: returns 0 when sudo is valid (asking only if needed), non-zero when `sudo -v` fails.
- `docker_install` for `docker=docker-desktop`: lazydocker if missing, then the cask per Global Constraints; `ui_ok "Docker Desktop is installed"` (also for `hand`).

- [ ] **Step 1: Write the failing tests in `test/docker.bats`**

```bash
@test "desktop: installs lazydocker and the cask, asking for sudo first"   # stub sudo: -n fails, -v ok → stub_calls order: sudo -n true, sudo -v, brew install --cask docker-desktop; output has "needs your password"; Docker.app exists; DOCKER_NOTES has "Open Docker Desktop once to finish its setup."
@test "desktop: valid sudo asks nothing"                                   # stub sudo exits 0 → no "sudo -v" in stub_calls, no "needs your password"
@test "desktop: a failed sudo -v stops before the cask"                    # stub sudo exits 1 → status non-zero; no "brew install --cask"
@test "desktop: already from Homebrew, a second run changes nothing"       # Caskroom/docker-desktop and Docker.app present, lazydocker in Cellar → no brew install/reinstall, no sudo call, DOCKER_NOTES empty
@test "desktop: listed by Homebrew but the app is gone, reinstalls it"     # Caskroom entry, no Docker.app → "brew reinstall --cask docker-desktop"
@test "desktop: a hand-installed app is used as it is"                     # Docker.app, no Caskroom → ℹ "omamac won't update it"; no cask call, no sudo call
@test "desktop: the user's own docker formula stays, the cask installs"   # docker in Cellar → cask installed; no "brew uninstall docker" or "brew install docker"
@test "colima: a failed marker write stops the run"                        # chmod a-w the state dir → status non-zero, no ui_ok line
@test "install summary names Docker for Docker Desktop"                    # replaces "install summary doesn't name Docker for Docker Desktop yet"
```

`test/add.bats`: "install: Docker Desktop is named as installed" (replaces the "isn't named" test): the closing box has "Installed: Go, Docker Desktop" and the Docker Desktop line.

- [ ] **Step 2: Run them and see them fail** — `(trap '' PIPE; bats test/docker.bats test/add.bats)`.

- [ ] **Step 3: Implement.** The rename in `lib/core.sh` (comment: the casks omamac installs and the app each puts in Applications, core or not), `lib/doctor.sh`, `update.sh`. `fake_cask` creates `Docker.app` for `docker-desktop` as it does `Ghostty.app`. In `lib/docker.sh`: `docker_formulas`, `docker_sudo`, and `docker_install` branches on the answer (`colima`: today's body; `docker-desktop`: new; else return 0). No check for Homebrew's `docker` formula: the spec's conflict turned out false (see the spec's updated fact). Add `|| return` to the colima marker's `mkdir -p` and `: >` (left from 5a). `install_summary` and `add_run`: Docker is named for any answer but `none`; drop the two "until Phase 5b" comments.

- [ ] **Step 4: Run the whole suite and shellcheck** — all pass, `1..N` equals the `ok` count.

- [ ] **Step 5: Commit** — `feat: install Docker Desktop, asking for the password in the open`.

### Task 2: `omamac update` upgrades Docker Desktop

**Files:** Modify `update.sh`. Test: `test/update.bats`.

**Interfaces:**
- Consumes `CASK_APP`, `core_cask_state`, `docker_sudo` (Task 1).
- Produces `update_upgrade_app <cask> <label>`: today's `update_upgrade_ghostty` body with the cask and label as parameters; for `docker-desktop` it calls `docker_sudo` right before `brew upgrade --cask docker-desktop` (and a failed `docker_sudo` counts as not upgraded). Not upgraded → the label is appended to `UPDATE_NOT_UPGRADED` (an array that replaces `UPDATE_FAILED`).

- [ ] **Step 1: Write the failing tests in `test/update.bats`**

```bash
@test "update upgrades lazydocker by name for Docker Desktop"          # docker=docker-desktop, lazydocker in Cellar → "brew upgrade" args include lazydocker, not docker
@test "Docker Desktop outdated and allowed: upgraded after sudo"       # Docker.app, Caskroom, outdated lists docker-desktop → stub_calls: sudo before "brew upgrade --cask docker-desktop"; no --greedy
@test "Docker Desktop current: no sudo, no cask upgrade"
@test "Docker Desktop by hand: never upgraded"
@test "Docker Desktop isn't upgraded unless it is the answer"          # docker=colima, Docker.app from Homebrew and outdated → no "upgrade --cask docker-desktop"
@test "Ghostty and Docker Desktop not allowed: both named, exit 1"     # both outdated, write test refused → status 1; output has "Ghostty and Docker Desktop are not"; other upgrades still ran
```

The existing Ghostty update tests stay unchanged and must pass.

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Implement.** `update_main` calls `update_upgrade_app ghostty Ghostty`, then `update_upgrade_app docker-desktop "Docker Desktop"` only when `CHOICES[docker]` is `docker-desktop`. Its ✗ messages put the label where "Ghostty" is today. The closing ✗ box: "✗ Everything else is up to date. <labels joined with " and "> is not." (one) or "are not." (two). `update_upgrade` needs no change: `docker_formulas docker-desktop` already gives `lazydocker`.

- [ ] **Step 4: Run the whole suite**, then **Step 5: Commit** — `feat: omamac update upgrades Docker Desktop like Ghostty`.

### Task 3: `omamac uninstall docker-desktop`

**Files:** Modify `lib/docker.sh`, `lib/remove.sh`. Test: `test/remove.bats`.

**Interfaces:**
- Consumes `docker_sudo`, `CASK_APP`, `core_cask_state`, `core_cask_listed`, `app_management_ok`.
- Produces `docker_uninstall_desktop`: when Homebrew lists the cask, `docker_sudo` then `brew uninstall --cask docker-desktop`; then `brew uninstall lazydocker` if installed. Returns non-zero on any failure.
- `remove_docker <colima|docker-desktop>` replaces today's `remove_docker`; the colima path is unchanged.

- [ ] **Step 1: Write the failing tests in `test/remove.bats`**

```bash
@test "uninstall docker-desktop: not the answer exits 0"            # docker=colima → "Docker Desktop isn't installed by omamac.", status 0, no brew call
@test "uninstall docker-desktop: shows what goes, no changes nothing"  # box text exact; gum_answers no → no brew call, answer kept
@test "uninstall docker-desktop: removes in order, answer last"     # stub_calls: sudo, brew uninstall --cask docker-desktop, brew uninstall lazydocker; Docker.app gone; docker=none; no --zap
@test "uninstall docker-desktop: App Management off changes nothing"  # write test refused → status 1; output names App Management; no brew call; docker=docker-desktop
@test "uninstall docker-desktop: a hand-installed app stays"        # Docker.app, no Caskroom → "wasn't installed by omamac, so it stays."; no "--cask" call; lazydocker removed; docker=none
@test "uninstall docker-desktop: app trashed, cask listed"          # Caskroom, no Docker.app → no write test, "brew uninstall --cask docker-desktop" still runs
@test "uninstall docker-desktop: a failed sudo keeps the answer"    # stub sudo fails → status non-zero; docker=docker-desktop
@test "uninstall docker-desktop: a second run changes nothing"      # status 0, no brew call
@test "uninstall docker-desktop: the user's own docker formula stays"  # docker in Cellar → no "brew uninstall docker"
@test "uninstall with no name offers Docker Desktop"                # picker options include "Docker Desktop:docker-desktop"
@test "uninstall: the unknown-name list names docker-desktop"
```

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Implement.** `remove_run`'s `case`: `colima | docker-desktop) remove_docker "$name"`. `remove_docker <name>` checks the answer equals the name, then for `docker-desktop` reads the cask state before the box: `brew` → `app_management_ok` on the app; refused (1) → `ui_fail "macOS won't let your terminal change apps, so nothing was removed."`, `ui_fail` the same Fix line update prints, `open "$APP_MANAGEMENT_URL" || true`, exit 1; other failure (2) → `ui_fail` and exit 1. `hand` → `ui_info "Docker Desktop wasn't installed by omamac, so it stays."` after the box. Then the box, `ask_yes "Remove Docker Desktop?"`, `log_start`, `docker_uninstall_desktop`, `CHOICES[docker]=none`, `choices_save`, `ui_ok "Docker Desktop is removed"`. The no-name picker offers the Docker answer when it isn't `none`, labelled with `question_label docker`; the "It can remove" list adds `docker-desktop`.

- [ ] **Step 4: Run the whole suite**, then **Step 5: Commit** — `feat: omamac uninstall docker-desktop keeps the user's Docker data`.

### Task 4: Doctor, the VM fixture and docs

**Files:** Modify `lib/docker.sh`, `lib/doctor.sh`, `test/hygiene.bats`, `README.md`, `CONTRIBUTING.md`, the spec. Create `test/fixtures/docker-desktop.env`, `test/fixtures/docker-desktop.steps.sh`. Test: `test/doctor.bats`.

**Interfaces:** Consumes Tasks 1 and 3.

- [ ] **Step 1: Write the failing tests in `test/doctor.bats`**

```bash
@test "doctor: Docker Desktop with everything in place is ✓"
@test "doctor: a gone Docker Desktop app is ✗ under Your tools"     # Caskroom, no Docker.app → one "Docker Desktop" line naming Docker Desktop; fix "omamac update puts it back; omamac uninstall docker-desktop drops it"; status 1
@test "doctor: a gone lazydocker is ✗, one Docker Desktop entry"    # names lazydocker
@test "doctor: a hand-installed Docker Desktop is ℹ"                # "installed by hand, so omamac won't update it"; status 0
@test "doctor: offers to reinstall Docker Desktop"                  # gum_answers reinstall, stub sudo ok → "brew reinstall --cask docker-desktop"
@test "doctor: with colima, a Docker Desktop app isn't reported"
```

`test/hygiene.bats`: the `colima delete` grep covers `bin lib install.sh update.sh` (left from 5a), and a new test: no `--zap` and no `xattr` in `bin lib install.sh update.sh`.

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Implement.** In `doctor_check_chosen`, generalise the colima block to the Docker answer: for `docker-desktop`, gone when `core_cask_state docker-desktop` is `missing` or lazydocker is missing; one `docker-desktop` entry in `DOCTOR_GONE`, its "why" naming what's gone ("Docker Desktop", "lazydocker", or both, joined with `clis_join`). `doctor_key docker-desktop` → `docker`. `doctor_offer` already sends `docker` to `docker_install` with Leave/Reinstall. `docker_check` for `docker-desktop`: `hand` → `doctor_report info "Docker Desktop" "installed by hand, so omamac won't update it"`; else nothing (the ✓ comes from "Your tools").

- [ ] **Step 4: VM fixture.** `docker-desktop.env` = `bare.env` with `docker=docker-desktop`. `docker-desktop.steps.sh` per the spec's 5b steps 1–3, with:
  - Step 1 checks `[[ -d /Applications/Docker.app ]]`, `brew list --cask docker-desktop`, `[[ $(readlink /usr/local/bin/docker) == /Applications/Docker.app/* ]]`, `lazydocker --version`.
  - Step 3's stand-in: `print -r -- admin | sudo -S -p '' -v`, with a comment: the steps have no keyboard, so this stands in for the user typing the password; `-p ''` because vm.exp answers any "Password:" prompt and counts it. Then `omamac uninstall docker-desktop`, the checks (no app, no cask, no `/usr/local/bin/docker`, `docker=none`), a second uninstall with fingerprints compared, and `omamac doctor`.

- [ ] **Step 5: Docs.** README: the top paragraph no longer says Docker Desktop comes later; "After install": "If you chose Docker Desktop, open it once to finish its setup."; "What it changes": the `docker-desktop` cask and lazydocker, and that Homebrew asks for your password for its links in `/usr/local`; update names Docker Desktop (as Ghostty, App Management); uninstall names `docker-desktop` and that your Docker data stays. CONTRIBUTING: the steps' sudo stand-in joins the stand-ins line. Spec: the `_docker` conflict fact gets the probe's answer (2026-11-19: with the `docker` formula installed, the cask installs and only skips linking its `_docker` completions, so the check is dropped; an SSH session may write inside Docker.app, so App Management doesn't block the VM's uninstall), and the "bats" section matches what was built (three summaries, the broken-link state, no service line when colima is gone, the 5b tests).

- [ ] **Step 6: Run the whole suite and shellcheck**, then **Step 7: Commit** — `feat: doctor checks Docker Desktop; the docker-desktop VM fixture; docs`.

### Task 6: Homebrew asks for Docker Desktop's password, in the open and early

Found in the VM: Homebrew resets sudo (`utils/sudo.sh`) and asks itself on every Docker Desktop cask step, so `docker_sudo` is dropped. Brief: `.superpowers/sdd/2026-11-19-phase-5b-docker-desktop/task-6-brief.md`.

- [ ] `ui_run_open` in `lib/ui.sh` (no spinner; `ui_run` without gum calls it). `docker_cask_run` prints "Homebrew asks for your password for Docker Desktop's links in /usr/local." and runs the brew command with it, for install, reinstall, upgrade and uninstall. `UPDATE_NOT_UPGRADED`'s password branch goes.
- [ ] `apply_all` runs `docker_install` first.
- [ ] Tests: the ℹ line before the cask call, no `gum spin` for the cask, a failed install returns non-zero with errexit off, Docker before the core formulas.
- [ ] VM fixture: `docker-desktop.brew-passwords` = `1`; the `sudo -S` stand-in goes.
- [ ] Docs: README, CONTRIBUTING, vision (the one-prompt line, the decision, the log), the spec.

### Task 5: Review, VM runs, PR, merge

- [ ] Whole-branch review (fresh reviewer, the spec and this plan), findings fixed.
- [ ] Push; `test/vm.sh phase-5b-docker-desktop docker-desktop` and `test/vm.sh phase-5b-docker-desktop bare`, both from a checkout nobody commits to while they run.
- [ ] PR with "Decisions", spec and plan links, bats count, both VM results; merge when `bats` and `vm` are green.
- [ ] Post "Phase 5b: passed" with "Left for later phases" (carry PR #14's list, minus what 5b did).
