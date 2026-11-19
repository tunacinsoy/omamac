# Phase 6c: the Dock — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On `dock=yes`, Apple's apps and the Downloads stack leave the Dock once, the user's own items stay, omamac's apps are added after them (now and whenever one is installed later), and suggested and recent apps turn off. On `dock_autohide=yes`, the Dock hides. `omamac uninstall dock` and `dock-autohide` put things back; uninstalling an app takes its tile out; doctor reports both; `omamac install` asks both again when answered no.

**Architecture:** A new `lib/dock.sh` changes the Dock through a copy: `defaults export com.apple.dock`, `plutil` edits on the copy, one `defaults import`, then the one `killall Dock` that `settings_dock_restart` already does. `settings_apply` gains the `dock` and `dock_autohide` answers (their `defaults` keys go through the existing record, put-back and doctor code) and calls `dock_apply` after the `dock` keys. The record `dock-before.plist` is the whole export from before the first cleanup; uninstall puts back only its two arrays.

**Tech Stack:** bash 5, macOS `defaults` and `plutil`, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-19-phase-6-apps-and-dock-design.md`: "Constraints" (the Dock facts), "Approaches" (the four Dock rows), "The Dock (6c)", "bats", "Docs" and "Left for later phases" (the 6c item). The why: `vision.md`. Read both before any task. `lib/settings.sh` is the pattern.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, never source `.bats` files outside bats, and **never run `defaults` on `com.apple.dock`, `killall Dock`, `brew install`, `brew uninstall`, `brew upgrade`, `brew reinstall`, `brew services`, `colima` or `sudo` on this Mac**. Tests use fake-defaults, fake-brew and stubs. `plutil` on a file in the test's own temp dir is fine.
- Paths (in `lib/paths.sh`): `OMAMAC_DOCK_RECORD=$OMAMAC_STATE_DIR/dock-before.plist`, `OMAMAC_DOCK_ADDED=$OMAMAC_STATE_DIR/dock-added` (one app file name per line, e.g. `VLC.app`).
- Settings keys: `SETTINGS_KEYS_dock=("com.apple.dock show-recents boolean false")`, `SETTINGS_KEYS_dock_autohide=("com.apple.dock autohide boolean true")`. Labels: `show-recents` → "Suggested and recent apps", `autohide` → "Dock auto-hide".
- Apple's tile: its `tile-data.file-data._CFURLString` starts with `file:///System/`, or its `tile-data.bundle-identifier` is one of `com.apple.iWork.Keynote com.apple.iWork.Numbers com.apple.iWork.Pages com.apple.iMovieApp com.apple.garageband10`. A tile with neither key (a spacer) is the user's.
- Downloads: the `persistent-others` tile whose URL is `$(dock_url "$HOME/Downloads")`.
- omamac's apps, in this order, each only when its file is in `$OMAMAC_APPLICATIONS`: `Ghostty.app`, the chosen catalog apps (`apps_chosen` order, `APP_BUNDLE`), `Docker.app` when `docker=docker-desktop`.
- A new tile, appended with `plutil -insert persistent-apps -xml '<dict>…</dict>' -append`: `tile-type` = `file-tile`, `tile-data.file-data._CFURLString` = the app's URL, `_CFURLStringType` = integer `15`. Nothing else: the Dock fills in the rest.
- A URL: `file://` + the path with each space as `%20` + `/` (`file:///Applications/Visual%20Studio%20Code.app/`).
- Read the copy with `plutil -extract <keypath> raw` (an array gives its count); never `-convert json` (the Dock's plist holds data and dates).
- Exact copy:
  - step names: `OMAMAC_STEP='cleaning up the Dock'`, `'putting the Dock back'`, `"taking <Label> out of the Dock"`.
  - uninstall box: "Dock cleanup: your Dock goes back to how it was before omamac cleaned it. Changes you made to it since are undone."
  - `settings_what dock_autohide`: "your earlier Dock auto-hide setting".
  - doctor ✗, no record: "Dock cleanup", "omamac hasn't cleaned the Dock", fix "omamac update".
- No printed line may contain `Install?`, or match vm.exp's `(Remove|Let Homebrew take over|Also remove) [^?\r\n]*\?` other than the question itself.
- `update.sh` asks nothing.
- Gate files are not changed (PR #17 made the gate changes: the fingerprint lists the Dock, vm.sh runs `before.sh`).
- Run tests as `(trap '' PIPE; bats test/)`, about 4 minutes, in the background or with a long timeout. The `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`, and `zsh -n` on fixture `.sh` files. Fixture scripts match strings with `[[ … ]]`, never `| grep -q`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **An omamac app the user had already pinned** (VLC in the Dock before omamac): not added twice, and written to `dock-added` anyway, so a later run doesn't put it back after the user takes it out. Test in Task 2.
2. **Names with spaces** (`Visual Studio Code.app`): the tile's URL holds `%20`, and a matching tile already in the Dock counts as there. Test in Task 2.
3. **A tile without a URL** (a spacer) or a folder the user added to `persistent-others`: stays, and the walk doesn't stop. Test in Task 2.
4. **A Dock without `persistent-others`** (or without `persistent-apps`): cleanup still works; uninstall removes from the Dock an array the record didn't have. Test in Tasks 2 and 3.
5. **`omamac uninstall dock` when no record exists** (a run that stopped before the Dock step): `show-recents` is put back, `dock=no` is saved, no import. Test in Task 3.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `test/helpers/fake-defaults` | `export <domain> <file>` and `import <domain> <file>` on `$T_DEFAULTS_DIR/<domain>.plist`; `T_DEFAULTS_FAIL=<domain>:import` fails the import | 1 |
| `lib/settings.sh` | the two answers' keys and labels, `settings_apply` calls `dock_apply` | 1, 2 |
| `lib/paths.sh` | the two Dock paths | 2 |
| `lib/dock.sh` | `dock_url`, `dock_apps`, `dock_apply`, `dock_remove_app`, `dock_restore` | 2, 3 |
| `install.sh`, `update.sh`, `bin/omamac` | source `lib/dock.sh` after `lib/settings.sh` | 2 |
| `lib/remove.sh` | `dock` and `dock-autohide`, the tile on app uninstall | 3 |
| `lib/doctor.sh` | "Dock cleanup" and "Dock auto-hide" | 4 |
| `lib/add.sh` | `ADD_KEYS` gains `dock dock_autohide` | 4 |
| `test/fixtures/dock.*`, `README.md`, `CONTRIBUTING.md`, the spec | VM fixture, docs | 5 |

### Task 1: The two answers as settings

**Files:** Modify `lib/settings.sh`, `test/helpers/fake-defaults`. Test: `test/settings.bats`.

**Interfaces:**
- `settings_apply` loops over `desktops window_margins dock dock_autohide`; `settings_label` and `settings_what` as in Global Constraints. `settings_uninstall dock` / `dock_autohide` work unchanged.
- fake-defaults: `export` copies the domain's plist to the file (an empty dict plist, through `plutil -create xml1`, when there is none); `import` copies the file in. Both logged like the other calls.

- [ ] **Step 1: Write the failing tests:** `dock=yes` → `show-recents` is `boolean false`, recorded as absent, one `killall Dock`, "✓ Dock cleanup"; `dock_autohide=yes` → `autohide` `boolean true`, "✓ Dock auto-hide"; a second run writes nothing and doesn't restart the Dock; `settings_uninstall dock_autohide` deletes `autohide`; fake-defaults' export then import round-trips a plist, and import fails with `T_DEFAULTS_FAIL=com.apple.dock:import`.
- [ ] **Step 2: Run `test/settings.bats`;** expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: Dock cleanup and auto-hide set their Dock settings".

### Task 2: Cleaning the Dock and adding omamac's apps

**Files:** Create `lib/dock.sh`, `test/dock.bats`. Modify `lib/paths.sh`, `lib/settings.sh`, `install.sh`, `update.sh`, `bin/omamac`.

**Interfaces:**
- `dock_url <path>`: the URL (Global Constraints).
- `dock_apps`: omamac's app file names in the Dock order, one per line, only those present.
- `dock_apply`: does nothing unless `CHOICES[dock]=yes`. Exports to a `mktemp` copy (removed on every return).
  - No record: `cp` the copy to `OMAMAC_DOCK_RECORD`; remove Apple's tiles from `persistent-apps` and the Downloads tile from `persistent-others` (highest index first); append each app from `dock_apps` not already in `persistent-apps` (by URL), creating the array when absent; import. Import fails → delete the record and return 1. Then write every app from `dock_apps` to `dock-added`, appended or already there (Review Focus 1).
  - Record: append the apps from `dock_apps` that are not in `dock-added` and not in the Dock; import only when one was appended; then add those apps to `dock-added`.
  - Sets `SETTINGS_DOCK=1` after an import. `OMAMAC_STEP='cleaning up the Dock'`.
- `settings_apply`: after the `dock` answer's keys, `dock_apply || { settings_dock_restart; return 1; }`, before its ✓.
- A test helper in `dock.bats`, `dock_seed <apps-url>… -- <others-url>…`, builds `$T_DEFAULTS_DIR/com.apple.dock.plist` with `plutil`; an apps argument `url|bundle-id` sets the bundle id too, `spacer` adds a tile without either. `dock_urls <array>` reads back the URLs in order.

- [ ] **Step 1: Write the failing tests** (`dock.bats`, Ghostty and VLC as files in the fake Applications, `apps_media=vlc`):
  - seeded with `file:///System/Applications/Mail.app/`, `file:///System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/`, `file:///Applications/Keynote.app/|com.apple.iWork.Keynote`, `file:///Applications/Things.app/`, `spacer` and others `file://$HOME/Downloads/`, `file:///Users/x/Projects/` → apps are Things, the spacer, Ghostty, VLC in that order; others is only Projects; the record equals the seeded plist; `dock-added` is `Ghostty.app`, `VLC.app`; one import, one `killall Dock`.
  - a second run: no import, no `killall`, the plist unchanged.
  - VLC already pinned → one VLC tile, and `VLC.app` in `dock-added`; then the user removes it (re-seed without it) → the next run doesn't add it.
  - `apps_developer=vscode` with `Visual Studio Code.app` present → its tile's URL is `file://…/Visual%20Studio%20Code.app/`; seeded with that URL already → one tile.
  - with the record, Spotify installed later (`apps_media="spotify vlc"`, its file added) → Spotify appended after VLC, added to `dock-added`; a run that failed before the Dock step (Spotify present, not in `dock-added`) → added next run.
  - with the record, the record is never rewritten (its checksum unchanged after a run that adds an app).
  - `docker=docker-desktop` with `Docker.app` → added last.
  - no `persistent-others` and no `persistent-apps` in the seed → apps are Ghostty, VLC; no error.
  - import fails → status non-zero, `FAILED: cleaning up the Dock`, no record, no `dock-added`; the next run cleans up.
  - `dock=no` → no `defaults export`.
- [ ] **Step 2: Run `test/dock.bats`;** expected: the new tests fail.
- [ ] **Step 3: Implement** the interfaces above and source `lib/dock.sh` where `lib/settings.sh` is sourced.
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: clean up the Dock and add omamac's apps to it".

### Task 3: Uninstall puts the Dock back and takes tiles out

**Files:** Modify `lib/dock.sh`, `lib/remove.sh`. Test: `test/dock.bats`, `test/remove.bats`.

**Interfaces:**
- `dock_restore`: with a record, export, replace each of `persistent-apps` and `persistent-others` with the record's (`plutil -extract <k> xml1 -o -` from the record, `-remove` then `-insert <k> -xml`; a key the record lacks is removed), import, `SETTINGS_DOCK=1`; then delete the record and `dock-added`. No record: nothing. `OMAMAC_STEP='putting the Dock back'`.
- `dock_remove_app <file name> <label>`: does nothing unless `CHOICES[dock]=yes`. Removes every `persistent-apps` tile whose URL is the app's, imports when one was removed, restarts the Dock, and drops the line from `dock-added`.
- `remove_dock` (in `lib/remove.sh`): `dock=yes` or "Dock cleanup isn't set by omamac." exit 0; the box (Global Constraints); `ask_yes "Remove Dock cleanup?"`; `log_start`; `dock_restore`; `settings_uninstall dock` (its `settings_dock_restart` restarts the Dock once); save `dock=no` last; "✓ Dock cleanup is removed".
- `remove_setting` maps `dock-autohide` → `dock_autohide`. `remove_run`: `dock` → `remove_dock`; the no-name menu offers "Dock cleanup:dock" and "Dock auto-hide:dock-autohide" when yes; the "It can remove" list ends `… colima docker-desktop dock dock-autohide`.
- `remove_app`, not `hand`: after the brew uninstall, before `apps_drop`, `dock_remove_app "${APP_BUNDLE[$id]}" "$label"`. `remove_docker docker-desktop`, not `hand`: the same for `Docker.app` before saving. A `hand` app keeps its tile.

- [ ] **Step 1: Write the failing tests:**
  - `dock.bats`: after a cleanup, the user adds a tile, then `dock_restore` → both arrays equal the seeded ones (the user's tile gone); record and `dock-added` gone; a seed without `persistent-others` → after cleanup the user adds a folder, restore removes `persistent-others`; no record → no export; `dock_remove_app VLC.app VLC` → no VLC tile, `dock-added` without `VLC.app`; VLC not in the Dock → no import, line dropped; `dock=no` → no export.
  - `remove.bats`: `omamac uninstall dock` → the box, "Remove Dock cleanup?", the Dock put back, `show-recents` absent again, `dock=no` saved; answered no → nothing changed; no record → `show-recents` put back, `dock=no`, no import; `dock=no` → the isn't-set line, exit 0; `omamac uninstall dock-autohide` → `autohide` absent, `dock_autohide=no`; `omamac uninstall vlc` with `dock=yes` → its tile gone; with VLC `hand` → its tile stays; `omamac uninstall docker-desktop` → `Docker.app`'s tile gone; the no-name menu lists both; an unknown name lists `dock dock-autohide`.
- [ ] **Step 2: Run the two files;** expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: uninstall puts the Dock back and takes an app's tile out".

### Task 4: doctor and `omamac install`

**Files:** Modify `lib/doctor.sh`, `lib/add.sh`. Test: `test/doctor.bats`, `test/add.bats`.

**Interfaces:**
- `doctor_check_settings` loops over `desktops window_margins dock dock_autohide`; for `dock` without the record: the ✗ line (Global Constraints), and no `settings_check`.
- `ADD_KEYS=("${APPS_KEYS[@]}" wispr_flow languages cloud_clis desktops window_margins dock dock_autohide docker)`.

- [ ] **Step 1: Write the failing tests:**
  - `doctor.bats`: `dock=yes`, record and `show-recents` false → "✓ Dock cleanup"; no record → the ✗ with "omamac update", exit 1; `show-recents` true → "✗ Dock cleanup … Suggested and recent apps was changed since omamac set it"; `dock_autohide=yes` with `autohide` false → its ✗; `dock=no` → no Dock line.
  - `add.bats`: with `dock=no`, `omamac install` asks "Clean up the Dock?"; yes then "Install?" yes → `dock=yes` saved and the Dock cleaned (the export/import calls in the stub log); with `dock=yes`, not asked; the same for auto-hide.
- [ ] **Step 2: Run the two files;** expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite;** expected: all pass, counts equal.
- [ ] **Step 5: Commit** "feat: doctor checks the Dock; omamac install asks the Dock questions again".

### Task 5: The `dock` fixture and docs

**Files:** Create `test/fixtures/dock.env`, `dock.before.sh`, `dock.steps.sh`. Modify `README.md`, `CONTRIBUTING.md`, the spec.

- [ ] **Step 1: `dock.env`:** `bare.env` with `apps_media=vlc`, `dock=yes`, `dock_autohide=yes`.
- [ ] **Step 2: `dock.before.sh`:** writes the Dock's `persistent-apps` URLs to `~/dock-before-apps` and `persistent-others` URLs to `~/dock-before-others`, with the same `defaults read … | sed` as `test/fingerprint.sh`; fails if `~/dock-before-apps` is empty (the Dock hasn't written its plist yet).
- [ ] **Step 3: `dock.steps.sh`**, with a `dock_urls <key>` function like before.sh's:
  1. `persistent-apps` URLs are exactly `file:///Applications/Ghostty.app/` and `file:///Applications/VLC.app/`; `persistent-others` has none; `defaults read com.apple.dock show-recents` is `0`; `autohide` is `1`.
  2. `omamac update` twice with fingerprints compared (as `apps.steps.sh`).
  3. `omamac uninstall vlc`: no VLC URL in the Dock.
  4. `omamac uninstall dock`: both URL lists equal the before files.
  5. `omamac uninstall dock-autohide`: `defaults read com.apple.dock autohide` fails.
  Both scripts pass `zsh -n`.
- [ ] **Step 4: README:** the top line no longer says the Dock comes later; "What it changes": on Dock cleanup, Apple's apps and Downloads leave the Dock once (your own items stay), omamac's apps are added after them, then any omamac installs later, never one you took out; suggested and recent apps turn off; the Dock from before is kept in `~/.local/state/omamac/dock-before.plist`; Dock auto-hide sets `autohide`. Uninstall: `dock` (the Dock goes back, later changes to it are undone) and `dock-autohide`; uninstalling an app takes its tile out. CONTRIBUTING: "A change to the Dock runs `bare` and `dock`."
- [ ] **Step 5: Spec:** in "The Dock (6c)", the record is the whole export from before the first cleanup (uninstall reads only its two arrays); every omamac app found in the Dock goes into `dock-added`, added or not; `omamac uninstall docker-desktop` takes its tile out too; an app uninstalled while `hand` keeps its tile.
- [ ] **Step 6: Run shellcheck and the whole suite;** expected: clean, all pass, counts equal.
- [ ] **Step 7: Commit** "test: dock fixture; docs: the Dock".

### Task 6: Review, VM runs, PR, merge (controller)

- [ ] Whole-branch review by a fresh reviewer; fix the findings.
- [ ] Push, then `test/vm.sh phase-6c-dock dock` and `bare` at once, from a worktree that isn't switched during the runs.
- [ ] Open the PR with the result comment ("Phase 6: passed", the VM facts, bats counts, and "Left for later phases" carried from PR #19 minus the 6c item), and merge once `bats` and `vm` are green.
