# Phase 7b: docs and the full run — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The README reads as a finished product for a stranger, and one VM run installs every option together (`full`), with `colima` run on the same commit. The README's run time comes from those runs.

**Architecture:** No code changes, unless the full run finds a bug (then a fix with its bats test, in this PR). New fixture files `test/fixtures/full.*`; README and CONTRIBUTING rewritten in place.

**Tech Stack:** zsh fixture scripts, bats-core, Tart.

**Spec:** `docs/superpowers/specs/2026-11-20-phase-7-release-design.md`: "Pull requests" item 3, "The `full` fixture", "The README", "CONTRIBUTING", "The Gate B issue". The why: `vision.md`.

## Global Constraints

- **Hard rule:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats or a test VM; never source `.bats` files outside bats; never run `brew install/uninstall/upgrade`, `defaults write` or `sudo` on this Mac.
- Fixture scripts: `zsh -n` clean; match strings with `[[ … ]]`, never `| grep -q`; nothing runs an app's binary (macOS's first-open check would hang); every command that prompts comes before any `zsh -ic`.
- README: fewest plain words; only what the code does; no apt, Windows or WSL.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Task 1: the `full` fixture

- [ ] `full.env`: `theme=catppuccin`; every app id in its group (`apps_browsers=brave chrome firefox`, `apps_communication=whatsapp telegram signal discord slack zoom`, `apps_media=spotify vlc`, `apps_screen_recording=cap`, `apps_storage=dropbox google-drive`, `apps_developer=vscode`, `apps_productivity=raycast obsidian`); `wispr_flow=yes`; `desktops`, `window_margins`, `dock`, `dock_autohide` = `yes`; every language; every cloud CLI; `docker=docker-desktop`. bats' fixture check must pass.
- [ ] `full.brew-passwords`: `1`. `full.steps-passwords`: the uninstalls that ask (Discord, Dropbox, Zoom, Google Drive, Docker Desktop: 5), plus slack for any other cask that turns out to ask; at most `9`.
- [ ] `full.before.sh`: as `dock.before.sh`, plus each macOS key `fingerprint.sh` lists, saved with `defaults read … 2>/dev/null || echo absent` to `~/settings-before`.
- [ ] `full.steps.sh`, in order (see the spec's list): every app in Applications and every cask listed; every language via `mise ls`; every CLI (`az` by file only, as `cloud.steps.sh`); `readlink /usr/local/bin/docker`; the Dock's apps in order (Ghostty, the catalog order, Docker.app), no Apple app, no Downloads; `starship.toml` equals catppuccin's, then `omamac theme dracula` and it equals dracula's; `omamac update` twice with fingerprints; uninstall every pick (apps, Wispr Flow, Docker Desktop, languages, CLIs, `dock`, `dock-autohide`, `desktops`, `window-margins`), checking each is gone and `choices.env` holds no pick; the Dock arrays and settings equal what `full.before.sh` saved; a second uninstall of one app changes nothing; `omamac doctor`.
- [ ] `zsh -n` on the three scripts; bats passes; commit.

## Task 2: README and CONTRIBUTING

- [ ] README per the spec's "The README": a finished top, "Back up first", the git identity / SSH / GitHub login item in "After install", "Uninstalling" as its own section, "What it changes" last. Keep every fact that is there today; cut repeats.
- [ ] CONTRIBUTING: the full run before a release, and `OMAMAC_VM_TIMEOUT`; the change-to-fixture table gains `full`.
- [ ] Any bats docs check (app ids, themes) passes; commit.

## Task 3: the full run (controller)

- [ ] Push; run `test/vm.sh phase-7b-docs full` and `test/vm.sh phase-7b-docs colima` side by side; time both.
- [ ] A failure: find the cause (systematic-debugging), fix with a test, push, run both again on the new commit.
- [ ] Put the measured time in the README's "Install" (a range from `bare` to `full`); that commit needs both runs again, so do it with the last fix, or run `bare` timing from an earlier run.

## Task 4: review, PR, merge, Gate B issue (controller)

- [ ] Whole-branch review by a fresh reviewer; fix findings.
- [ ] PR; merge when `bats` and `vm` are green; post "Left for later phases".
- [ ] Open the Gate B issue (the spec's "The Gate B issue"), with PR #33's Gate B items and the "For Tuna" items.
