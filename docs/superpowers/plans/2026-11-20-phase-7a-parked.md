# Phase 7a: the parked items — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every item parked in earlier phases is settled. The ones a user can hit that show a wrong next step, or break "nothing pre-selected", are fixed; the rest are GitHub issues labelled `after-v1`, Gate B checklist lines, or closed because they no longer hold.

**Architecture:** Small, separate fixes in `lib/ui.sh`, `bin/omamac`, `lib/add.sh`, `lib/ask.sh`, `lib/apps.sh`, `boot.sh` and the test sandbox. No new files in `lib/`.

**Tech Stack:** bash 5, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-20-phase-7-release-design.md`, "Pull requests" item 2. The why: `vision.md`.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, never source `.bats` files outside bats, and never run `brew install/uninstall/upgrade`, `defaults write` or `sudo` on this Mac.
- Each fix has a bats test that fails without it.
- Run tests as `(trap '' PIPE; bats test/)`; the `1..N` count must equal the `ok` count. Shellcheck as CONTRIBUTING shows.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Decisions on the parked items

Checked against `main` at 6d04933 (after PR #21 if merged first).

| Item (PR) | Outcome |
| --- | --- |
| `GUM_*` from the user's environment could pre-select (2) | Fix, Task 1 |
| `omamac install`'s failure says "run omamac update" before anything was saved (3c, 6b) | Fix, Task 2 |
| `omamac uninstall herdr` with no `choices.env` gives the "doesn't know your answers" message (3c) | Fix, Task 2 |
| gum failure on `install`/`uninstall` says "Run the one-liner again" (3c) | Fix, Task 2 |
| doctor's Reinstall of one app ends with "Your apps are installed" (6a) | Fix, Task 3 |
| A regular file at `~/.local/share/omamac` gives network help (2) | Fix, Task 3 |
| The sandbox doesn't unset `STARSHIP_CONFIG` (4b) | Fix, Task 1 |
| A gum error on a yes/no reads as "no" (2) | Issue: gum exits 1 for "no" and for its own errors, so the exit code can't tell them apart; `ask_need_tty` covers the likely cause (no terminal) |
| A render failure in doctor reads as ✓ (3b) | Closed: `herdr_render` left doctor in f5709cc; `languages_render` reads ✗ |
| A `run ! grep` passes when the log is missing (3c) | Closed: every one targets a log that always exists |
| The README names Ctrl g `,` twice (3b) | Closed: once |
| The ruleset JSON lacks a field; `vm.exp` number check; VM name collision (2, 6c) | Done in PR #21 |
| The README's "about 10 minutes" (2) | 7b |
| doctor says "Homebrew no longer has Docker Desktop" when only the app is gone (5b) | Issue: the fix it prints is right |
| Duplicated lookups across install, uninstall and doctor (3c) | Issue (refactor) |
| An old `choices.env` without `languages`/`cloud_clis` (3c) | Closed: no one has a pre-v1 `choices.env` |
| An unreadable herdr config makes zsh print a read error (3b) | Issue |
| Unchecked against live herdr: a key command that exits 1; `nc -U -w 1` and Tab (3b) | Gate B |
| What Esc does in gum (2) | Gate B |
| A root-owned `~/.local` or `~/.config` gives a raw `mkdir` error (2) | Issue |
| A commented-out include line counts as present (4a) | Issue |
| A hand-written value of the wrong type stops every update (4c) | Issue |
| A failed put-back during settings rollback is swallowed (4c) | Issue |
| "Homebrew may ask for your password." before steps that won't ask (6a) | Issue |
| The password step makes one `brew list` per password app (6a) | Issue |
| Adoption relies on every cask having `auto_updates` (6b) | Issue |
| "run omamac update" when Homebrew can't list during `omamac install`'s questions (6b) | Fix, Task 2 (same message) |
| `adopt.before.sh` uses the arm64 disk image (6b) | Closed: omamac is Apple Silicon only |
| 6c's four small items (killed run, deleted record, process substitution, URL encoding) | One issue |
| Test gaps: 3a's four, 3b's four, 3c's (`MISE_YES`, `mise prune` failing, tap call order, "line 18"), 4a's update-can't-list, 4c's note-failure loop, `deny_app_management` copied | One issue |
| "For Tuna" items (Google Drive's login item, `docker login` credentials, window margins on a fresh Mac, ristretto's fork, Dock cleanup on update, `--greedy` for Ghostty) | In the Gate B issue, for Tuna to decide |

## Task 1: `GUM_*` and the sandbox

- [x] In `test/helpers/common.bash`'s sandbox, unset `STARSHIP_CONFIG` next to `HERDR_CONFIG_PATH`.
- [x] Test (in `test/ask.bats` or the closest file): with `GUM_CHOOSE_SELECTED=x` and `GUM_CONFIRM_DEFAULT=true` exported, a question runs, and fake-gum's recorded environment holds no `GUM_` variable. Extend `fake-gum` to log `env | grep '^GUM_'` if it doesn't already. It fails first.
- [x] `lib/ui.sh`: after `UI_GUM=…`, unset every `GUM_*` variable (`unset "${!GUM_@}"`), with a one-line why: gum reads them, and the user's could pre-select or restyle omamac's prompts. Every entry point sources `lib/ui.sh` before it asks.
- [x] Tests pass; commit.

## Task 2: messages that name the next step

- [x] `omamac install` failing before its answers are saved: `omamac_failed` says "run omamac install again" (nothing was saved), and "run omamac update" only after `choices_save` in `lib/add.sh`. A flag set right after the save (for example `ADD_SAVED=1`) decides. Tests: a failure while asking (Homebrew can't list) and one after saving.
- [x] `ask_broken`: under `omamac <cmd>` (`OMAMAC_CMD` set), "Run omamac <cmd> again."; at the first run, as today. Tests for both.
- [x] `omamac uninstall <core tool>` without `choices.env`: the core message, not "doesn't know your answers". Move the core check out of `remove_run` into `remove_refuse_core`, which `bin/omamac` calls before `omamac_choices`. `remove_run` no longer checks: its only caller is `bin/omamac`, and its menu offers no core name. Test.
- [x] Tests pass; commit.

## Task 3: doctor's Reinstall line, and a file where omamac goes

- [x] `apps_install`: "Your apps are installed" only when called with no ids (the whole run). Test: doctor's Reinstall of one app doesn't print it; the first run still does.
- [x] `boot.sh`: when `$OMAMAC_HOME` exists and isn't a folder, stop with "$OMAMAC_HOME exists and isn't an omamac checkout. Move it away and run this again. The checkout wasn't changed." (the folder case's words). Test in `test/boot_install.bats` or the checkout tests.
- [x] Tests pass; commit.

## Task 4: issues (controller)

- [x] Create the `after-v1` label. One issue per "Issue" row above (grouped rows are one issue), each: what happens, where, why it waits. Titles short.
- [x] Note the Gate B rows and the "For Tuna" row for 7b's Gate B issue (the spec's "The Gate B issue").

## Task 5: review, VM runs, PR, merge (controller)

- [ ] Whole-branch review by a fresh reviewer.
- [ ] Push; open the PR with the decisions table and the issue links.
- [ ] VM: `bare` and `apps` (Task 3 touches app installs and Task 2 install's failure paths).
- [ ] Merge when `bats` and `vm` are green; post the "Left for later phases" comment.
