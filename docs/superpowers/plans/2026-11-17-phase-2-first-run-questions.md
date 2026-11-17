# Phase 2: first-run questions — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `install.sh` asks the first-run questions it has no saved answer for, shows one summary and "Install?", and saves the answers in `~/.local/state/omamac/choices.env` before anything else is written; re-runs skip the questions.

**Architecture:** `lib/questions.sh` holds the question table (keys, kinds, texts, `Label:value` options). `lib/choices.sh` reads `choices.env` as data into an associative array, checks it against the table and writes it back only when it changed. `lib/ask.sh` asks the missing questions with gum on the tty, prints the summary and asks "Install?". `install.sh` runs them first; doctor reuses `choices_load`. A separate, earlier gate PR teaches `test/vm.exp` to answer "Install?".

**Tech Stack:** bash 5, gum 2 (`choose`, `confirm`), bats-core, shellcheck, expect, Tart.

**Spec:** `docs/superpowers/specs/2026-11-17-phase-2-first-run-questions-design.md` (the why: `vision.md`). Read both before any task.

## Global Constraints

- Everything in this plan is bash 5 (`#!/opt/homebrew/bin/bash` or sourced by such a script) with `set -Eeuo pipefail`. `boot.sh` is not touched.
- Every gum prompt reads `< "$OMAMAC_TTY"`; `OMAMAC_TTY=${OMAMAC_TEST_TTY:-/dev/tty}` (the same seam `boot.sh` uses).
- Nothing is selected before the user picks it: no `--selected`; every `gum confirm` has `--default=false`; Docker lists `No Docker:none` first.
- `choices.env` is never `source`d or `eval`ed. Each line is `^[a-z_]+=[a-z0-9 -]*$`, a table key, once, with a valid value.
- Nothing in `install.sh` writes a file before "Install?" is answered yes.
- Ctrl-C at any prompt: print `Stopped. Nothing was changed.` and exit 130.
- Users never see apt, Windows or WSL, so the carriage-return error must not say "Windows" (`test/hygiene.bats` greps `lib/`).
- Gate files (`test/vm.exp`, `test/vm.sh`, `test/fingerprint.sh`, `test/image.sh`, `.github/workflows/bats.yml`, `.github/rulesets/main.json`) change only in Task 1's PR.
- Messages: fewest plain words, ✓ ✗ ℹ markers via `lib/ui.sh`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Review Focus

1. **Last line without a newline.** A hand-edited `choices.env` whose last line has no trailing newline must still be read (`while read` drops it by default). Test in Task 2.
2. **Carriage returns** (a file saved by an editor with CRLF endings): stop naming the line and "carriage return", never treat `no\r` as a new value. Test in Task 2.
3. **Spacing in multi values** (`apps_browsers=brave  firefox`, trailing space): rejected with the line number, not split into an empty id. Test in Task 2.
4. **Empty value for a single or yes/no key** (`theme=`, `dock=`): invalid, not "answered". Test in Task 2.
5. **Saving fails** (`~/.local/state/omamac` not writable): the run stops naming "saving your answers", and no zsh file or line is written. Test in Task 4.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `test/vm.exp`, `test/vm_exp.bats`, `test/fingerprint.sh`, `test/vm.sh` (comment) | gate: terminal size, answer "Install?" once, fingerprint `choices.env` | 1 |
| `lib/questions.sh` | the question table and lookups | 2 |
| `lib/choices.sh` | read, check, render, save `choices.env` | 2 |
| `lib/paths.sh` | `OMAMAC_CHOICES_FILE`, `OMAMAC_TTY` | 2 |
| `test/fixtures/bare.env`, `test/choices.bats` | complete fixture; parser tests; every fixture valid | 2 |
| `lib/ask.sh`, `test/helpers/fake-gum`, `test/helpers/common.bash`, `test/ask.bats` | asking, summary, "Install?"; gum test double | 3 |
| `install.sh`, `test/install.bats` | questions first, then Phase 1 steps | 4 |
| `lib/doctor.sh`, `bin/omamac`, `test/doctor.bats` | "Saved answers" check; `GIT_OPTIONAL_LOCKS=0` | 5 |
| `README.md`, `CONTRIBUTING.md` | docs | 6 |
| — | rebase, review, VM run, PR | 7 |

---

### Task 1: Gate PR — the VM loop answers "Install?"

Branch `gate-install-prompt` from `main` (already created, empty). This is its own PR, opened before Phase 2's.

**Files:**
- Modify: `test/vm.exp`
- Modify: `test/fingerprint.sh`
- Modify: `test/vm.sh` (step 3 comment only)
- Test: `test/vm_exp.bats`

**Interfaces:**
- Produces: `vm.exp` sets the spawned terminal to 50 rows × 120 columns, sends `y` (no Enter) on the first match of `Install?`, ignores later matches in the same run, and still fails on any other `(y/n)` / `[y/N]` prompt. `fingerprint.sh` prints a `shasum -a 256` line for `~/.local/state/omamac/choices.env`.

- [ ] **Step 1: Extend the fake ssh in `test/vm_exp.bats` and write the failing tests**

The stub gains, after its password prompts: `T_SIZE=1` prints `size:$(stty size)`; `T_INSTALL=<n>` prints `Install?` n times, then reads one key (`read -r -n1 k`) and prints `got:$k`, then `read -r -t 2 -n1 extra && echo "extra:$extra"`; `T_ASK="<text>"` prints that text and waits for a line.

```bash
@test "the terminal has a size, so gum draws" {
  T_SIZE=1 vm_exp
  [ "$status" -eq 0 ]
  [[ "$output" == *"size:50 120"* ]]
}

@test "Install? is answered with one y, redraws ignored" {
  T_INSTALL=2 vm_exp
  [ "$status" -eq 0 ]
  [[ "$output" == *"got:y"* ]]
  [[ "$output" != *"extra:"* ]]
}

@test "any other y/n prompt still fails" {
  T_ASK='Continue? (y/n)' vm_exp
  [ "$status" -eq 1 ]
  [[ "$output" == *"unexpected prompt"* ]]
}
```

- [ ] **Step 2: Run them; the first two fail**

Run: `bats test/vm_exp.bats`
Expected: "the terminal has a size" and "Install? is answered" FAIL; the rest pass.

- [ ] **Step 3: Change `test/vm.exp`**

`set stty_init "rows 50 cols 120"` before `spawn`; a `set answered 0`; in the `expect` block, before the y/n pattern, `-re {Install\?}` → if `answered` is 0, `send -- "y"` and set it to 1; then `exp_continue` either way. A comment says why: gum draws nothing in a 0×0 terminal, and redraws its prompt, so only the first sighting is answered.

- [ ] **Step 4: Add `choices.env` to `test/fingerprint.sh`**

Add `~/.local/state/omamac/choices.env` to the `shasum -a 256` line. Change `test/vm.sh`'s step 3 comment to `# 3. The fixture, where install.sh reads it.`

- [ ] **Step 5: Run the suite and shellcheck**

Run: `bats test/ && git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`
Expected: all pass, no shellcheck output.

- [ ] **Step 6: Commit, push, VM run, PR**

```bash
git add test/vm.exp test/vm_exp.bats test/fingerprint.sh test/vm.sh
git commit -m "test: VM loop answers Install? and fingerprints saved answers"
git push -u origin gate-install-prompt
test/vm.sh gate-install-prompt bare
```
Expected: `✓ gate-install-prompt (bare) passed`. Open the PR into `main` titled "Gate: the VM loop answers Install?", body: what changed and why (gum draws nothing at 0×0; redraws), that its purpose is the gate, and the VM result. Tell Tuna it's ready to merge; Phase 2 work continues on the stacked branch meanwhile.

---

### Task 2: The question table and `choices.env`

On `phase-2-first-run-questions`, rebased onto `gate-install-prompt` (`git rebase gate-install-prompt`).

**Files:**
- Create: `lib/questions.sh`, `lib/choices.sh`
- Modify: `lib/paths.sh`, `test/fixtures/bare.env`
- Test: `test/choices.bats`

**Interfaces:**
- Produces, in `lib/paths.sh`: `OMAMAC_CHOICES_FILE=$OMAMAC_STATE_DIR/choices.env`, `OMAMAC_TTY=${OMAMAC_TEST_TTY:-/dev/tty}`.
- Produces, in `lib/questions.sh` (the spec's table, rows 1–16, exact keys, values and option order; Docker: `No Docker:none` first):
  - `QUESTION_KEYS` — indexed array of the 16 keys in table order.
  - `QUESTION_KIND[key]` — `single` | `multi` | `yesno`.
  - `QUESTION_TEXT[key]` — the question text.
  - `QUESTION_TITLE[key]` — the short summary label: Theme, Browsers, Communication, Media, Screen recording, Storage and sync, Developer, Productivity, Wispr Flow, Desktops as workspaces, Window margins, Dock cleanup, Dock auto-hide, Languages, Cloud CLIs, Docker.
  - `QUESTION_OPTIONS[key]` — newline-separated `Label:value` lines (empty for `yesno`).
  - `question_values <key>` — prints the allowed values one per line (`yes`, `no` for `yesno`).
  - `question_label <key> <value>` — prints the label for a value (`yes`/`no` for `yesno`).
- Produces, in `lib/choices.sh`:
  - `CHOICES` — global associative array, key → value.
  - `choices_load <file>` — resets `CHOICES`, fills it, returns 0; on a bad line prints `<file>, line <n>: <problem>. Fix: delete that line and run the one-liner again; omamac asks that question again.` to stderr and returns 1. A missing file is 0 answers. Multi values are stored in table order.
  - `choices_missing` — prints keys with no answer, in table order.
  - `choices_render` — prints the file body: the header comment, then `key=value` for every answered key in table order.
  - `choices_save <file>` — `mkdir -p` the folder, render to a temp file there, `mv` into place only if `cmp -s` says it differs.

- [ ] **Step 1: Write `test/choices.bats` (failing)**

Each test sources `lib/paths.sh`, `lib/questions.sh`, `lib/choices.sh` under `$BASH5` via a small `in_lib '<code>'` helper. Tests, with these assertions:

```bash
@test "the table has the 16 keys in the vision's order" {
  in_lib 'echo "${QUESTION_KEYS[*]}"'
  [ "$output" = "theme apps_browsers apps_communication apps_media apps_screen_recording apps_storage apps_developer apps_productivity wispr_flow desktops window_margins dock dock_autohide languages cloud_clis docker" ]
}
@test "Docker lists No Docker first"            # first line of QUESTION_OPTIONS[docker] is "No Docker:none"
@test "a missing file has no answers"           # choices_missing prints all 16 keys
@test "reads a full file"                       # bare.env: CHOICES[theme]=tokyo-night, CHOICES[docker]=none, CHOICES[apps_media]=""
@test "comments and blank lines are skipped"
@test "the last line needs no newline"          # printf 'theme=nord' (no \n) → CHOICES[theme]=nord
@test "unknown key stops with the line number"  # line 2 'colour=red' → status 1, output has "line 2" and "Fix: delete that line"
@test "duplicate key stops"
@test "bad single value stops"                  # theme=neon
@test "empty single or yes/no value stops"      # theme=  ;  dock=
@test "bad yes/no value stops"                  # dock=maybe
@test "unknown or duplicate multi value stops"  # apps_browsers=brave opera ; apps_browsers=brave brave
@test "double or trailing spaces stop"          # 'apps_browsers=brave  firefox' ; 'apps_browsers=brave '
@test "carriage return stops, without the word Windows"   # printf 'theme=nord\r\n' → status 1, output has "carriage return", not "Windows"
@test "a command in a value never runs"         # 'theme=$(touch '"$HOME"'/pwned)' → status 1, [ ! -e "$HOME/pwned" ]
@test "multi values are kept in table order"    # 'apps_browsers=firefox brave' → CHOICES[apps_browsers]="brave firefox"
@test "render puts keys in table order"         # load a shuffled full file, render == content of a canonical file
@test "save writes once, then leaves the file alone"  # save; record shasum + stat -f %m; sleep 1.1; save; both unchanged
@test "save creates the state folder"
@test "every fixture is valid and complete"     # for f in test/fixtures/*.env: choices_load ok, choices_missing empty
```

- [ ] **Step 2: Run it; it fails**

Run: `bats test/choices.bats`
Expected: FAIL, `lib/questions.sh` missing.

- [ ] **Step 3: Write `lib/paths.sh` additions, `lib/questions.sh` and `lib/choices.sh`**

`choices_load` reads with `while IFS= read -r line || [ -n "$line" ]` (keeps a last line without newline), checks `\r` before the line regex, splits on the first `=`, and for `multi` matches the value against `^([a-z0-9-]+( [a-z0-9-]+)*)?$` before checking each id. The header comment is the spec's: `# omamac's saved answers. omamac reads this file as data; it is never run.`

- [ ] **Step 4: Make `test/fixtures/bare.env` complete**

The header comment, `theme=tokyo-night`, every `multi` key empty, `wispr_flow desktops window_margins dock dock_autohide` all `no`, `docker=none`, in table order (so it renders byte-identical to itself).

- [ ] **Step 5: Run the tests and shellcheck**

Run: `bats test/ && shellcheck lib/*.sh`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/paths.sh lib/questions.sh lib/choices.sh test/choices.bats test/fixtures/bare.env
git commit -m "feat: add the question table and saved answers"
```

---

### Task 3: Asking, the summary and "Install?"

**Files:**
- Create: `lib/ask.sh`, `test/ask.bats`
- Modify: `test/helpers/fake-gum`, `test/helpers/common.bash`

**Interfaces:**
- Consumes: Task 2's table, `CHOICES`, `choices_missing`, `question_label`, `OMAMAC_TTY`; `lib/ui.sh`'s `ui_box`, `ui_info`, `ui_fail`.
- Produces, in `lib/ask.sh`:
  - `ask_missing` — for each key from `choices_missing`, asks it and sets `CHOICES[key]` (multi in table order). Before the first `apps_*` question it asks, prints one `ui_info` line: desktop apps, installed with Homebrew; picking none is fine.
  - `ask_summary` — `ui_box` with one line per key: `<QUESTION_TITLE>: <labels joined by ", ">`, `none` for an empty multi.
  - `ask_install` — `gum confirm --default=false "Install?"`; returns 0 on yes, 1 on no.
  - Any prompt exiting 130: `ui_fail "Stopped. Nothing was changed."`, `exit 130`. Any other non-zero (other than confirm's 1): `ui_fail` naming the question's title, return 1.
  - Calls: single `gum choose --header "<text>" --label-delimiter=: <options>`; multi adds `--no-limit`; yesno `gum confirm --default=false "<text>"`; all `< "$OMAMAC_TTY"`.
- Produces, in the test helpers:
  - `fake-gum choose|confirm` logs `gum <args…>` to `$STUB_LOG`; requires the first line of its stdin to be `fake-tty` (else prints `fake-gum: prompt not reading the tty` and exits 98); takes the next line of `$T_GUM_ANSWERS` (a position counter in `$T_GUM_ANSWERS.pos`). For `choose` the line is space-separated values, printed one per line (empty line → prints nothing); for `confirm`, `yes` → exit 0, `no` → exit 1. `exit <n>` → exits n. No line left → `fake-gum: no answer for prompt <n>`, exit 99.
  - `common.bash`: `setup_sandbox` writes `fake-tty` into `$BATS_TEST_TMPDIR/tty` and exports `OMAMAC_TEST_TTY` to it; `gum_answers <line>…` writes the queue and exports `T_GUM_ANSWERS`.

- [ ] **Step 1: Write `test/ask.bats` (failing)**

```bash
@test "fresh: all 16 asked in table order, nothing pre-selected"
  # gum_answers with one line per question + nothing for Install
  # run ask_missing; grep -c '^gum choose\|^gum confirm' STUB_LOG = 16
  # order of --header texts / confirm texts matches QUESTION_KEYS
  # ! grep -q -- '--selected' STUB_LOG ; every 'gum confirm' line has --default=false
@test "multi uses --no-limit, single does not"
@test "answers land in CHOICES, multi in table order"   # browsers answered "firefox brave" → "brave firefox"
@test "the app intro line shows once, only if an app group is asked"
@test "only missing keys are asked"                     # CHOICES pre-filled except docker → exactly 1 prompt, header "How should Docker run?"
@test "Ctrl-C at a question exits 130 with the stop message"   # answer 'exit 130'
@test "prompts read the tty"                            # OMAMAC_TEST_TTY pointing at an empty file → status 98 surfaces as failure
@test "summary shows labels and none"                   # Theme: Tokyo Night ; Browsers: Brave, Firefox ; Media: none ; Wispr Flow: no ; Docker: No Docker
@test "Install? yes returns 0, no returns 1, Ctrl-C exits 130"
```

- [ ] **Step 2: Run it; it fails**

Run: `bats test/ask.bats`
Expected: FAIL, `lib/ask.sh` missing.

- [ ] **Step 3: Extend `fake-gum` and `common.bash`, write `lib/ask.sh`**

Capture each prompt's exit with `out=$(gum … < "$OMAMAC_TTY") || status=$?` so the `ERR` trap never fires for a normal "no" or Ctrl-C.

- [ ] **Step 4: Run the tests and shellcheck**

Run: `bats test/ && git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`
Expected: all pass. `test/hygiene.bats`' "every bash 5 script parses" now covers `lib/ask.sh`.

- [ ] **Step 5: Commit**

```bash
git add lib/ask.sh test/ask.bats test/helpers/fake-gum test/helpers/common.bash
git commit -m "feat: ask the first-run questions and confirm"
```

---

### Task 4: `install.sh` asks first

**Files:**
- Modify: `install.sh`, `test/install.bats`

**Interfaces:**
- Consumes: `choices_load`, `choices_save`, `ask_missing`, `ask_summary`, `ask_install`, `OMAMAC_CHOICES_FILE`.
- Produces: `install_questions` runs first in `install_main`: load (on failure `exit 1`, the parser's message already shown), ask missing, summary, Install? (no → `ui_info "Stopped. Nothing else was changed. Run the one-liner again to start over."`, `exit 0`), then `OMAMAC_STEP='saving your answers'` and `choices_save`.

- [ ] **Step 1: Update and extend `test/install.bats` (failing)**

`setup` copies `test/fixtures/bare.env` to `$HOME/.local/state/omamac/choices.env` and queues `gum_answers yes`, so the existing tests run as a re-run with "Install?" answered. New tests:

```bash
@test "fresh: asks, saves, then writes the Phase 1 files"      # no choices.env; 16 answers + yes; choices.env == choices_render of those; zshrc exists
@test "re-run: no questions, summary, Install? asked once"      # STUB_LOG has exactly one 'gum confirm --default=false Install?' and no 'gum choose'
@test "re-run leaves choices.env byte-identical, same mtime"    # covered by "second run changes nothing" now that snapshot includes the state dir
@test "Install? no: exit 0, nothing written"                    # fresh; answers + no → status 0; no choices.env, no ~/.config/omamac/zshrc, no ~/.zshrc
@test "Ctrl-C at a question: exit 130, nothing written"
@test "broken choices.env: stops before any question"           # 'colour=red' → status 1, output has "line", no gum calls, file unchanged
@test "saving fails: stops naming it, no zsh file or lines"     # chmod 555 the state dir after removing choices.env; status 1; output has "saving your answers"
```

- [ ] **Step 2: Run it; the new tests fail**

Run: `bats test/install.bats`
Expected: new tests FAIL; the old ones may fail until Step 3.

- [ ] **Step 3: Wire `install_questions` into `install.sh`**

Source `lib/questions.sh`, `lib/choices.sh`, `lib/ask.sh`. Update the header comment to say the questions come first.

- [ ] **Step 4: Run the suite**

Run: `bats test/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh test/install.bats
git commit -m "feat: install.sh asks the questions before changing anything"
```

---

### Task 5: doctor checks the saved answers

**Files:**
- Modify: `lib/doctor.sh`, `bin/omamac`, `test/doctor.bats`

**Interfaces:**
- Consumes: `choices_load`, `choices_missing`, `OMAMAC_CHOICES_FILE`.
- Produces: `doctor_check_choices`, run last in `doctor_run`, with "Saved answers" as its name. `bin/omamac` sources `lib/questions.sh` and `lib/choices.sh`.

- [ ] **Step 1: Update `test/doctor.bats` (failing)**

`healthy_mac` copies `bare.env` into place; the healthy test expects 9 ✓ lines. New tests:

```bash
@test "saved answers missing"     # expect_fail "Saved answers" "run the one-liner"
@test "saved answers invalid"     # 'colour=red' → expect_fail "Saved answers" "delete that line"
@test "saved answers incomplete"  # drop the docker line → expect_fail "Saved answers" "it asks only that one"
@test "git status takes no lock"  # stub git 'echo "locks=${GIT_OPTIONAL_LOCKS:-unset}" >> "$STUB_LOG"; exec /usr/bin/git "$@"'
                                  # then the line after "git -C … status --porcelain" in STUB_LOG is "locks=0"
```

- [ ] **Step 2: Run it; it fails**

Run: `bats test/doctor.bats`
Expected: FAIL.

- [ ] **Step 3: Add `doctor_check_choices` and `GIT_OPTIONAL_LOCKS=0 git -C … status --porcelain`**

`choices_load`'s stderr message becomes the ✗ line's why and fix; keep one line per check.

- [ ] **Step 4: Run the suite**

Run: `bats test/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/doctor.sh bin/omamac test/doctor.bats
git commit -m "feat: doctor checks the saved answers"
```

---

### Task 6: Docs

**Files:**
- Modify: `README.md`, `CONTRIBUTING.md`

- [ ] **Step 1: README**

Per the spec's Docs section: the "still being built" line; Install gains the questions paragraph (x or Tab to pick, Enter to go on; nothing chosen for you; "no" stops and the next run asks again); What it changes: `~/.local/state/omamac`: logs and your saved answers. No mention of fixtures.

- [ ] **Step 2: CONTRIBUTING**

A short "Questions and fixtures" section: a question is one row in `lib/questions.sh` plus its value in every `test/fixtures/*.env`; the bats suite fails on an incomplete fixture, which would otherwise hang the VM run.

- [ ] **Step 3: Run the suite** (hygiene greps the docs)

Run: `bats test/`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add README.md CONTRIBUTING.md
git commit -m "docs: README explains the first-run questions"
```

---

### Task 7: Rebase, review, VM run, PR

- [ ] **Step 1:** Once Tuna has merged the gate PR: `git fetch origin && git rebase origin/main`. Expected: the gate commit drops out; `git diff origin/main --stat` shows no gate files.
- [ ] **Step 2:** Whole-branch review (superpowers:requesting-code-review) against the spec; fix what it finds, each fix its own commit, `bats test/` green.
- [ ] **Step 3:** `git push -u origin phase-2-first-run-questions && test/vm.sh phase-2-first-run-questions bare`. Expected: `✓ … passed`. The log shows the summary and "Install?" answered on both runs, and an identical fingerprint including `choices.env`.
- [ ] **Step 4:** Open the PR into `main`: what Phase 2 does, the calls from the spec, the VM result, and a "Left for later phases" list carrying forward Phase 1's open items plus any new ones.
