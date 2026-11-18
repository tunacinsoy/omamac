# Phase 4c: desktop and window-margin settings — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** With `desktops=yes` or `window_margins=yes`, the one-liner and `omamac update` apply the macOS settings with `defaults`, recording each key's earlier value the first time omamac changes it. `omamac uninstall desktops` / `window-margins` put those values back. `omamac install` offers the two settings again when answered no, and doctor reports drift.

**Architecture:** `lib/settings.sh` holds the key table, a reader that tells "absent" from a refused read, `settings_apply` (called by `apply_all` after the installs), `settings_restore <key>` and the doctor check. The record is `~/.local/state/omamac/macos-settings.tsv`. `lib/add.sh` and `lib/remove.sh` learn yes/no answers.

**Tech Stack:** bash 5, macOS `defaults`, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-18-phase-4-ghostty-themes-desktop-design.md`, sections "Constraints", "Approaches" (the record row), "Desktop and window-margin settings (4c)", "Fixtures and VM runs" and "bats" (the why: `vision.md`, "macOS desktop and Dock settings"). Read both before any task.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, never source `.bats` files outside bats, and **never run `defaults write`, `defaults delete` or `killall` on this Mac**. Read-only `defaults read` is fine; tests use the fake `defaults` and a `killall` stub.
- The keys, exactly (domain, key, type, wanted value):

  | Answer | Keys |
  | --- | --- |
  | `desktops` | `com.apple.dock mru-spaces bool false`; `NSGlobalDomain AppleSpacesSwitchOnActivate bool true`; `com.apple.universalaccess reduceMotion bool true`; `com.apple.Accessibility ReduceMotionEnabled int 1` |
  | `window_margins` | `com.apple.WindowManager EnableTiledWindowMargins bool true` |

- `defaults read` prints `1`/`0` for booleans; `defaults read-type` prints `Type is boolean|integer|…`. A missing key: exit 1 with `Could not find key` (or `Domain … not found`) on stderr. A protected domain: `Could not write domain <domain>; exiting` on write (and possibly on read). Write with `defaults write <d> <k> -bool true|false` / `-int <n>`.
- Record `OMAMAC_SETTINGS_RECORD=$OMAMAC_STATE_DIR/macos-settings.tsv`: one line per key omamac changed: `domain<TAB>key<TAB>type<TAB>value`, or `domain<TAB>key<TAB>absent`. A key is appended only after omamac's first successful write of it, and never rewritten. The file is deleted when its last line goes.
- Reduce motion is one unit: `reduceMotion` first, `ReduceMotionEnabled` only after it succeeded. A refused protected domain is never a failure: apply and uninstall each print one line instead. Apply prints "Turn on Reduce motion: search for Reduce motion in System Settings." Uninstall says "Turn off" instead. Any other `defaults` failure stops the run through the caller's ERR trap.
- `killall Dock` once per run, only if a `com.apple.dock` or `NSGlobalDomain` key was written or restored.
- On the clean macOS 27.2 image: `mru-spaces`, `AppleSpacesSwitchOnActivate`, `reduceMotion` and `EnableTiledWindowMargins` are absent; `com.apple.Accessibility ReduceMotionEnabled` is present as `0` (integer). So a VM restore deletes four keys and writes `ReduceMotionEnabled` back to `0`.
- Uninstall names: `desktops` → key `desktops`, `window-margins` → key `window_margins`. Titles come from `QUESTION_TITLE` ("Desktops as workspaces", "Window margins").
- Gate files are not changed. Tests never touch the real `defaults`.
- Run tests as `(trap '' PIPE; bats test/)`, which takes about 4 minutes, so run it in the background or with a long timeout. The `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`, and `zsh -n` on steps files. Steps files match strings with `[[ … ]]`, never `| grep -q`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The record must survive everything after the first change.** A second run, a user change then update ("Put back"), and update again must all leave the record byte for byte. Test in Task 1.
2. **Reduce motion refused:** apply records neither key and writes neither, prints the one line, exits 0; uninstall then restores nothing for it and doesn't fail. Tests in Tasks 1, 2.
3. **Restore of a key that was present** (`ReduceMotionEnabled = 0` on a real clean Mac) writes `0` back with its type, not `defaults delete`. Test in Task 2.
4. **A failed uninstall halfway** (a restore that fails for another reason): the answer stays `yes` and the record keeps the keys not yet restored, so running it again finishes. Test in Task 2.
5. **`omamac install` with `desktops=no`:** asked again; a yes replaces `no` (never `"no yes"`), then applies; a no changes nothing. Test in Task 2.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/settings.sh` | key table, `settings_read`, `settings_apply`, `settings_restore`, `settings_check` | 1, 2, 3 |
| `test/helpers/fake-defaults` | a `defaults` double, bash 3.2 safe, per-domain files under `$T_DEFAULTS_DIR`; `T_DEFAULTS_REFUSE=<domain>` refuses it | 1 |
| `lib/paths.sh`, `lib/apply.sh`, `install.sh`, `update.sh`, `bin/omamac` | record path, wiring, sourcing, the summary line | 1 |
| `lib/add.sh`, `lib/remove.sh`, `lib/choices.sh` (if needed) | yes/no answers in install and uninstall | 2 |
| `lib/doctor.sh` | the settings check | 3 |
| `test/fixtures/desktop.env`, `test/fixtures/desktop.steps.sh`, `README.md`, `CONTRIBUTING.md` | VM fixture and docs | 3 |

### Task 1: Apply the settings and keep the record

**Files:** Create `lib/settings.sh`, `test/helpers/fake-defaults`, `test/settings.bats`. Modify `lib/paths.sh`, `lib/apply.sh`, `install.sh`, `update.sh`, `bin/omamac` (source `lib/settings.sh` before `lib/apply.sh`), `test/helpers/common.bash` (link `fake-defaults` as `defaults` and stub `killall` in `setup_sandbox`; export `T_DEFAULTS_DIR`).

**Interfaces:**
- `SETTINGS_KEYS_desktops` / `SETTINGS_KEYS_window_margins`: arrays of `"domain key type value"` strings, in the table's order. Or an equivalent table; later tasks use the next two functions only.
- `settings_keys <answer-key>`: prints that answer's lines.
- `settings_read <domain> <key>`: prints `<type> <value>` or `absent`; returns 3 when the domain refuses to be read, other non-zero on other errors.
- `settings_apply`: for each answer that is `yes`, applies its keys as the Global Constraints say. It prints:
  - "Put back: <what>" for a recorded key it wrote again, where `<what>` names the setting, e.g. "Reduce motion";
  - the refused line;
  - one `ui_ok` per answer that is applied.

  It sets `OMAMAC_STEP` per key. Called at the end of `apply_all`.
- `SETTINGS_REFUSED=1` when Reduce motion was refused, so `install_summary` adds its line.

- [ ] **Step 1: Write the failing tests** in `test/settings.bats`:
  - `"no yes answers: defaults is never written"`.
  - `"desktops on a clean Mac"`: three keys absent and `ReduceMotionEnabled` integer `0` →
    - all four hold the wanted values;
    - the record has four lines: three `absent`, and `com.apple.Accessibility	ReduceMotionEnabled	integer	0`;
    - `killall Dock` called once.
  - `"window margins on a clean Mac"`: one key written, one `absent` line, no `killall`.
  - `"second apply changes nothing"`: no `defaults write` or `killall` in the stub log; the record is byte-identical.
  - `"a value the user changed is put back, the record kept"`: set `mru-spaces` to true after the first apply, apply again → `Put back:` line, value false, record byte-identical.
  - `"already the wanted value: not written, not recorded"`: `mru-spaces` already false before the first apply → no write for it, no record line for it.
  - `"Reduce motion refused"`: `T_DEFAULTS_REFUSE=com.apple.universalaccess` →
    - neither Reduce motion key is written or recorded;
    - the other keys are applied;
    - the "Turn on Reduce motion" line is printed;
    - status 0.
  - `"another defaults failure stops the run"`: the fake fails a write with an unrelated error, the status is non-zero, and the step names the key.
  - `"record with a key from an earlier run is never rewritten"`: a pre-existing line keeps its old value after apply.
- [ ] **Step 2:** Run them; they fail.
- [ ] **Step 3:** Implement. `install_summary` gains the Reduce motion line when `SETTINGS_REFUSED=1`. Existing install and update tests keep passing (the sandbox fake defaults makes their default `no` answers no-ops; `FRESH_ANSWERS` has `desktops=yes`, so fresh-install tests now see settings applied and `killall Dock` stubbed).
- [ ] **Step 4:** All bats pass; shellcheck clean. Commit `feat: the desktop and window-margin settings, with a record of earlier values`.

### Task 2: Uninstall restores, install offers again

**Files:** Modify `lib/settings.sh`, `lib/remove.sh`, `lib/add.sh`. Test: `test/settings.bats`, `test/remove.bats`, `test/add.bats`.

**Interfaces:**
- Consumes: `settings_keys`, `settings_read`, the record format.
- Produces:
  - `settings_restore <answer-key>`, which restores each recorded key of that answer:
    - `absent` → `defaults delete`, where a missing key counts as done;
    - otherwise → `defaults write -<type flag> <value>`, where `boolean` becomes `-bool true|false` from `1|0` and `integer` becomes `-int`.
  - It removes each restored line from the record as it goes, deletes an empty record, runs `killall Dock` if needed, and prints the "Turn off Reduce motion" line on a refused domain.
  - Restore with no record lines for that answer changes nothing.
- `remove_run`:
  - accepts `desktops` and `window-margins`;
  - a `no` answer prints "<title> isn't set by omamac." and exits 0;
  - shows "Desktops as workspaces: your earlier Spaces, app-switching and Reduce motion settings" or "Window margins: your earlier window-margin setting";
  - asks `Remove <title>?`;
  - on yes, runs `settings_restore`, then sets the answer to `no` and saves, last;
  - its no-name menu adds the settings answered `yes`.
- `add_run`: `ADD_KEYS` gains `desktops window_margins`.
  - A yes/no key answered `yes` is skipped.
  - Answered `no`, it is asked with `ask_one`. A `yes` replaces the saved answer; `choices_add` is for multi answers only.
  - The summary line is the question's title.
  - After "Install?", `apply_all` applies it.

- [ ] **Step 1: Write the failing tests:**
  - settings.bats:
    - `"restore puts back absent and present values"`: after `"desktops on a clean Mac"`, restore → three keys deleted, `ReduceMotionEnabled` written back as integer `0`, record gone, `killall Dock` called.
    - `"restore again changes nothing"`.
    - `"restore with Reduce motion refused"`: the others are restored, the line is printed, and status is 0. That answer's lines are dropped from the record, the refused ones too, as the spec says. The printed line tells the user to turn Reduce motion off by hand.
  - remove.bats:
    - `"uninstall desktops"`: the box text, `Remove Desktops as workspaces?` answered yes, the answer is saved `no`, and the record is gone.
    - `"uninstall window-margins maps the name"`.
    - `"not set by omamac"`: exit 0 with the message.
    - `"no-name menu offers settings answered yes"`.
    - `"a failed restore leaves the answer yes and the rest recorded"`: the fake fails the second key's delete with an unrelated error. The status is non-zero and the answer is still `yes`. The record has lost the first key's line and still holds the rest. Rerun with the failure gone, and it finishes.
  - add.bats:
    - `"desktops no: asked again; yes applies"`: the saved answer becomes `yes`, never `no yes`, and the keys are written.
    - `"desktops yes: not asked"`.
    - `"answer no again: nothing changes"`.
- [ ] **Step 2:** Run them; they fail.
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** All bats pass; shellcheck clean. Commit `feat: uninstall puts the settings back; install offers them again`.

### Task 3: Doctor, the VM fixture and docs

**Files:** Modify `lib/settings.sh` (`settings_check`), `lib/doctor.sh`, `test/doctor.bats`, `README.md`, `CONTRIBUTING.md`. Create `test/fixtures/desktop.env`, `test/fixtures/desktop.steps.sh`.

**Interfaces:** `doctor_check_settings`. For each `yes` answer:
- ✓ "<title>" when every key holds its wanted value;
- otherwise ✗ "<title>", "<what> was changed since omamac set it", with fix `omamac update`;
- Reduce motion unreadable because the domain refuses: ℹ with the "search for Reduce motion" click;
- skipped (ℹ) when the answers can't be read, like the other choice checks.

- [ ] **Step 1: Write the failing tests** in doctor.bats: all set → ✓; `mru-spaces` changed → ✗ with the fix; Reduce motion refused → ℹ; both answers `no` → no settings lines.
- [ ] **Step 2:** Run them; they fail. Implement; they pass.
- [ ] **Step 3: VM fixture.**
  - `desktop.env` is `bare.env` with `desktops=yes` and `window_margins=yes`.
  - `desktop.steps.sh` runs in zsh `-eux`, with an `fp` helper like `bare.steps.sh`'s. It checks:
    1. The five keys read as wanted: `mru-spaces` 0, `AppleSpacesSwitchOnActivate` 1, `reduceMotion` 1, `ReduceMotionEnabled` 1, `EnableTiledWindowMargins` 1.
    2. `~/.local/state/omamac/macos-settings.tsv` has five lines.
    3. `omamac update` twice, fingerprints equal.
    4. `omamac uninstall desktops`, then `omamac uninstall window-margins`.
    5. The four keys are absent (each `defaults read` exits non-zero), `ReduceMotionEnabled` reads 0, the record is gone, and both answers are `no` in `choices.env`.
    6. Fingerprint, both uninstalls again, fingerprint, and the two are equal.
- [ ] **Step 4: Docs.**
  - README "What it changes" lists:
    - the five keys per answer;
    - the record file;
    - that uninstall puts the earlier values back;
    - that Reduce motion may need the click.
  - README "After install" says how to give an app its own desktop: right-click its Dock icon → Options → Assign To. This is the vision's README step.
  - README gives `omamac uninstall desktops` / `window-margins` one line.
  - CONTRIBUTING lists the `desktop` fixture.
- [ ] **Step 5:** All bats pass; shellcheck and `zsh -n` clean. Commit `feat: doctor checks the settings; the desktop VM fixture`.
- [ ] **Step 6 (controller):** whole-branch review, merge `main`, push, `test/vm.sh phase-4c-desktop-settings desktop` and `… bare` from a clean worktree of the pushed head, PR.
