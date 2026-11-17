# Phase 3 gate and 3a: core tools — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The VM loop can run a fixture's steps and answer "Remove …?" (gate PR); then the one-liner installs the core tools, writes omamac's full zsh file, sets up LazyVim on a fresh Mac, and `omamac update` upgrades what omamac installed (3a).

**Architecture:** `lib/core.sh` holds the core formula list and installs what's missing. `config/zshrc` is the zsh file's text, copied to `~/.config/omamac/zshrc`. `lib/neovim.sh` clones LazyVim's starter when `~/.config/nvim` is absent. `lib/apply.sh` runs those steps for both `install.sh` and the new `update.sh`; `bin/omamac update` pulls the checkout and `exec`s `update.sh`, which applies, then upgrades by name.

**Tech Stack:** bash 5, zsh, Homebrew, gum 2, bats-core, shellcheck, expect, Tart.

**Spec:** `docs/superpowers/specs/2026-11-17-phase-3-shell-and-tools-design.md` (the why: `vision.md`). Read both before any task. 3b and 3c get their own plans after 3a merges.

## Global Constraints

- bash 5 (`#!/opt/homebrew/bin/bash`, or sourced by such a script) with `set -Eeuo pipefail`. `boot.sh` is not touched.
- Core formulas, exactly: `starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli`.
- Nothing writes or installs before "Install?" is answered yes. The one-liner never upgrades; only `omamac update` does, and only by name from omamac's lists (core, `bash`, `gum`).
- A user's own `~/.config/nvim` is never written. `update` never adds the `~/.zprofile` / `~/.zshrc` lines.
- omamac's own files are written compare-then-move, so a second run leaves them and their mtime alone.
- Users never see apt, Windows or WSL (`test/hygiene.bats`); it greps `config/` and `update.sh` too from Task 3 on.
- Gate files (`test/vm.exp`, `test/vm.sh`, `test/fingerprint.sh`, `test/image.sh`, `.github/workflows/bats.yml`, `.github/rulesets/main.json`) change only in Task 1's PR.
- Tests never touch the network: LazyVim's URL comes from `OMAMAC_TEST_LAZYVIM_URL` (a local repo in tests).
- Run tests as `(trap '' PIPE; bats test/)`; check the `1..N` count equals the `ok` count.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Review Focus

1. **A user's `~/.config/nvim` that is a symlink or a file** (dotfile managers): treated as "exists", never written through. Test in Task 4.
2. **A half-finished LazyVim clone** (network drops): no `~/.config/nvim` left, and no stray temp folder in `~/.config` after the failure. Test in Task 4.
3. **`omamac update` with local edits in the checkout**: stops before any change, naming `git status` as the fix; nothing upgraded. Test in Task 6.
4. **A core formula the user removed with `brew uninstall`**: the next one-liner reinstalls it, `update` installs it before upgrading, and doctor names it. Tests in Tasks 2, 6, 7.
5. **A shell where none of the tools exist** (Homebrew gone, or before the first install finishes): sourcing omamac's zshrc prints nothing and exits 0. Test in Task 3.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `test/vm.exp`, `test/vm_exp.bats`, `test/vm.sh`, `test/fingerprint.sh`, `test/fixtures/bare.steps.sh` | gate: `Remove …?` answers, `-lic`, steps step, fingerprint additions | 1 |
| `lib/core.sh`, `test/helpers/fake-brew`, `test/core.bats` | core list, `core_install`, `core_missing` | 2 |
| `config/zshrc`, `test/zshrc.bats`, `test/hygiene.bats` | omamac's zsh settings | 3 |
| `lib/neovim.sh`, `lib/paths.sh`, `test/neovim.bats` | LazyVim on a fresh Mac | 4 |
| `lib/apply.sh`, `install.sh`, `test/install.bats` | shared apply steps; install.sh uses them | 5 |
| `lib/log.sh`, `update.sh`, `bin/omamac`, `test/update.bats`, `test/omamac.bats` | `omamac update` | 6 |
| `lib/doctor.sh`, `test/doctor.bats` | core tools and neovim checks | 7 |
| `README.md`, `CONTRIBUTING.md`, `test/fixtures/bare.steps.sh` | docs; VM steps for 3a | 8 |
| — | review, VM run, PR, merge | 9 |

---

### Task 1: Gate PR — steps, "Remove …?" and a richer fingerprint

Branch `gate-phase-3` from `main`. Its own PR, merged before 3a's.

**Files:**
- Modify: `test/vm.exp`, `test/vm.sh`, `test/fingerprint.sh`
- Create: `test/fixtures/bare.steps.sh`
- Test: `test/vm_exp.bats`

**Interfaces:**
- Produces: `vm.exp` sends `y` once per distinct prompt text matching `Remove [^?]*\?` (and still once for `Install?`). `vm.sh` runs the one-liner in `zsh -lic`, and, when `test/fixtures/<fixture>.steps.sh` exists, a last step named `steps` that runs it in the VM with stdin from `/dev/null`, then `omamac doctor`. `fingerprint.sh` adds `tap:`, `mise:` and file-hash lines only for things that exist.

- [ ] **Step 1: Extend the fake ssh in `test/vm_exp.bats` and write the failing test**

The stub gains `T_REMOVE="<text>|<text>|…"`: for each text it prints it, then reads one key and prints `got:<key>`; at the end `read -r -t 2 -n1 extra && echo "extra:$extra"`.

```bash
@test "each Remove …? prompt is answered once" {
  T_REMOVE='Remove Go?|Remove Go?|Remove Rust?' vm_exp
  [ "$status" -eq 0 ]
  [ "$(grep -c '^got:y' <<< "$output")" -eq 2 ]
  [[ "$output" != *"extra:"* ]]
}
```

The stub's loop reads a key only after the first sighting of each distinct text, matching what gum does (a redraw is the same text, no new read).

- [ ] **Step 2: Run it; it fails**

Run: `bats test/vm_exp.bats`
Expected: the new test FAILS (`unexpected prompt` or timeout); the rest pass.

- [ ] **Step 3: Change `test/vm.exp`**

An array `removed`; a `-re {Remove [^?]*\?}` branch before the y/n pattern: take `$expect_out(0,string)`, and if it isn't in `removed`, add it and `send -- "y"`; `exp_continue`. Update the header comment ("answers omamac's "Install?" and each "Remove …?" once").

- [ ] **Step 4: Change `test/vm.sh`**

- `one_liner` uses `zsh -lic`. The comment says why: `.zshrc` loads as in a Terminal window.
- After the last doctor, a step 9:

```bash
# 9. The fixture's own steps (update, uninstall…), if it has any.
steps="test/fixtures/$fixture.steps.sh"
if [ -f "$steps" ]; then
  step=steps
  info "Running $steps"
  vm "set -o pipefail; f=\$(mktemp) && curl -fsSL $raw/$steps -o \$f && zsh -lic \"zsh -eux -o pipefail \$f </dev/null\""
  step='doctor after the steps'
  vm "zsh -lic 'omamac doctor'"
fi
```

- [ ] **Step 5: Change `test/fingerprint.sh`**

Inside the sorted block, each guarded so a missing tool or folder prints nothing and doesn't fail:
- `/opt/homebrew/bin/brew tap | sed 's/^/tap: /'`
- `[ ! -x /opt/homebrew/bin/mise ] || (cd ~ && /opt/homebrew/bin/mise ls --installed) | sed 's/^/mise: /'`
- for `~/.config/nvim` and `~/.config/mise/conf.d`: `[ ! -d "$d" ] || find "$d" -type f -exec shasum -a 256 {} +`

- [ ] **Step 6: Add `test/fixtures/bare.steps.sh`**

```zsh
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
omamac doctor
```

- [ ] **Step 7: Run the suite and shellcheck**

Run: `(trap '' PIPE; bats test/) && git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`
Expected: all pass, counts match, no shellcheck output.

- [ ] **Step 8: Commit, push, VM run, PR, merge**

```bash
git add test/vm.exp test/vm_exp.bats test/vm.sh test/fingerprint.sh test/fixtures/bare.steps.sh
git commit -m "test: VM loop runs fixture steps and answers Remove prompts"
git push -u origin gate-phase-3
test/vm.sh gate-phase-3 bare
```
Expected: `✓ gate-phase-3 (bare) passed`; the log shows step 9 ran `omamac doctor`. Open the PR "Gate: the VM loop runs fixture steps", body: what changed, why, that its purpose is the gate (name the gate files), and the VM result. Merge once `bats` and `vm` are green; tell Tuna it touched gate files.

---

### Task 2: The core formulas

Branch `phase-3a-core-tools` (holds the spec commit), rebased onto `main` after Task 1 merges.

**Files:**
- Create: `lib/core.sh`, `test/core.bats`
- Modify: `test/helpers/fake-brew`

**Interfaces:**
- Produces, in `lib/core.sh` (sourced after `lib/paths.sh`, `lib/ui.sh`):
  - `CORE_FORMULAS` — indexed array, the Global Constraints list in that order.
  - `core_missing` — prints the core formulas `brew list --formula <name>` reports missing, one per line, in list order.
  - `core_install` — if any are missing, `ui_run "Installing <names joined by ', '>" "$OMAMAC_BREW_PREFIX/bin/brew" install <missing…>`, then `ui_ok "Core tools are installed"`; nothing missing: only the `ui_ok`.
- Produces, in `fake-brew`: `install` takes any number of formulas and exits 1 when `T_BREW_FAIL=1`; `upgrade <names…>` only logs. Every call is logged as today. (Casks, taps and uninstall come with 3c.)

- [ ] **Step 1: Write `test/core.bats` (failing)**

```bash
@test "the core list is the spec's" {
  in_lib 'echo "${CORE_FORMULAS[*]}"'
  [ "$output" = "starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli" ]
}
@test "fresh: one brew install with every core formula"   # STUB_LOG has exactly one "brew install starship neovim … tree-sitter-cli"
@test "all present: no brew install at all"               # pre-install all; no "brew install" line after core_install
@test "one removed: installs only that one"               # remove Cellar/eza; log has "brew install eza" and nothing else installed
@test "a brew failure returns non-zero and shows the log" # fake-brew with T_BREW_FAIL=1 on install → status ≠ 0, output has "Log:"
```

`in_lib` sources `lib/paths.sh lib/ui.sh lib/core.sh` under `$BASH5`, as `test/choices.bats` does.

- [ ] **Step 2: Run it; it fails**

Run: `bats test/core.bats` — Expected: FAIL, `lib/core.sh` missing.

- [ ] **Step 3: Extend `fake-brew` (bash 3.2 safe) and write `lib/core.sh`**

`core_missing` collects with `mapfile` before printing (no early return mid-pipe; see `question_has`).

- [ ] **Step 4: Run the suite and shellcheck** — `(trap '' PIPE; bats test/)`, shellcheck as in Task 1. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core.sh test/core.bats test/helpers/fake-brew
git commit -m "feat: core formula list and installing what's missing"
```

---

### Task 3: omamac's zsh file

**Files:**
- Create: `config/zshrc`, `test/zshrc.bats`
- Modify: `test/hygiene.bats` (grep `config/` and `update.sh` too)

**Interfaces:**
- Produces: `config/zshrc`, the spec's seven parts in that order, starting with the two lines `install.sh` writes today (the comment line and the PATH line, unchanged). Every tool use is guarded with `(( $+commands[<tool>] ))`. Homebrew's prefix is `/opt/homebrew`.

- [ ] **Step 1: Write `test/zshrc.bats` (failing)**

Run zsh with `HOME` in the sandbox and `ZDOTDIR` unset, `zsh -f -i -c "source $REPO_ROOT/config/zshrc; <check>"`.

```bash
@test "zsh parses it"                          # zsh -n config/zshrc
@test "with no tools it prints nothing"        # PATH=/usr/bin:/bin; output empty, status 0
@test "PATH gets omamac's bin once"            # source twice; one .local/share/omamac/bin
@test "EDITOR is nvim when nvim exists"        # stub nvim in STUB_DIR → EDITOR=nvim, VISUAL=nvim; without it, unset
@test "aliases appear with their tools"        # stub eza bat zoxide lazygit; alias ls == "eza -lh --group-directories-first --icons=auto"; alias cat == "bat --paging=never"; alias lzg == lazygit
@test "history settings"                       # HISTSIZE=10000, SAVEHIST=20000, [[ -o hist_ignore_space ]]
@test "starship and mise init only when present"  # stubs print "starship init zsh" / "mise activate zsh" calls to STUB_LOG; both logged when present, starship last
@test "no zellij, apt names or multiplexer start"  # grep -E 'zellij|batcat|fdfind|herdr' config/zshrc finds nothing
```

The `zoxide` stub answers `init zsh` with a `z() { :; }` function; `starship init zsh` and `mise activate zsh` stubs print nothing.

- [ ] **Step 2: Run it; it fails** — `bats test/zshrc.bats`. Expected: FAIL, file missing.

- [ ] **Step 3: Write `config/zshrc`**

Content per the spec, aliases copied from `~/git-repos/omawsl/configs/bashrc` (`bat`, not `batcat`; `fd` needs no alias). Completion: `fpath=(/opt/homebrew/share/zsh/site-functions $fpath)`, `(( $+functions[compdef] )) || { autoload -Uz compinit && compinit; }`, `zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'`, `autoload -U up-line-or-beginning-search down-line-or-beginning-search`, `zle -N` both, `bindkey '^[[A'`/`'^[[B'` to them. fzf: `source <(fzf --zsh)`. Comments say *why* in a line, not what.

- [ ] **Step 4: Widen `test/hygiene.bats`**

Add `config` and `update.sh` to the searched paths, and `"$REPO_ROOT"/update.sh` to the bash 5 parse test (skipped while missing, as now).

- [ ] **Step 5: Run the suite and shellcheck** — Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add config/zshrc test/zshrc.bats test/hygiene.bats
git commit -m "feat: omamac's zsh file with omawsl's aliases and prompt"
```

---

### Task 4: LazyVim on a fresh Mac

**Files:**
- Create: `lib/neovim.sh`, `test/neovim.bats`
- Modify: `lib/paths.sh`, `test/helpers/common.bash`

**Interfaces:**
- Produces, in `lib/paths.sh`: `OMAMAC_NVIM_DIR=$HOME/.config/nvim`, `OMAMAC_NVIM_MARKER=$OMAMAC_NVIM_DIR/lua/plugins/omamac.lua`, `OMAMAC_LAZYVIM_URL=${OMAMAC_TEST_LAZYVIM_URL:-https://github.com/LazyVim/starter}`.
- Produces, in `lib/neovim.sh`: `neovim_setup` — if `$OMAMAC_NVIM_DIR` exists in any form (`-e` or `-L`): when the marker is missing, `ui_info "Your own neovim config is kept."`; return 0. Otherwise clone `--depth 1` into `mktemp -d "$HOME/.config/nvim.omamac.XXXXXX"`, remove its `.git`, write the marker (`-- Set up by omamac.` then `return {}`), `mv` it to `$OMAMAC_NVIM_DIR`, `ui_ok "neovim is set up with LazyVim"`. A failed clone removes the temp folder and returns non-zero. The clone runs under `ui_run`, with `GIT_TERMINAL_PROMPT=0`.

- [ ] **Step 1: Write `test/neovim.bats` (failing)**

`common.bash` gains `lazyvim_fixture`: a local git repo with `init.lua` and `lua/config/lazy.lua`, made once per test in `$BATS_TEST_TMPDIR`; `setup_sandbox` calls it and exports `OMAMAC_TEST_LAZYVIM_URL` as its `file://` URL (so `--depth` works). Every test then runs offline, `install.bats` included.

```bash
@test "fresh: clones the starter, drops .git, adds the marker"  # init.lua there; no .git; marker content exact
@test "existing folder: untouched, says so"                     # pre-made dir with a file; snapshot equal; output "Your own neovim config is kept."
@test "omamac's own folder: no message on a re-run"             # run twice; second output has no "kept"
@test "a symlink counts as the user's"                          # ln -s elsewhere ~/.config/nvim; target untouched; link still a link
@test "a failed clone leaves nothing"                           # URL to a missing repo → status ≠ 0; no ~/.config/nvim, no ~/.config/nvim.omamac.*
```

- [ ] **Step 2: Run it; it fails** — Expected: FAIL, `lib/neovim.sh` missing.
- [ ] **Step 3: Write `lib/paths.sh` additions and `lib/neovim.sh`**
- [ ] **Step 4: Run the suite and shellcheck** — Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/paths.sh lib/neovim.sh test/neovim.bats test/helpers/common.bash
git commit -m "feat: LazyVim on a fresh Mac, a user's own neovim config kept"
```

---

### Task 5: `lib/apply.sh` and `install.sh`

**Files:**
- Create: `lib/apply.sh`
- Modify: `install.sh`, `test/install.bats`

**Interfaces:**
- Consumes: `core_install` (Task 2), `config/zshrc` (Task 3), `neovim_setup` (Task 4).
- Produces, in `lib/apply.sh` (sourced after the libs above; uses the caller's `OMAMAC_STEP`):
  - `apply_zsh_file` — compare-then-move `$OMAMAC_CHECKOUT/config/zshrc` to `$OMAMAC_ZSH_FILE` (the current `install_zsh_file` logic, moved).
  - `apply_all` — sets `OMAMAC_STEP` before each: `apply_zsh_file`, `core_install`, `neovim_setup`.
- `install.sh` order: questions → `apply_all` → `install_lines` → summary. The summary box: `Installed: Homebrew, bash, gum, omamac and the core tools`, the log line, `Open a new terminal window, then run omamac.`

- [ ] **Step 1: Update `test/install.bats` (failing)**

- "fresh Mac: writes the zsh file and both lines": the zsh file equals `config/zshrc` byte for byte.
- New: `@test "installs the core and LazyVim after Install?"` — log has one `brew install starship …`; `~/.config/nvim/lua/plugins/omamac.lua` exists.
- New: `@test "Install? no: no brew install, no nvim"`.
- New: `@test "a re-run calls no brew upgrade"` — two runs; `grep -c '^brew upgrade' "$STUB_LOG"` is 0.
- "second run changes nothing" keeps passing with the new files (snapshot includes `~/.config/nvim`).
- New: `@test "never-touch: a user's nvim folder is left alone"` — pre-made folder, snapshot of it equal after.

- [ ] **Step 2: Run it; the new tests fail** — `bats test/install.bats`.
- [ ] **Step 3: Write `lib/apply.sh`; wire it into `install.sh`, delete `install_zsh_file`**
- [ ] **Step 4: Run the suite and shellcheck** — Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/apply.sh install.sh test/install.bats
git commit -m "feat: the one-liner installs the core tools and LazyVim"
```

---

### Task 6: `omamac update`

**Files:**
- Create: `lib/log.sh`, `update.sh`, `test/update.bats`
- Modify: `bin/omamac`, `test/omamac.bats`, `test/hygiene.bats` (none if Task 3 already added `update.sh`)

**Interfaces:**
- Consumes: `apply_all` (Task 5), `choices_load`, `ui_*`.
- Produces, in `lib/log.sh`: `log_start` — the same as `boot.sh`'s `boot_log_start` (new UTC-stamped file in `$OMAMAC_STATE_DIR/logs`, newest 10 kept), setting and exporting `OMAMAC_LOG`. bash 5; `boot.sh` keeps its own copy (it can't source `lib/`).
- Produces, in `bin/omamac`: `update` runs `omamac_update`: `git -C "$OMAMAC_HOME" pull --ff-only` with `GIT_TERMINAL_PROMPT=0`, output to a temp log; on failure prints `✗ omamac couldn't update its code. Fix: git -C ~/.local/share/omamac status, to see why.` and exits 1; on success `exec "$OMAMAC_BREW_PREFIX/bin/bash" "$OMAMAC_HOME/update.sh"`.
- Produces, `update.sh` (same header, bash-5 check and `ERR` trap pattern as `install.sh`): `log_start`; `choices_load` (missing file: `✗ omamac doesn't know your answers. Fix: run the one-liner.` exit 1); `apply_all`; `update_upgrade`; box `omamac and your tools are up to date.` + `Log: <path>`.
  - `update_upgrade` — the installed formulas among `CORE_FORMULAS bash gum` (checked with `brew list --formula`), then one `ui_run "Upgrading your tools" brew upgrade <them>`.
- `bin/omamac`'s usage and "not available yet" list lose `update`.

- [ ] **Step 1: Write `test/update.bats` (failing)**

`setup`: sandbox, fake brew with every core formula plus bash and gum, `bare.env` saved, a local origin repo whose `update.sh` is the real one plus `lib/`, `config/` (copy the tree with `git archive HEAD | tar -x` into a temp repo and commit), cloned to `$HOME/.local/share/omamac`.

```bash
@test "pulls, then runs the new update.sh"           # add a commit to origin that makes update.sh echo "new code"; output has "new code"
@test "local edits stop it before any change"        # edit a tracked file in the clone; status 1; output has "git -C ~/.local/share/omamac status"; no "brew upgrade" in STUB_LOG
@test "upgrades only omamac's formulas, by name"     # brew list also has "wget" (user's); the upgrade line names the 15 and not wget
@test "a removed core formula comes back first"      # remove Cellar/eza; "brew install eza" logged before "brew upgrade"
@test "writes no include line"                        # no ~/.zshrc, no ~/.zprofile before; none after
@test "a second update changes no file"               # snapshot (as install.bats) equal after the second run
@test "logs to a new file"                            # a new file in ~/.local/state/omamac/logs; output names it
@test "no saved answers: stops with the fix"          # rm choices.env; status 1; "run the one-liner"
```

In `test/omamac.bats`, "commands not built yet say so" drops `update`.

- [ ] **Step 2: Run them; they fail**
- [ ] **Step 3: Write `lib/log.sh`, `update.sh`, the `update` command**
- [ ] **Step 4: Run the suite and shellcheck** — Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/log.sh update.sh bin/omamac test/update.bats test/omamac.bats
git commit -m "feat: omamac update pulls and upgrades what omamac installed"
```

---

### Task 7: doctor checks the core and neovim

**Files:**
- Modify: `lib/doctor.sh`, `bin/omamac` (source `lib/core.sh`), `test/doctor.bats`

**Interfaces:**
- Consumes: `core_missing` (Task 2), `OMAMAC_NVIM_DIR`, `OMAMAC_NVIM_MARKER` (Task 4).
- Produces: `doctor_check_core` — ✓ `Core tools`; ✗ `Core tools — <names> missing, and omamac's shell and editor need them. Fix: brew install <names>`. `doctor_check_neovim` — ✓ `neovim config` when the marker exists; ℹ `neovim config — your own neovim config is kept` when the folder exists without it; ✗ when the folder is missing, fix `Run the one-liner again`. Both run in `doctor_run` after the zsh file check.

- [ ] **Step 1: Update `test/doctor.bats` (failing)** — `healthy_mac` adds every core formula and an omamac nvim folder with the marker. New tests: `core formula missing` (✗, fix names `brew install eza`), `user's own neovim config` (ℹ line, exit 0), `neovim config missing` (✗). "doctor is read-only" covers the new checks unchanged.
- [ ] **Step 2: Run it; it fails**
- [ ] **Step 3: Add the two checks**
- [ ] **Step 4: Run the suite and shellcheck** — Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/doctor.sh bin/omamac test/doctor.bats
git commit -m "feat: doctor checks the core tools and the neovim config"
```

---

### Task 8: Docs and the VM steps

**Files:**
- Modify: `README.md`, `CONTRIBUTING.md`, `test/fixtures/bare.steps.sh`

- [ ] **Step 1: README**
  - Top: the one-liner installs Homebrew, bash, gum, the `omamac` command, and the core tools (starship, neovim with LazyVim, btop, mise, herdr, eza, bat, zoxide, fzf, ripgrep, fd, lazygit, tree-sitter-cli); your other picks aren't installed yet.
  - After install: open a new terminal window; `nvim` downloads its plugins the first time it opens.
  - New "Keeping it up to date": `omamac update` updates omamac and what it installed, nothing else.
  - What it changes: the core formulas; `~/.config/nvim` with LazyVim's starter, only if you don't have one (yours is kept). Undo by hand: `brew uninstall` the core formulas, delete `~/.config/nvim` if omamac made it (it holds `lua/plugins/omamac.lua`).
- [ ] **Step 2: CONTRIBUTING** — a fixture may have `<name>.steps.sh`: commands run in the VM after the two runs, in `zsh -eux`, stdin closed; "Remove …?" prompts are answered y, any other prompt fails.
- [ ] **Step 3: `test/fixtures/bare.steps.sh`**

```zsh
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
omamac update
before=$(fp)
omamac update
after=$(fp)
[[ $before == "$after" ]]
nvim --headless +qa
[[ $(zsh -ic 'alias ls') == *eza* ]]
omamac doctor
```

- [ ] **Step 4: Run the suite** (hygiene greps the docs) — Expected: all pass.
- [ ] **Step 5: Commit**

```bash
git add README.md CONTRIBUTING.md test/fixtures/bare.steps.sh
git commit -m "docs: core tools, omamac update, and fixture steps"
```

---

### Task 9: Review, VM run, PR, merge

- [ ] **Step 1:** `git fetch origin && git rebase origin/main` (after the gate PR merged). Expected: `git diff origin/main --stat` shows no gate files.
- [ ] **Step 2:** Whole-branch review (superpowers:requesting-code-review) against the spec; each fix its own commit; `(trap '' PIPE; bats test/)` green with matching counts.
- [ ] **Step 3:** `git push -u origin phase-3a-core-tools && test/vm.sh phase-3a-core-tools bare`. Expected: `✓ … passed`; the log shows the core installed once, an identical fingerprint after the second run, and step 9's two updates with equal fingerprints.
- [ ] **Step 4:** Open the PR "Phase 3a: core tools and omamac update": what it does, the spec's calls, the VM result, and a "Left for later phases" list carrying Phase 2's open items (minus the `-lic` one, done) plus new ones. Merge once `bats` and `vm` are green; post the result comment.
