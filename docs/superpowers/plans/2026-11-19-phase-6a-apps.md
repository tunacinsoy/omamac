# Phase 6a: desktop apps — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The apps picked in the seven app groups, and Wispr Flow on yes, install as Homebrew casks; Zoom, Google Drive and Docker Desktop share one password step right after "Install?"; `omamac install` offers the unpicked apps; `omamac update` upgrades an app only when Homebrew lists it as outdated; `omamac uninstall <app>` asks about settings and data (Docker Desktop too); doctor reports a gone or hand-installed app.

**Architecture:** One data file per app in `apps/`, read by the new `lib/apps.sh` into `APP_CASK`, `APP_BUNDLE`, `APP_PASSWORD` and `APP_ALLOW`, and into `CASK_APP` so `core_cask_state` works for apps. `lib/apps.sh` also holds the id helpers, `apps_install_password` (the shared password step) and `apps_install`. `apply_all`, the summaries, `add_run`, `update.sh`, `lib/remove.sh` and `lib/doctor.sh` call them.

**Tech Stack:** bash 5, Homebrew casks, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-19-phase-6-apps-and-dock-design.md`: "Constraints", "Approaches", "The catalog (6a)", "Installing (6a)", "Updating (6a)", "Uninstalling (6a)", "doctor (6a)", "Fixtures and VM runs (6a)", "bats" and "Docs". The why: `vision.md`. Read both before any task. Phase 5's `lib/docker.sh` and `lib/remove.sh` are the pattern.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, never source `.bats` files outside bats, and **never run `brew install`, `brew uninstall`, `brew upgrade`, `brew reinstall`, `brew services`, `colima` or `sudo` on this Mac**. Tests use fake-brew and stubs.
- The catalog, id → `cask` / `app` (exact):
  `brave` brave-browser / Brave Browser.app · `chrome` google-chrome / Google Chrome.app · `firefox` firefox / Firefox.app · `whatsapp` whatsapp / WhatsApp.app · `telegram` telegram / Telegram.app · `signal` signal / Signal.app · `discord` discord / Discord.app · `slack` slack / Slack.app · `zoom` zoom / zoom.us.app · `spotify` spotify / Spotify.app · `vlc` vlc / VLC.app · `cap` cap / Cap.app · `dropbox` dropbox / Dropbox.app · `google-drive` google-drive / Google Drive.app · `vscode` visual-studio-code / Visual Studio Code.app · `raycast` raycast / Raycast.app · `obsidian` obsidian / Obsidian.app · `wispr-flow` wispr-flow / Wispr Flow.app.
- `password=yes`: `zoom`, `google-drive`. `allow` lines (exact): Cap "Cap: allow Screen Recording, and Camera and Microphone if you use them." · Wispr Flow "Wispr Flow: allow Microphone and Accessibility." · Zoom "Zoom: allow Camera and Microphone, and Screen Recording to share."
- Exact copy:
  - password step: "Homebrew asks for your password for: <labels joined with clis_join>."
  - under the summary, before "Install?": "Homebrew asks for your password once more, after you confirm, for: <labels>." No printed line may contain `Install?`.
  - hand-installed app at install: "<Label> is already installed, not through Homebrew. omamac won't update it."
  - install summary, when any app is chosen: the Ghostty lines become "The first time you open Ghostty and each app, macOS asks you" / "to confirm; click Open.", followed by the `allow` lines of the chosen apps.
- Uninstall copy (exact): not picked "<Label> isn't installed by omamac."; hand box "<Label>: installed by hand, so the app stays. omamac only forgets your pick."; help "On yes, Homebrew also deletes what <Label> keeps in ~/Library."; question `Also remove <Label>'s settings and data?`; box "<Label>: the app." or "<Label>: the app, with its settings and data."; question `Remove <Label>?`; before brew "Homebrew may ask for your password."; done "<Label> is removed". Docker Desktop's help: "On yes, Homebrew also deletes Docker Desktop's images, containers and volumes, and ~/.docker (Docker's settings and saved logins)."; its box on yes: "Docker Desktop: the app and lazydocker, with Docker Desktop's images, containers, volumes and ~/.docker."
- doctor copy (exact): check "Your apps"; ✗ "you chose it, but it's gone from Applications", fix "omamac update puts it back; omamac uninstall <id> drops it"; ℹ "installed by hand, so omamac won't update it".
- No `--greedy` for apps; `--zap` only in `lib/remove.sh`, only after a yes; no `--force` on any cask command; never `HOMEBREW_SUDO_CHECKED` or `SUDO_ASKPASS`.
- Gate files are not changed (PR #17 made the gate changes).
- Run tests as `(trap '' PIPE; bats test/)`, about 4 minutes, in the background or with a long timeout. The `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`, and `zsh -n` on steps files. Steps files match strings with `[[ … ]]`, never `| grep -q`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A download fails halfway** (Chrome's dropped download in the probe): the run stops naming the app ("omamac stopped while installing Chrome."), and the next run installs only what's missing. Test in Task 2.
2. **An app trashed by hand that Homebrew still lists:** install and doctor's Reinstall use `brew reinstall --cask`; for a password app that call runs in the open too. Test in Tasks 2 and 5.
3. **App Management off with three apps outdated:** update upgrades everything else, names all three in the closing ✗ line, exits 1. Test in Task 3.
4. **An app the user removed with `brew uninstall --cask` themselves:** `omamac uninstall <id>` calls no brew and drops the pick; doctor shows ✗ and offers Reinstall. Test in Tasks 4 and 5.
5. **A wrong name for uninstall** (`VS Code`, `apps_media`, `wispr_flow`): refused with exit 2 and the list of names, which includes `vscode` and `wispr-flow`. Test in Task 4.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `apps/<id>` (18 files) | the catalog | 1 |
| `lib/apps.sh` | loader, `apps_chosen`, `apps_key`, `apps_label`, `apps_drop`, `apps_install_password`, `apps_install` | 1, 2 |
| `test/helpers/fake-brew` | catalog casks put their app in Applications; `uninstall --zap`; `outdated` for several casks | 1, 3, 4 |
| `install.sh`, `update.sh`, `bin/omamac` | source `lib/apps.sh` | 1 |
| `lib/apply.sh`, `lib/docker.sh` | the order in `apply_all`; Docker Desktop's cask moves to the password step | 2 |
| `install.sh`, `lib/add.sh` | the line before "Install?", summaries, `ADD_KEYS` | 2 |
| `update.sh` | `update_upgrade_apps`, the closing ✗ line | 3 |
| `lib/remove.sh` | `remove_app`, Docker Desktop's data question, `remove_run`'s list | 4 |
| `lib/doctor.sh` | "Your apps", `doctor_key`, `doctor_offer` | 5 |
| `test/fixtures/apps.*`, `test/fixtures/docker-desktop.*`, `test/hygiene.bats`, `README.md`, `CONTRIBUTING.md` | VM fixtures, hygiene, docs | 6 |

### Task 1: The catalog and its helpers

**Files:** Create `apps/<id>` ×18, `lib/apps.sh`, `test/apps.bats`. Modify `install.sh`, `update.sh`, `bin/omamac` (source `lib/apps.sh` after `lib/core.sh`), `test/helpers/fake-brew` (`fake_cask` creates the app for any cask in `apps/`).

**Interfaces:**
- Produces (associative, keyed by id): `APP_CASK`, `APP_BUNDLE`, `APP_PASSWORD` (`yes` or empty), `APP_ALLOW` (lines joined with `\n`, may be empty). Adds `CASK_APP[<cask>]=<app>`.
- Produces `apps_ids` (every id, question order: the seven `apps_*` groups' values, then `wispr-flow`), `apps_chosen` (the picked ids, same order; reads `CHOICES`), `apps_key <id>` (`apps_media`… or `wispr_flow`), `apps_label <id>` (the question's label; "Wispr Flow" for `wispr-flow`), `apps_drop <id>` (`choices_drop` on its key, or `CHOICES[wispr_flow]=no`). All print one value per line.

- [ ] **Step 1: Write the failing tests in `test/apps.bats`:** every option of the seven groups has `apps/<value>`, and `apps/wispr-flow` exists; every file in `apps/` is one of those; every file has `cask` and `app`; the exact casks, apps, `password` and `allow` values from Global Constraints; a file with a line that isn't `key=value` (or an unknown key) stops sourcing with a message naming the file and line; `apps_chosen` with `apps_media=vlc apps_developer=vscode wispr_flow=yes` prints `vlc vscode wispr-flow` (one per line); `apps_key wispr-flow` → `wispr_flow`, `apps_key vscode` → `apps_developer`; `apps_drop vlc` and `apps_drop wispr-flow` change only their answer; `CASK_APP[visual-studio-code]` is `Visual Studio Code.app`.
- [ ] **Step 2: Run `(trap '' PIPE; bats test/apps.bats)`;** expected: failures (no `lib/apps.sh`).
- [ ] **Step 3: Write the 18 files and `lib/apps.sh`.** The loader reads each line as data (`IFS== read -r key value`, never `source`), allows `cask`, `app`, `password`, `allow`, and skips blank and `#` lines. It needs `OMAMAC_CHECKOUT`; the catalog folder is `$OMAMAC_CHECKOUT/apps`.
- [ ] **Step 4: Run the file, then the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: the app catalog, one file per app".

### Task 2: Installing apps, the password step, and `omamac install`

**Files:** Modify `lib/apps.sh`, `lib/apply.sh`, `lib/docker.sh`, `install.sh` (`install_questions`, `install_summary`), `lib/add.sh`. Test: `test/apps.bats`, `test/install.bats`, `test/add.bats`, `test/docker.bats`.

**Interfaces:**
- Consumes Task 1's helpers.
- Produces `apps_password_pending [<id>…]`: the ids that the password step would install now (chosen apps with `password=yes`, and `docker-desktop` when `docker=docker-desktop`, each in state `missing`), in that order; with ids, only those. `apps_install_password [<id>…]`: runs the step for them (one `brew install --cask …` for the unlisted ones, then one `brew reinstall --cask …` for the listed ones, each through `ui_run_open`, after the password line), adds "Open Docker Desktop once to finish its setup." to `DOCKER_NOTES` when Docker Desktop was in it; returns non-zero on a brew failure. `apps_install [<id>…]`: every chosen app without `password=yes` (or only the given ids), by `core_cask_state`, one `ui_run "Installing <Label>"` each; sets `OMAMAC_STEP="installing <Label>"` before each.
- `apply_all` order: `DOCKER_NOTES=()`, `apps_install_password`, `docker_install`, … , `clis_install`, `apps_install`, `settings_apply`. `docker_install` no longer resets `DOCKER_NOTES`, and its Docker Desktop branch keeps only lazydocker and the `hand` line.

- [ ] **Step 1: Write the failing tests.**
  - `apps.bats`: Zoom, Google Drive and Docker Desktop missing → one `brew install --cask zoom google-drive docker-desktop` call, before any other brew call, run without a spinner, after the exact password line; nothing missing → no password line and no call; Zoom listed but its app gone → `brew reinstall --cask zoom` in a second call; `apps_install` installs VLC and VS Code with two calls, skips a `brew` app, prints the exact hand line for a `hand` app; a failing install of `google-chrome` stops with "omamac stopped while installing Chrome." and a second run calls `brew install --cask google-chrome` only; a second full run calls no install.
  - `install.bats`: with `apps_communication=zoom`, the exact "once more, after you confirm" line is printed before "Install?", and no output line before the prompt contains `Install?`; the summary names apps in "Installed:" and holds the Cap and Wispr Flow `allow` lines and the "Ghostty and each app" lines; with no apps, today's summary is unchanged.
  - `add.bats`: the app groups and Wispr Flow are asked first, offering only unpicked apps; a pick is installed after "Install?"; the password line before "Install?" for Zoom.
  - `docker.bats`: Docker Desktop's "Open Docker Desktop once…" note survives into the summary; `docker_install` with `docker=docker-desktop` makes no cask call.
- [ ] **Step 2: Run the four files;** expected: the new tests fail.
- [ ] **Step 3: Implement** the functions and the order above; `install_questions` and `add_run` print the "once more" line when `apps_password_pending` prints anything. "Installed:" lists, joined "a, b and c": "the languages", "cloud CLIs", "apps" (when any app is chosen), "Docker" (when not `none`).
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: install the chosen apps, the password ones in one early step".

### Task 3: `omamac update` upgrades apps

**Files:** Modify `update.sh`, `test/helpers/fake-brew` (`outdated --cask --quiet a b c` prints each listed outdated one, status 1 if any). Test: `test/update.bats`.

**Interfaces:**
- Replaces `update_upgrade_app` with `update_upgrade_apps`: the casks of Ghostty, Docker Desktop (when chosen) and the chosen apps, only those in state `brew`; one `brew outdated --cask --quiet <casks…>`; for each listed one, `app_management_ok` as today (a refusal adds its label to `UPDATE_NOT_UPGRADED` with today's two ✗ lines); the allowed non-password ones get one `ui_run "Upgrading <Label>"` each; the allowed password ones (`password=yes` and Docker Desktop) get the password line, then one `ui_run_open "Upgrading <labels>" brew upgrade --cask <casks…>`.
- The closing ✗ line: "✗ Everything else is up to date. <clis_join of UPDATE_NOT_UPGRADED> is not." for one, "… are not." for more.

- [ ] **Step 1: Write the failing tests:** one `outdated` call for Ghostty, VLC and Zoom; only the listed ones upgrade; VLC outdated with App Management off → VLC not upgraded, Zoom upgraded, exit 1, VLC named; Ghostty, VLC and Zoom refused → all three named; Zoom and Docker Desktop outdated → one `upgrade --cask zoom docker-desktop` without a spinner; a `hand` app gets no outdated query; no `--greedy` in any app upgrade call; today's Ghostty and Docker Desktop update tests still pass.
- [ ] **Step 2: Run `test/update.bats`;** expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: update upgrades apps only when Homebrew lists them".

### Task 4: `omamac uninstall <app>` and Docker Desktop's data question

**Files:** Modify `lib/remove.sh`, `test/helpers/fake-brew` (`uninstall --cask --zap` is recorded; the app goes as without `--zap`). Test: `test/remove.bats`.

**Interfaces:**
- Produces `remove_app <id>`, dispatched from `remove_run` when the name is in `apps_ids`. The order: not picked → exit 0; `hand` → hand box, `Remove <Label>?`, `apps_drop`, save; otherwise App Management (only when the app exists; the same ✗ lines and `open` as `remove_docker`, naming `omamac uninstall <id>`), help line, `Also remove <Label>'s settings and data?`, box, `Remove <Label>?`, "Homebrew may ask for your password.", `ui_run_open "Removing <Label>" brew uninstall --cask [--zap] <cask>` only when Homebrew lists the cask, `apps_drop`, save last, `ui_ok`.
- `remove_docker docker-desktop`: when the state isn't `hand`, the help line and data question come after the App Management check and before the box; on yes the box is the "with …" one and `docker_uninstall_desktop` gets `--zap` (it takes an optional `--zap` argument).
- `remove_run` with no name offers the chosen apps (labels) after the settings; the "It can remove" list and the "nothing to remove" message include apps.

- [ ] **Step 1: Write the failing tests:** each copy line and the order (calls recorded by fake-brew and fake-gum); `--zap` only when the data question is yes; Enter alone on the data question removes the app without `--zap`; no on `Remove VLC?` changes nothing; not picked exits 0 with no brew call; `hand` drops the pick with no brew call; cask unlisted and app gone → no brew call, pick dropped; App Management off → exit 1, no question asked, pick kept; `wispr-flow` saves `wispr_flow=no`; `VS Code`, `apps_media`, `wispr_flow` → exit 2 with a list holding `vscode` and `wispr-flow`; Docker Desktop: data yes → `uninstall --cask --zap docker-desktop`, data no → today's call and box; a second `omamac uninstall vlc` calls no brew.
- [ ] **Step 2: Run `test/remove.bats`;** expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: omamac uninstall removes an app, with its data on yes".

### Task 5: doctor's "Your apps"

**Files:** Modify `lib/doctor.sh`. Test: `test/doctor.bats`.

**Interfaces:**
- Produces `doctor_check_apps`, run right after `doctor_check_chosen` in `doctor_run`; skipped like "Your tools" when the answers can't be read or Homebrew can't list. It appends gone app ids to `DOCTOR_GONE` (after the tools'). `doctor_key <id>` returns `apps_key <id>` for app ids; `question_label` callers use `apps_label` for app ids.
- `doctor_offer` for an app: "Leave it", "Reinstall it" (`apps_install_password <id>` for a password app, else `apps_install <id>`), "Remove it from my answers" (`apps_drop`, save). Docker Desktop's Reinstall runs `apps_install_password docker-desktop`, then `docker_install`.

- [ ] **Step 1: Write the failing tests:** all chosen apps present → "✓ Your apps"; VLC gone → the exact ✗ line and fix, exit 1; VLC `hand` → the ℹ line, exit 0; Reinstall for VLC calls `brew install --cask vlc` (or `reinstall` when listed), for Zoom runs without a spinner; Remove from answers for `wispr-flow` saves `wispr_flow=no`; Docker Desktop's Reinstall installs the cask; no apps chosen → no "Your apps" line.
- [ ] **Step 2: Run `test/doctor.bats`;** expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: doctor reports the chosen apps".

### Task 6: VM fixtures, hygiene and docs

**Files:** Create `test/fixtures/apps.env`, `apps.steps.sh`, `apps.brew-passwords` (`1`). Modify `test/fixtures/docker-desktop.env` (`apps_communication=zoom`) and `docker-desktop.steps.sh`, `test/hygiene.bats`, `README.md`, `CONTRIBUTING.md` (which fixtures an app change runs).

- [ ] **Step 1: The fixtures,** as the spec's "Fixtures and VM runs (6a)". `apps.steps.sh` checks `$(brew --prefix)/bin/code` with `[[ -L … && $(readlink …) == /Applications/Visual\ Studio\ Code.app/* ]]` and runs no app binary. `docker-desktop.steps.sh` also checks Zoom is installed and listed. Both pass `zsh -n`.
- [ ] **Step 2: Hygiene tests:** no file in `bin`, `lib`, `install.sh`, `update.sh` contains `HOMEBREW_SUDO_CHECKED` or `SUDO_ASKPASS`; no cask command there passes `--force`; `--zap` appears only in `lib/remove.sh` and `lib/docker.sh` (the argument passed through); `--greedy` appears only in `update_upgrade_casks`; the README holds every `allow` line from `apps/`.
- [ ] **Step 3: README,** per the spec's "Docs", 6a parts only (adoption and the Dock come in 6b and 6c; the top still says the Dock comes later).
- [ ] **Step 4: Run shellcheck and the whole suite;** expected: clean, all pass, counts equal.
- [ ] **Step 5: Commit** "test: apps fixture; docs: apps".

### Task 7: Review, VM runs, PR, merge (controller)

- [ ] Before the VM runs, probe in a throwaway VM (from `main` after PR #17): whether `brew uninstall --cask google-drive` takes Google Docs, Sheets and Slides with it, and `brew uninstall --cask --zap docker-desktop` over SSH (exit status, prompts, what stays). Write the facts into the spec's "Constraints"; adjust copy if the zap leaves something.
- [ ] Whole-branch review by a fresh reviewer; fix the findings.
- [ ] Rebase on `main` (PR #17 merged), push, then `test/vm.sh phase-6a-apps apps`, `docker-desktop` and `bare`, one at a time, from a worktree that isn't switched during the runs.
- [ ] Open the PR with the result comment ("Phase 6a: passed", the VM facts, bats counts, and "Left for later phases"), and merge once `bats` and `vm` are green.
