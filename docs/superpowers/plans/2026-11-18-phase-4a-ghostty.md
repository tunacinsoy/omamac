# Phase 4a: Ghostty opening into herdr — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ghostty joins the core. Its config gets one optional include line pointing at omamac's file, which sets `command` (a launcher that runs herdr, falling back to zsh) and `macos-option-as-alt = left`. `omamac update` upgrades Ghostty only with App Management, and doctor reports Ghostty, its line and App Management.

**Architecture:** `lib/core.sh` gains one core cask. `lib/ghostty.sh` renders `config/ghostty.conf` into `~/.config/omamac/ghostty.conf` (inside `apply_all`) and picks the user file for the include line (in `install_lines`, like the zsh lines). `bin/omamac-terminal` is the zsh launcher Ghostty runs. `lib/appmanagement.sh` holds Homebrew's own write test; `update.sh` uses it before upgrading Ghostty.

**Tech Stack:** bash 5, zsh, Homebrew, Ghostty 1.4.0, herdr 0.9.5, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-18-phase-4-ghostty-themes-desktop-design.md`, sections "Constraints", "Ghostty (4a)", "Fixtures and VM runs" and "bats" (the why: `vision.md`). Read both before any task.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, and never source `.bats` files outside bats. They act on the real `$HOME`.
- **omamac never runs Ghostty's binary** (`…/Ghostty.app/Contents/MacOS/ghostty`) in `bin/`, `lib/`, `install.sh` or `update.sh`: on a fresh Mac it waits on macOS's "Open?" dialog. Only `test/fixtures/*.steps.sh` may, after removing quarantine.
- bash 5 with `set -Eeuo pipefail` and the callers' ERR traps; `bin/omamac-terminal` is zsh. `boot.sh` is not touched.
- New paths in `lib/paths.sh`: `OMAMAC_APPLICATIONS=${OMAMAC_TEST_APPLICATIONS:-/Applications}`, `OMAMAC_GHOSTTY_FILE=$OMAMAC_CONFIG_DIR/ghostty.conf`, `OMAMAC_TERMINAL=$OMAMAC_HOME/bin/omamac-terminal`, `OMAMAC_GHOSTTY_LINE='config-file = ?~/.config/omamac/ghostty.conf'`.
- The include line carries no `# added by omamac`: Ghostty reads everything after `=` as the value, so a trailing comment would become part of the path and, with `?`, silently never load. The path itself names omamac. (This replaces the spec's "builder checks the comment"; update the spec's line in Task 2.)
- Ghostty's user files, in load order (later wins): `~/.config/ghostty/config`, `~/.config/ghostty/config.ghostty`, `~/Library/Application Support/com.mitchellh.ghostty/config`, `…/config.ghostty`.
- omamac's files are written compare-then-move (`apply_put`).
- Gate files are not changed. Tests never touch the network, a real Ghostty or a real herdr.
- Run tests as `(trap '' PIPE; bats test/)`; the `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac bin/omamac-herdr-mode test/helpers/fake-* | xargs shellcheck`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Ghostty dragged in by hand** (`/Applications/Ghostty.app`, unknown to Homebrew): no `brew install --cask`, one ℹ line, update never upgrades or tests it, doctor ℹ, and the include line and omamac's file are still written. Tests in Tasks 1, 3.
2. **The user already has Ghostty config in Application Support** (a used Mac): the line goes there, the last file Ghostty loads, and nothing else in it changes; with the line already in any of the four files nothing is added. Test in Task 2.
3. **`brew outdated` exits 1 because Ghostty is outdated**: update doesn't stop at that call. Test in Task 3.
4. **herdr missing, or crashing with exit 1**: the window still gets zsh, after one line. Test in Task 2.
5. **App Management refused during update**: the formulas still upgrade, Ghostty is untouched, the click is printed, exit 1. Test in Task 3.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/core.sh` | `CORE_CASKS`, cask install, hand-installed check | 1 |
| `lib/paths.sh` | the new paths above | 1, 2 |
| `lib/remove.sh` | `ghostty` is a core name | 1 |
| `test/helpers/fake-brew` | `outdated`, `list --cask <name>` | 1, 3 |
| `config/ghostty.conf` | omamac's Ghostty settings template | 2 |
| `lib/ghostty.sh` | render, write, pick the user file, add the line | 2 |
| `bin/omamac-terminal` | the launcher | 2 |
| `lib/apply.sh`, `install.sh`, `update.sh`, `bin/omamac` | source `lib/ghostty.sh`; call it | 2, 3 |
| `lib/appmanagement.sh` | `app_management_ok` | 3 |
| `lib/doctor.sh` | Ghostty, its line, omamac's file, App Management | 3 |
| `install.sh` | summary lines | 4 |
| `test/fixtures/bare.steps.sh`, `README.md`, `CONTRIBUTING.md`, `test/hygiene.bats` | VM steps, docs, the no-Ghostty-binary grep | 4 |

### Task 1: Ghostty in the core

**Files:** Modify `lib/core.sh`, `lib/paths.sh`, `lib/remove.sh`, `test/helpers/fake-brew`. Test: `test/core.bats`, `test/remove.bats`.

**Interfaces:**
- Produces: `CORE_CASKS=(ghostty)`; `declare -A CORE_CASK_APP=([ghostty]=Ghostty.app)`; `core_cask_state <cask>` prints `brew`, `hand` (the app is in `$OMAMAC_APPLICATIONS` but `brew list --cask` lacks it) or `missing`, and returns non-zero if Homebrew can't list; `core_install` also installs missing core casks.

- [ ] **Step 1: Write the failing tests** in `test/core.bats`:
  - `"fresh: one cask install for Ghostty"`: after `core_install`, the stub log has exactly one `brew install --cask ghostty`, after the formula install.
  - `"Ghostty from Homebrew: no cask install"`: with `Caskroom/ghostty`, no `install --cask` line.
  - `"Ghostty by hand: used as it is"`: with `$OMAMAC_TEST_APPLICATIONS/Ghostty.app` and no Caskroom entry, no `install --cask`, output contains `Ghostty is already installed, not through Homebrew`, status 0.
  - `"core_cask_state"`: prints `brew`, `hand`, `missing` for the three set-ups; with `T_BREW_LIST_FAIL=1` returns non-zero.
  - In `test/remove.bats`: `"ghostty is core"`: `omamac uninstall ghostty` exits 1 with `ghostty is part of omamac's core`.
  - `setup_sandbox` (in `test/helpers/common.bash`) exports `OMAMAC_TEST_APPLICATIONS="$BATS_TEST_TMPDIR/Applications"` and creates it, so no test sees the real `/Applications`.
- [ ] **Step 2:** Run `(trap '' PIPE; bats test/core.bats test/remove.bats)`; the new tests fail.
- [ ] **Step 3:** Implement as in Interfaces. The cask install is its own `ui_run "Installing Ghostty" brew install --cask …` after the formulas. fake-brew: `list --cask <name>` exits 0 only if `Caskroom/<name>` exists. `remove_run`'s core list gains `"${CORE_CASKS[@]}"`.
- [ ] **Step 4:** Run all of bats; every test passes (`1..N` = `ok` count). Run shellcheck.
- [ ] **Step 5:** Commit `feat: Ghostty joins the core`.

### Task 2: omamac's Ghostty file, the include line and the launcher

**Files:** Create `config/ghostty.conf`, `lib/ghostty.sh`, `bin/omamac-terminal`, `test/ghostty.bats`, `test/terminal.bats`. Modify `lib/apply.sh`, `install.sh`, `update.sh`, `bin/omamac` (source the new lib), `test/hygiene.bats` (parse and shellcheck lists), the spec's include-line sentence.

**Interfaces:**
- Consumes: `apply_put`, `lines_has`, `lines_add`, `OMAMAC_*` paths.
- Produces: `ghostty_render <out>`; `ghostty_config_apply` (in `apply_all` right after `apply_zsh_file`, with `OMAMAC_STEP="writing $OMAMAC_GHOSTTY_FILE"`); `ghostty_user_files` (the four paths, load order, one per line); `ghostty_line_file` (prints the file that holds the line, or the one to add it to); `ghostty_line_add` (called by `install_lines` after the zsh lines, with its own `OMAMAC_STEP` and `ui_ok "Ghostty starts herdr"`).

`config/ghostty.conf` is exactly:

```
# Generated by omamac. Changes here are overwritten; put your own in Ghostty's config.
# Each new window runs herdr; if herdr can't start, the window gets zsh.
command = direct:@OMAMAC_TERMINAL@
# The left Option key is Alt (herdr's chords); the right one still types special characters.
macos-option-as-alt = left
```

`bin/omamac-terminal` (mode 755) behaves as:

```zsh
#!/bin/zsh -il
# Ghostty runs this in each new window. -il loads ~/.zprofile and ~/.zshrc, so
# herdr gets the same PATH and HERDR_CONFIG_PATH as any shell.
if (( $+commands[herdr] )); then
  herdr && exit 0
fi
print -r -- "herdr didn't start, so this is a plain zsh window. Run omamac doctor to see why."
exec zsh -l
```

- [ ] **Step 1: Write the failing tests** in `test/ghostty.bats`:
  - `"render names the launcher by absolute path"`: the rendered file has `command = direct:$HOME/.local/share/omamac/bin/omamac-terminal` and `macos-option-as-alt = left`, and no `@`.
  - `"apply writes once"`: two `ghostty_config_apply` calls; the file's mtime is unchanged by the second.
  - `"no Ghostty config: the line creates config.ghostty"`: `~/.config/ghostty/config.ghostty` holds exactly the line.
  - `"line goes in the last existing file"`: with `~/.config/ghostty/config` and `…/Application Support/com.mitchellh.ghostty/config` both holding `font-size = 14`, the line is appended to the Application Support one, and the other is byte for byte unchanged.
  - `"line already in any file: nothing added"`: with the line in `~/.config/ghostty/config` and another file existing later, no file changes.
  - `"second install_lines changes nothing"`.

  In `test/terminal.bats` (run the script with `HOME` sandboxed and `PATH="$STUB_DIR:/usr/bin:/bin"`, `zsh` stubbed to log and exit 0):
  - `"herdr exits 0: the window closes"`: stub `herdr` exit 0; status 0; no `zsh -l` call; no message.
  - `"herdr exits 1: zsh with one line"`: output is the line above; the stub log has `zsh -l`.
  - `"no herdr: zsh with one line"`: no herdr stub; same.
- [ ] **Step 2:** Run the two files; they fail.
- [ ] **Step 3:** Implement. The `@OMAMAC_TERMINAL@` substitution follows `herdr_render` (bash replacement, not sed). `bin/omamac-terminal` is zsh, which shellcheck can't check, so `test/hygiene.bats` gains `"the launcher parses under zsh"` (`zsh -n`), and CI's shellcheck line doesn't list it. Change the spec's line "The builder checks in the VM that Ghostty accepts a trailing `#` comment…" to say the line has no comment and why.
- [ ] **Step 4:** All bats pass; shellcheck clean.
- [ ] **Step 5:** Commit `feat: Ghostty opens into herdr through omamac's own file`.

### Task 3: App Management, update and doctor

**Files:** Create `lib/appmanagement.sh`. Modify `update.sh`, `lib/doctor.sh`, `bin/omamac` (source it), `test/helpers/fake-brew`. Test: `test/update.bats`, `test/doctor.bats`, `test/appmanagement.bats`.

**Interfaces:**
- Consumes: `core_cask_state`, `ghostty_line_file`, `lines_has`.
- Produces: `app_management_ok <app path>`: 0 allowed, 1 on "Operation not permitted" (prints nothing), 2 on any other failure (prints why to stderr). `APP_MANAGEMENT_URL='x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles'`. `update_upgrade_ghostty` in `update.sh`, run after `update_upgrade_casks`; it sets `UPDATE_FAILED=1` instead of returning non-zero.

fake-brew `outdated --cask --greedy --quiet <name>`: prints `<name>` and exits 1 when `$prefix/outdated` lists it (Homebrew's real exit status), else prints nothing and exits 0.

- [ ] **Step 1: Write the failing tests:**
  - `test/appmanagement.bats`: `touch` stubbed to succeed → 0, and the test file is removed (stub log has `rm`… or the file doesn't exist); stub printing `touch: …: Operation not permitted` and exit 1 → 1, no output; stub printing `No such file or directory` exit 1 → 2 with the reason on stderr.
  - `test/update.bats`:
    - `"Ghostty current: no write test, no cask upgrade"`.
    - `"Ghostty by hand: never checked or upgraded"` (no `outdated --cask` call at all).
    - `"Ghostty outdated and allowed: upgraded greedy"`: log has `brew upgrade --cask --greedy ghostty`; status 0.
    - `"Ghostty outdated, App Management missing"`: `touch` stub says Operation not permitted; log has the formula `brew upgrade` but no `upgrade --cask … ghostty`; `open` stub called with `$APP_MANAGEMENT_URL`; output names System Settings → Privacy & Security → App Management; status 1; the ERR trap message ("omamac stopped while") is absent.
  - `test/doctor.bats`:
    - `"Ghostty from Homebrew with its line"`: ✓ Ghostty, ✓ Ghostty line, ✓ App Management.
    - `"Ghostty by hand"`: ℹ "installed by hand", no App Management line.
    - `"Ghostty missing"`: ✗ with fix `brew install --cask ghostty`; status 1.
    - `"line missing"`: ✗ fix "Run the one-liner again".
    - `"omamac's Ghostty file missing"`: ✗ fix `omamac update`.
    - `"App Management refused is info"`: ℹ with the click; status 0 when nothing else fails.
- [ ] **Step 2:** Run them; they fail.
- [ ] **Step 3:** Implement. `app_management_ok` is touch-then-`rm -f` of `<app>/.omamac-write-test`, matching on the stderr text. In `update_upgrade_ghostty`, read `brew outdated` with `out=$(… ) || true` and decide on `$out`; a failed `brew list` (non-zero `core_cask_state`) skips with an ℹ line. `update_main` ends with a ✗ box and `exit 1` when `UPDATE_FAILED=1`. Doctor's new checks run after `doctor_check_core`.
- [ ] **Step 4:** All bats pass; shellcheck clean.
- [ ] **Step 5:** Commit `feat: update upgrades Ghostty only with App Management; doctor checks Ghostty`.

### Task 4: Summary, VM steps and docs

**Files:** Modify `install.sh` (`install_summary`), `test/fixtures/bare.steps.sh`, `test/hygiene.bats`, `test/install.bats`, `README.md`, `CONTRIBUTING.md`.

- [ ] **Step 1: Write the failing tests:**
  - `test/install.bats` `"summary names Ghostty and the clicks"`: output contains `Open Ghostty`, `App Management`, `click Open`, `command` and `macos-option-as-alt`.
  - `test/hygiene.bats` `"omamac never runs Ghostty's binary"`: `grep -rn 'MacOS/ghostty' bin lib install.sh update.sh` finds nothing.
- [ ] **Step 2:** Run them; the summary test fails.
- [ ] **Step 3:** `install_summary`'s box, each line within 80 columns:
  - `Installed: Homebrew, bash, gum, omamac, Ghostty and the core tools,`
  - `and the languages and cloud CLIs you chose.`
  - `omamac sets two Ghostty settings: command (starts herdr) and macos-option-as-alt.`
  - `Open Ghostty: it starts herdr. The first time, macOS asks you to confirm; click Open.`
  - `Allow App Management for Ghostty: System Settings → Privacy & Security → App Management.`
  - `Log: $OMAMAC_LOG`

  Shorten them if a line passes 80 columns.
- [ ] **Step 4:** `bare.steps.sh` gains, at the end, before its last `omamac doctor`:
  1. `xattr -dr com.apple.quarantine /Applications/Ghostty.app`, with a comment that it stands in for the user's Open click and must come before anything starts Ghostty.
  2. `G=/Applications/Ghostty.app/Contents/MacOS/ghostty`; `$G +show-config --no-pager` has `command = direct:$HOME/.local/share/omamac/bin/omamac-terminal` and `macos-option-as-alt = left`.
  3. `open -a Ghostty`, then wait up to 30 s for `pgrep -x herdr`. The herdr server's environment (`ps -E -ww -o command= -p <pid>`, for the pid whose command is `herdr server`, or the builder's equivalent found in the VM) contains `HERDR_CONFIG_PATH=$HOME/.config/omamac/herdr.toml`.
- [ ] **Step 5: Docs.**
  - README:
    - The top paragraph adds Ghostty opening in herdr.
    - "After install" gains the Open Ghostty, first-open and App Management lines.
    - "What it changes" adds:
      - Ghostty (cask; one by hand is used as is and not updated);
      - the include line and where it goes;
      - `~/.config/omamac/ghostty.conf` and the two settings it takes over;
      - that a pre-release install gets the line by running the one-liner again.
    - "Keeping it up to date" says Ghostty is upgraded only with App Management.
    - The herdr section drops "Ghostty will do it in a later phase".
    - The hand-undo text: delete the line naming `~/.config/omamac/ghostty.conf`; `brew uninstall --cask ghostty`.
  - CONTRIBUTING's steps-file section: remove quarantine before opening an app, and why.
- [ ] **Step 6:** All bats pass; shellcheck clean. Commit `feat: the summary and README cover Ghostty; the VM opens it`.
- [ ] **Step 7: Prove it.** Push; open the PR (spec, plan and vision ride along); run `test/vm.sh phase-4a-ghostty bare` from a clean checkout of the pushed head. On a fail, fix and rerun; never edit a gate file to pass.
