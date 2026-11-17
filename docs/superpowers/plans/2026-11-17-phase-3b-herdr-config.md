# Phase 3b: herdr's config — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** jq joins the core; herdr gets omawsl's config and key bindings through `HERDR_CONFIG_PATH`, with a fresh `bin/omamac-herdr-mode` behind the Ctrl g modes and Alt chords; omamac never overwrites the config once herdr or the user changed it; doctor reports which herdr config is in use.

**Architecture:** `config/herdr.toml` is the template. `lib/herdr.sh` renders it (helper path filled in), writes it to `~/.config/omamac/herdr.toml` unless it was changed since omamac last wrote it, and answers whether the user's own config is in use. `apply_all` calls it, so the one-liner and `omamac update` share it. `config/zshrc` exports `HERDR_CONFIG_PATH` only when the user has no config of their own. `bin/omamac-herdr-mode` is a standalone bash 5 script herdr runs from popups and key commands.

**Tech Stack:** bash 5, zsh, Homebrew, herdr 0.9.5, jq, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-17-phase-3-shell-and-tools-design.md`, sections "herdr's config (3b)", "omamac doctor" and "Fixtures and VM runs" (the why: `vision.md`). Read both before any task. The reference behaviour is omawsl's `~/git-repos/omawsl/configs/herdr.toml`, `bin/omawsl-herdr-mode`, `docs/keys.md` and `tests/omawsl_herdr_mode_test.bats`.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh` or `boot.sh` outside bats, and never source `.bats` files outside bats. They act on the real `$HOME`.
- bash 5 (`#!/opt/homebrew/bin/bash`, or sourced by such a script) with `set -Eeuo pipefail`, except the helper (below). `boot.sh` is not touched.
- Core formulas, exactly: `starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq`.
- Never written: `~/.config/herdr/config.toml`, or any file a user's `HERDR_CONFIG_PATH` names.
- omamac's files are written compare-then-move (a second run leaves them and their mtime alone).
- Paths: `OMAMAC_HERDR_FILE=$OMAMAC_CONFIG_DIR/herdr.toml`, `OMAMAC_HERDR_WRITTEN=$OMAMAC_STATE_DIR/herdr.toml.written`, `OMAMAC_HERDR_USER_FILE=$HOME/.config/herdr/config.toml`, `OMAMAC_HERDR_HELPER=$OMAMAC_HOME/bin/omamac-herdr-mode`.
- Gate files (`test/vm.exp`, `test/vm.sh`, `test/fingerprint.sh`, `test/image.sh`, `.github/workflows/bats.yml`, `.github/rulesets/main.json`) are not changed. CI's shellcheck line doesn't list the helper, so `test/hygiene.bats` runs shellcheck on it instead.
- Tests never touch the network or a real herdr server.
- Run tests as `(trap '' PIPE; bats test/)`; the `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac bin/omamac-herdr-mode test/helpers/fake-* | xargs shellcheck`.
- Users never see apt, Windows or WSL (`test/hygiene.bats` greps `bin/` and `config/`).
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Review Focus

1. **herdr's settings screen changed omamac's file** (theme, sound): `omamac update` leaves it byte for byte, says so with the fix, and a second update is just as quiet and changes nothing. Test in Task 2.
2. **A run stopped between writing the file and its copy**: the next run still treats the file as omamac's and finishes the copy, with no "changed" message. Test in Task 2.
3. **The user's own herdr config** (`~/.config/herdr/config.toml`, or their own `HERDR_CONFIG_PATH`): zsh doesn't export omamac's path, the installer and doctor say ℹ, and their file is never written. Tests in Tasks 2, 3, 5.
4. **herdr not reachable from the helper** (server gone, `pane list` empty): the helper says "herdr isn't running" and exits 1 instead of calling herdr with an empty pane id. Test in Task 4.
5. **jq removed by the user**: the helper names `brew install jq` and exits 1 instead of a stream of errors; doctor's core check names jq. Tests in Tasks 1, 4.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/core.sh`, `test/core.bats`, `test/update.bats`, `test/fixtures/bare.steps.sh` | jq in the core; 3a's leftover tests | 1 |
| `config/herdr.toml`, `lib/herdr.sh`, `lib/paths.sh`, `lib/apply.sh`, `install.sh`, `update.sh`, `test/herdr.bats`, `test/install.bats` | the config template and writing it | 2 |
| `config/zshrc`, `test/zshrc.bats` | `HERDR_CONFIG_PATH` | 3 |
| `bin/omamac-herdr-mode`, `test/herdr_mode.bats`, `test/hygiene.bats` | the key-binding helper | 4 |
| `lib/doctor.sh`, `bin/omamac`, `test/doctor.bats` | doctor's herdr check | 5 |
| `README.md`, `CONTRIBUTING.md`, `test/fixtures/bare.steps.sh` | docs; VM steps for 3b | 6 |
| — | review, VM run, PR, merge | 7 |

---

### Task 1: jq joins the core, and 3a's leftover tests

**Files:**
- Modify: `lib/core.sh`, `test/core.bats`, `test/update.bats`, `test/fixtures/bare.steps.sh`

**Interfaces:**
- Produces: `CORE_FORMULAS` ends with `jq` (the Global Constraints list).

- [ ] **Step 1: Update the tests (failing)**
  - `test/core.bats`: `ALL` gains ` jq`; "the core list is the spec's" compares against it.
  - `test/update.bats`: `OMAMAC_FORMULAS` gains `jq` before `bash`. New test:

```bash
@test "every formula pinned: no brew upgrade call" {
  printf '%s\n' $OMAMAC_FORMULAS > "$OMAMAC_TEST_BREW_PREFIX/pinned"
  update
  [ "$status" -eq 0 ]
  ! grep -q '^brew upgrade' "$STUB_LOG"
}
```

- [ ] **Step 2: Run them; the list tests fail** — `bats test/core.bats test/update.bats`.
- [ ] **Step 3: Add `jq` to `CORE_FORMULAS`.** Comment: herdr's key bindings need it.
- [ ] **Step 4: `bare.steps.sh` prints nvim's output when nvim itself fails** (3a leftover): `out=$(nvim --headless "+Lazy! sync" +qa 2>&1) || { print -r -- "$out"; exit 1; }`, then the existing grep.
- [ ] **Step 5: Run the suite and shellcheck.** Expected: all pass, counts match.
- [ ] **Step 6: Commit** — `feat: jq joins the core for herdr's key bindings`.

---

### Task 2: herdr's config, written unless herdr changed it

**Files:**
- Create: `config/herdr.toml`, `lib/herdr.sh`, `test/herdr.bats`
- Modify: `lib/paths.sh`, `lib/apply.sh`, `install.sh`, `update.sh` (source `lib/herdr.sh` before `lib/apply.sh`), `test/install.bats`

**Interfaces:**
- Produces, in `lib/paths.sh`: the four `OMAMAC_HERDR_*` paths (Global Constraints).
- Produces, in `lib/apply.sh`: `apply_put <tmp> <dest>` — `mkdir -p` dest's folder; `cmp -s` → `rm` tmp, else `mv`. `apply_zsh_file` uses it.
- Produces, in `lib/herdr.sh` (sourced after `lib/paths.sh`, `lib/ui.sh`, before `lib/apply.sh`):
  - `herdr_render <out>`: `config/herdr.toml` with every `@OMAMAC_HELPER@` replaced by `$OMAMAC_HERDR_HELPER`, using bash `${s//…/…}`, not sed (a path may hold `&` or `/`).
  - `herdr_changed <rendered>`: returns 0 when `$OMAMAC_HERDR_FILE` exists and differs from both `$OMAMAC_HERDR_WRITTEN` and `<rendered>`.
  - `herdr_user_config`: returns 0 when `$OMAMAC_HERDR_USER_FILE` exists (`-e` or `-L`), or `HERDR_CONFIG_PATH` is set to anything other than `$OMAMAC_HERDR_FILE`.
  - `herdr_config_apply`: render to a temp file in `$OMAMAC_CONFIG_DIR`. If `herdr_changed`: remove the temp file; `ui_info "herdr's config was changed in herdr, so omamac leaves it. To use omamac's again: delete ~/.config/omamac/herdr.toml, then run omamac update."`. Otherwise `apply_put` it to the file, then put a copy to `$OMAMAC_HERDR_WRITTEN`, in that order (Review Focus 2). Then `herdr_user_config` → `ui_info "Your own herdr config is kept."`, else `ui_ok "herdr's config is in place"`.
- `apply_all` runs `herdr_config_apply` after `apply_zsh_file`, with `OMAMAC_STEP="writing $OMAMAC_HERDR_FILE"`.

- [ ] **Step 1: Write `config/herdr.toml`**

Start from omawsl's `configs/herdr.toml`. Keep every key and setting. Add `onboarding = false` as the first key, before any table, with a two-line comment: herdr writes this on its first start, so setting it keeps herdr from changing omamac's file. The helper paths become `@OMAMAC_HELPER@ <mode>`. Rewrite the header so it stands alone: herdr's single prefix and the popup helper, no zellij or omawsl history, no `@OMAWSL_ROOT@`. The `[theme]` line stays (Phase 4).

- [ ] **Step 2: Write `test/herdr.bats` (failing)**

`in_lib` sources `lib/paths.sh lib/ui.sh lib/herdr.sh lib/apply.sh` under `$BASH5`, with `OMAMAC_CHECKOUT=$REPO_ROOT`, as `test/core.bats` does.

```bash
@test "the template's commands all name the helper"     # grep -c '^command = "@OMAMAC_HELPER@ ' config/herdr.toml is 11; no OMAWSL, zellij or omawsl in it
@test "the template sets onboarding = false before any table"  # first non-comment, non-blank line is exactly: onboarding = false
@test "each Ctrl g mode letter opens its popup"         # for p:pane t:tab r:resize m:move o:session, grep -A2 '^key = "prefix+<l>"' finds 'omamac-herdr-mode <mode>"'
@test "fresh: writes the file and its copy"            # both exist, equal; command lines name "$HOME/.local/share/omamac/bin/omamac-herdr-mode pane"; output "herdr's config is in place"
@test "a second run leaves both files alone"           # mtimes (stat -f %m) unchanged
@test "a new template replaces omamac's unchanged file" # edit a copy of the checkout's template (OMAMAC_CHECKOUT in a temp dir); rerun; the file has the new line
@test "changed in herdr: left alone, says how to undo" # append 'sound = false' under [ui] to the file; rerun twice; file byte-equal to before; output both times has "delete ~/.config/omamac/herdr.toml"
@test "stopped before the copy: finishes it quietly"   # fresh run, rm the copy; rerun; copy back, no "changed in herdr"
@test "the user's own config: ℹ and never written"     # pre-make ~/.config/herdr/config.toml; snapshot equal after; output "Your own herdr config is kept."
@test "the user's own HERDR_CONFIG_PATH: ℹ"            # HERDR_CONFIG_PATH=$HOME/mine.toml; output has the ℹ; $HOME/mine.toml not created
@test "herdr config check accepts the rendered file"   # skip unless command -v herdr; HERDR_CONFIG_PATH=<rendered> herdr config check → output starts "config: ok"
@test "no key spelling herdr's client rejects"         # no '"…+plus"' or '"…++"' outside comments (omawsl's test)
```

- [ ] **Step 3: Run it; it fails** — `bats test/herdr.bats`. Expected: FAIL, `lib/herdr.sh` missing.
- [ ] **Step 4: Write `lib/paths.sh` additions, `lib/herdr.sh`, `apply_put`; wire into `apply_all`, `install.sh`, `update.sh`.** Comments in `lib/herdr.sh` say why the copy exists (herdr writes this file from its settings screen) in two lines.
- [ ] **Step 5: `test/install.bats`**: the fresh-run test also checks `~/.config/omamac/herdr.toml` exists; the never-touch test gains a pre-made `~/.config/herdr/config.toml`, unchanged after.
- [ ] **Step 6: Run the suite and shellcheck.** Expected: all pass ("a second update changes no file" in `update.bats` included).
- [ ] **Step 7: Commit** — `feat: herdr gets omawsl's config, left alone once herdr changes it`.

---

### Task 3: `HERDR_CONFIG_PATH` in omamac's zsh file

**Files:**
- Modify: `config/zshrc`, `test/zshrc.bats`

**Interfaces:**
- Produces, in `config/zshrc` after the EDITOR block: when `HERDR_CONFIG_PATH` is unset (`(( ! ${+HERDR_CONFIG_PATH} ))`) and `~/.config/herdr/config.toml` doesn't exist (`[[ ! -e … && ! -L … ]]`), `export HERDR_CONFIG_PATH=~/.config/omamac/herdr.toml`. Not guarded on herdr being installed: the variable is harmless without it, and a later `brew install herdr` works at once. One comment line: herdr can't include another file, so omamac points it at its own when the user has none.

- [ ] **Step 1: Update `test/zshrc.bats` (failing)**
  - "no zellij, apt names or multiplexer start" becomes `grep -E 'zellij|batcat|fdfind|herdr( |$)'` (a command, not the variable), still finding nothing.

```bash
@test "HERDR_CONFIG_PATH points at omamac's file"      # zrc 'print -r -- $HERDR_CONFIG_PATH' → "$HOME/.config/omamac/herdr.toml"
@test "the user's own herdr config wins"               # mkdir -p ~/.config/herdr; touch config.toml; zrc → empty
@test "a HERDR_CONFIG_PATH the user set is kept"       # HERDR_CONFIG_PATH=/x zrc → "/x"
```

- [ ] **Step 2: Run it; the new tests fail.**
- [ ] **Step 3: Add the lines to `config/zshrc`.**
- [ ] **Step 4: Run the suite and shellcheck.** Expected: all pass.
- [ ] **Step 5: Commit** — `feat: zsh points herdr at omamac's config when you have none`.

---

### Task 4: `bin/omamac-herdr-mode`

**Files:**
- Create: `bin/omamac-herdr-mode` (mode 755), `test/herdr_mode.bats`
- Modify: `test/hygiene.bats`

**Interfaces:**
- Produces: `omamac-herdr-mode pane|tab|resize|move|session|quit|new-pane|grow|shrink|focus-or-tab <left|right>`; anything else prints `usage: omamac-herdr-mode …` to stderr, exit 2. Behaviour per mode and key: exactly omawsl's `bin/omawsl-herdr-mode` (its case tables and `docs/keys.md`), written fresh.
- `#!/opt/homebrew/bin/bash`, `set -uo pipefail` (no `-e`: a herdr call that fails, like focusing past an edge, must not end a mode). Comment why.
- Commands: `prefix=${OMAMAC_TEST_BREW_PREFIX:-/opt/homebrew}`; herdr is `$prefix/bin/herdr`, jq `$prefix/bin/jq`. herdr runs key commands without the shell's PATH, so nothing is looked up on PATH.
- Raw socket call (focus a pane by id; herdr 0.9.5's CLI focuses only by direction): `/usr/bin/nc -U -w 1 "$HERDR_SOCKET_PATH"`. macOS `nc` has no `-q`; `-w 1` stops it once the socket is idle. Comment why.
- Start: `$prefix/bin/jq` not executable → `jq is missing. Fix: brew install jq` on stderr, exit 1. After the first `refresh`, no pane id → `herdr isn't running.` on stderr, exit 1.

- [ ] **Step 1: Write `test/herdr_mode.bats` (failing)**

`setup`: `setup_sandbox`; `mkdir -p "$OMAMAC_TEST_BREW_PREFIX/bin"`; link the real jq there (`command -v jq` → skip if none); write the herdr stub from omawsl's `tests/omawsl_herdr_mode_test.bats` to `$OMAMAC_TEST_BREW_PREFIX/bin/herdr` (logging `herdr $*` to `$STUB_LOG`), plus `STUB_NO_PANE=1` making `pane list` print `{"result":{"panes":[]}}`. `MODE=$REPO_ROOT/bin/omamac-herdr-mode`, run as `"$BASH5" "$MODE" …` with keys piped on stdin.

Port every omawsl test with the name changed (pane d split, c note save/clear/prefill, sticky hjkl until Esc, Esc/Enter/Ctrl g leave, CR Enter, new-pane direction, focus-or-tab neighbor and wrap, tab digit, tab `[` at the first tab, tab `]`, resize l/L, l and h at the edges, HJKL with no neighbor, move h, tab hjkl closes, unknown mode → 2), and add:

```bash
@test "pane mode: Tab focuses the next pane by id over the socket"  # STUB_PANES with w1:p1,w1:p2; OMAMAC_TEST_NC=<stub>, HERDR_SOCKET_PATH=/x; printf '\t\e' | … pane → the logged request has "method":"pane.focus" and "pane_id":"w1:p2", and the stub got -U -w 1 /x
@test "no pane: says herdr isn't running, calls nothing else"      # STUB_NO_PANE=1; printf x | … pane → status 1, "herdr isn't running"; STUB_LOG has only "herdr pane list"
@test "no jq: names the fix"                                        # rm the jq link; status 1; output "brew install jq"; STUB_LOG empty
```

For the Tab test the helper's `nc` path is `${OMAMAC_TEST_NC:-/usr/bin/nc}`, the only test hook besides the prefix; the stub writes its stdin to `$STUB_LOG`.

- [ ] **Step 2: Run it; it fails** — the helper is missing.
- [ ] **Step 3: Write the helper.** Comments explain herdr's one-key prefix and why the popup reads the mode's next key itself; no zellij or omawsl history.
- [ ] **Step 4: `test/hygiene.bats`**: "every bash 5 script parses" adds `bin/omamac-herdr-mode`; new `@test "the helper passes shellcheck"` (skip unless `command -v shellcheck`) — CI's shellcheck line can't list it without a gate change.
- [ ] **Step 5: Run the suite and shellcheck.** Expected: all pass.
- [ ] **Step 6: Commit** — `feat: omamac-herdr-mode drives the Ctrl g modes and Alt chords`.

---

### Task 5: doctor's herdr check

**Files:**
- Modify: `lib/doctor.sh`, `bin/omamac` (source `lib/herdr.sh`), `test/doctor.bats`

**Interfaces:**
- Consumes: `herdr_user_config`, `herdr_render`, `herdr_changed` (Task 2).
- Produces: `doctor_check_herdr`, after `doctor_check_neovim`, what `herdr config`:
  - user's own in use → ℹ `your own herdr config is kept, so omamac's key bindings don't reach herdr`;
  - else `$OMAMAC_HERDR_FILE` missing → ✗ `~/.config/omamac/herdr.toml is missing`, fix `omamac update`;
  - else changed (render to a temp file outside `$HOME`, `herdr_changed`, delete it) → ℹ `changed in herdr, so omamac's updates to it are skipped`;
  - else ✓.
  Read-only: the temp render goes in `${TMPDIR:-/tmp}`, never in omamac's folders.

- [ ] **Step 1: Update `test/doctor.bats` (failing)** — `healthy_mac` adds jq to the formulas and writes omamac's herdr file and copy (via `herdr_config_apply` in the sandbox). New tests: `herdr: omamac's config` ✓; `herdr: the user's own config` ℹ, exit 0; `herdr: changed in herdr` ℹ, exit 0; `herdr: omamac's file missing` ✗, exit 1, fix names `omamac update`. "doctor is read-only" stays green with the new check.
- [ ] **Step 2: Run it; it fails.**
- [ ] **Step 3: Add the check.**
- [ ] **Step 4: Run the suite and shellcheck.** Expected: all pass.
- [ ] **Step 5: Commit** — `feat: doctor says which herdr config is in use`.

---

### Task 6: Docs and the VM steps

**Files:**
- Modify: `README.md`, `CONTRIBUTING.md`, `test/fixtures/bare.steps.sh`

- [ ] **Step 1: README**
  - Every core list gains jq (top paragraph, "What it changes", the undo `brew uninstall` line).
  - The zsh file line: the full alias list (`ls`, `lsa`, `ll`, `lt`, `lta`, `tree`, `cat`, `cd`, `ff`, `..`, `...`, `....`, `g`, `gcm`, `gcam`, `gcad`, `d`, `lzg`, `lzd`, `n`, `r`), and that it sets `HERDR_CONFIG_PATH` when you have no herdr config.
  - "What it changes": `~/.config/omamac/herdr.toml` (omawsl's herdr config and key bindings) and `~/.local/state/omamac/herdr.toml.written`. A `~/.config/herdr/config.toml` of your own is used instead and never touched.
  - A short "herdr" section: start it with `herdr` (Ghostty will do it in a later phase); Ctrl g is the prefix, then `p` pane, `t` tab, `r` resize, `m` move, `o` session, `s` scroll; Alt h/j/k/l move between panes, Alt n new pane. herdr's first-run screen is skipped; its settings are Ctrl g ,. Changing settings there makes omamac leave its herdr config alone from then on; `omamac doctor` says so, and deleting `~/.config/omamac/herdr.toml` then `omamac update` brings omamac's back.
  - Undo by hand: also delete `~/.local/state/omamac` (already listed as one of "the three folders": check the wording still holds).
- [ ] **Step 2: CONTRIBUTING** — the helper is shellchecked by `test/hygiene.bats`, not CI's shellcheck line (a gate file); add it to the local shellcheck command.
- [ ] **Step 3: `test/fixtures/bare.steps.sh`** — after the nvim check:

```zsh
[[ $(zsh -ic 'print -r -- $HERDR_CONFIG_PATH') == ~/.config/omamac/herdr.toml ]]
[[ $(zsh -ic 'herdr config check' 2>&1) == "config: ok"* ]]
{ ~/.local/share/omamac/bin/omamac-herdr-mode bogus; [[ $? -eq 2 ]]; } || exit 1
```

  The last line proves the helper starts under Homebrew's bash on a real Mac; under `-e` the non-zero exit must be caught, as written.
- [ ] **Step 4: Run the suite** (hygiene greps the docs). Expected: all pass.
- [ ] **Step 5: Commit** — `docs: herdr's config, keys and what omamac leaves alone`.

---

### Task 7: Review, VM run, PR, merge

- [ ] **Step 1:** `git fetch origin && git rebase origin/main`. Expected: `git diff origin/main --stat` lists no gate file.
- [ ] **Step 2:** Whole-branch review (superpowers:requesting-code-review) against the spec and this plan, with the hard rule in the brief. Each fix its own commit; `(trap '' PIPE; bats test/)` green with matching counts; shellcheck clean.
- [ ] **Step 3:** `git push -u origin phase-3b-herdr-config && test/vm.sh phase-3b-herdr-config bare`. Expected: `✓ … passed`; the log shows jq installed with the core, an identical fingerprint after the second run (it hashes `~/.config/omamac/herdr.toml`), and the steps' herdr checks passing.
- [ ] **Step 4:** PR "Phase 3b: herdr's config and key bindings": what it does, the herdr finding and the rule it led to, the VM result. Merge once `bats` and `vm` are green and review findings are fixed; post a "Phase 3b: passed" comment with "Left for later phases" (3a's list minus what 3b did, plus anything new).
