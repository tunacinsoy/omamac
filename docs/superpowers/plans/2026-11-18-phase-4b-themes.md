# Phase 4b: themes — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The theme saved in `choices.env` reaches Ghostty, herdr, starship, btop and neovim from the first run. `omamac theme [<id>]` switches all five, and a running Ghostty, herdr and btop reload. Doctor reports user configs that themes can't reach, and offers to move a user's `~/.config/nvim` aside.

**Architecture:** `themes/<id>/` holds each theme's four files, copied from omawsl (Ghostty's converted once from omawsl's terminal palette). `lib/theme.sh` renders every theme-dependent file into `~/.config/omamac/` in one function, `theme_apply`, called by `apply_all` and by `omamac theme`. `config/zshrc` points starship and btop at omamac's files when the user has none. `lib/neovim.sh` gains the single writer of `omamac.lua`.

**Tech Stack:** bash 5, zsh, Ghostty 1.4.0, herdr 0.9.5, starship, btop 1.4.8, LazyVim, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-18-phase-4-ghostty-themes-desktop-design.md`, sections "Constraints", "Approaches", "Themes (4b)", "Fixtures and VM runs" and "bats" (the why: `vision.md`). Read both before any task. Source content: `~/git-repos/omawsl/themes/` (read-only).

## Global Constraints

- **Hard rule for every implementer and reviewer:**
  - never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats;
  - never source `.bats` files outside bats;
  - never run Ghostty's binary, `herdr`, `btop` or `nvim` against the real `$HOME`;
  - never `pkill` anything on this Mac outside bats' stubs.
- omamac never runs Ghostty's binary (hygiene test from 4a).
- Theme ids, in question order: `catppuccin dracula everforest gruvbox kanagawa matte-black nord one-dark osaka-jade ristretto rose-pine solarized tokyo-night`.
- herdr theme map: the same name for `catppuccin dracula gruvbox kanagawa nord one-dark solarized tokyo-night`; `rose-pine` → `rose-pine-dawn`; `everforest matte-black osaka-jade ristretto` → `terminal`.
- New paths in `lib/paths.sh`:
  - `OMAMAC_STARSHIP_FILE=$OMAMAC_CONFIG_DIR/starship.toml`, `OMAMAC_STARSHIP_USER_FILE=$HOME/.config/starship.toml`
  - `OMAMAC_BTOP_FILE=$OMAMAC_CONFIG_DIR/btop.conf`, `OMAMAC_BTOP_THEMES=$OMAMAC_CONFIG_DIR/btop-themes`, `OMAMAC_BTOP_USER_FILE=$HOME/.config/btop/btop.conf`
  - `OMAMAC_NEOVIM_THEME_FILE=$OMAMAC_CONFIG_DIR/neovim.lua`
- omamac's files are written compare-then-move (`apply_put`). A second run, update or same-theme switch changes no file and no mtime.
- Never written: `~/.config/starship.toml`, `~/.config/btop/btop.conf`, a user's `~/.config/nvim` (except the rename doctor asks about).
- Gate files are not changed. Tests never touch the network, a real Ghostty, herdr, btop or nvim.
- Run tests as `(trap '' PIPE; bats test/)`, which takes about 4 minutes, so run it in the background or with a long timeout. The `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`, plus `zsh -n` on zsh files, steps files included.
- Users never see apt, Windows or WSL; `test/hygiene.bats` greps `themes/` too.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **First run with a theme other than Tokyo Night:**
   - every file, `omamac.lua` and `neovim.lua` included, holds the chosen theme;
   - a second run changes nothing (the 4a final review found a variant of this).
   - Test in Task 2.
2. **A switch that failed halfway** (one file not writable): a rerun of `omamac theme <same>` finishes it. Test in Task 3.
3. **The user's own starship or btop config, or their own `STARSHIP_CONFIG`:** zsh doesn't point the tool at omamac's file, doctor says ℹ, and their file is never written. Tests in Tasks 2 and 3.
4. **Nothing running:** the switch's reloads fail quietly and the switch still exits 0. Test in Task 3.
5. **Doctor's move-aside where the backup name is taken, or the clone fails:** nothing is lost, the backup is named, and omamac's marker isn't written over the user's folder. Test in Task 3.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `themes/<id>/{ghostty.conf,btop.theme,neovim.lua,starship.toml}`, `themes/LICENSE.omarchy` | theme content | 1 |
| `test/themes.bats`, `test/hygiene.bats` | theme files are complete and clean | 1 |
| `lib/theme.sh` | `theme_herdr_name`, `theme_apply` | 2 |
| `lib/herdr.sh`, `config/herdr.toml` | the theme placeholder | 2 |
| `lib/ghostty.sh` | render appends the theme's colours | 2 |
| `lib/neovim.sh` | `neovim_marker_write` | 2 |
| `lib/apply.sh`, `lib/paths.sh`, `config/zshrc`, sourcing in `install.sh`, `update.sh`, `bin/omamac` | wiring and the zsh rules | 2 |
| `bin/omamac`, `lib/doctor.sh` | `omamac theme`, reloads, doctor ℹ/✗, the move-aside offer | 3 |
| `install.sh`, `test/fixtures/bare.steps.sh`, `README.md`, `CONTRIBUTING.md` | summary, VM steps, docs | 4 |

### Task 1: The theme files

**Files:** Create `themes/<id>/` × 13 and `themes/LICENSE.omarchy`, and `test/themes.bats`. Modify `test/hygiene.bats` (add `themes` to the grep's paths).

- [ ] **Step 1: Write the failing tests** in `test/themes.bats`:
  - `"one folder per theme answer"`: `themes/*/` names equal `question_values theme`, sorted.
  - `"each theme has its four files"`: `ghostty.conf btop.theme neovim.lua starship.toml` are all non-empty.
  - `"ghostty.conf is 20 colour lines"`: each file has exactly these keys once each: `background`, `foreground`, `cursor-color`, `selection-background`, and `palette = 0=` … `palette = 15=`. Every value matches `#[0-9a-fA-F]{6}`. Comment lines (`#` first) are allowed.
  - `"starship palette names its theme"`: each `starship.toml` has `palette = "<x>"` and a `[palettes.<x>]` table with the same `<x>`.
  - `"licence comes along"`: `themes/LICENSE.omarchy` exists.
- [ ] **Step 2:** Run them; they fail.
- [ ] **Step 3: Copy and convert.** For each id:
  - Copy `btop.theme` and `neovim.lua` from `~/git-repos/omawsl/themes/<id>/` byte for byte.
  - Copy `starship.toml`, replacing its comment lines 3–8 (the "omawsl theme integration" block) with:
    ```
    # The prompt keeps starship's own modules; only the named colours they use
    # come from this theme's palette.
    ```
  - Write `ghostty.conf` from `windows-terminal-scheme.json` with `jq`:
    - first line `# <name from the JSON>, from omawsl's palette.`;
    - then `background`, `foreground`, `cursor-color` (from `cursorColor`) and `selection-background` (from `selectionBackground`);
    - then `palette = 0..15=`, in the order black, red, green, yellow, blue, purple, cyan, white, then the bright ones.

  Values keep the JSON's case. Copy `themes/LICENSE.omarchy`. The conversion is done once; no script is committed.
- [ ] **Step 4:** All bats pass (hygiene included); commit `feat: the 13 themes, copied from omawsl`.

### Task 2: One function writes every theme file

**Files:** Create `lib/theme.sh`, `test/theme.bats`. Modify `lib/paths.sh`, `lib/herdr.sh`, `config/herdr.toml`, `lib/ghostty.sh`, `lib/neovim.sh`, `lib/apply.sh`, `config/zshrc`, `install.sh`, `update.sh`, `bin/omamac` (source `lib/theme.sh`), `test/zshrc.bats`, `test/herdr.bats`, `test/ghostty.bats`, `test/neovim.bats`.

**Interfaces:**
- Consumes: `CHOICES[theme]`, `apply_put`, `herdr_render`, `ghostty_render`.
- Produces:
  - `theme_herdr_name <id>`: prints herdr's name per the map.
  - `theme_apply`: writes the six outputs of the spec's table from `CHOICES[theme]`. It replaces the separate `herdr_config_apply` and `ghostty_config_apply` steps in `apply_all`, keeping their `ui_step`/`ui_ok` lines or one "Theme files are in place" line. It also calls `neovim_marker_write` when `$OMAMAC_NVIM_MARKER` exists.
  - `neovim_marker_write`: writes the spec's `omamac.lua` text exactly, compare-then-move. `neovim_setup` calls it in place of its `printf`.
  - `herdr_render <out>` fills `@OMAMAC_HERDR_THEME@` too.
  - `ghostty_render <out>` appends `themes/<id>/ghostty.conf`.
- `config/herdr.toml`'s `name = "tokyo-night"` becomes `name = "@OMAMAC_HERDR_THEME@"`.
- `config/zshrc` additions, beside the herdr block:

  ```zsh
  # starship and btop can't include another file either: same rule as herdr.
  if (( ! ${+STARSHIP_CONFIG} )) && [[ ! -e ~/.config/starship.toml && ! -L ~/.config/starship.toml ]]; then
    export STARSHIP_CONFIG=~/.config/omamac/starship.toml
  fi
  if (( $+commands[btop] )) && [[ ! -e ~/.config/btop/btop.conf && ! -L ~/.config/btop/btop.conf ]]; then
    alias btop='btop -c ~/.config/omamac/btop.conf --themes-dir ~/.config/omamac/btop-themes'
  fi
  ```

- [ ] **Step 1: Write the failing tests** (`test/theme.bats` unless named):
  - `"herdr names"`: the map for all 13 ids.
  - `"apply writes the six files for the chosen theme"`: with `theme=dracula`:
    - `ghostty.conf` ends with Dracula's `background = …` line and still has `command = direct:`;
    - `herdr.toml` has `name = "dracula"`;
    - `starship.toml` equals `themes/dracula/starship.toml`;
    - `btop.conf` is `color_theme = "dracula"`;
    - `btop-themes/` holds only `dracula.theme`;
    - `neovim.lua` equals Dracula's.
  - `"rose-pine: herdr gets rose-pine-dawn; ristretto: terminal"`.
  - `"switching removes the old btop theme file"`.
  - `"second apply changes nothing"`: mtimes of all six are unchanged.
  - `"first run with Catppuccin: marker and theme in place, second run changes nothing"`: `neovim_setup`, then `apply_all`'s theme step, twice. `omamac.lua` holds the spec's text, and `neovim.lua` is Catppuccin's. Review Focus 1.
  - `"Phase 3's marker is upgraded"`: an `omamac.lua` holding `return {}` is rewritten. A user folder without the marker gets nothing written.
  - `test/zshrc.bats`:
    - `"STARSHIP_CONFIG is omamac's when the user has none"`.
    - `"own starship.toml, own STARSHIP_CONFIG: left alone"`.
    - `"btop alias only without the user's btop.conf"` (btop stubbed on PATH).
    - `zsh -n` still passes.
- [ ] **Step 2:** Run the focused files; they fail.
- [ ] **Step 3:** Implement per Interfaces. `OMAMAC_STEP` names each file it writes. Existing herdr, ghostty and neovim tests that pinned the old text are updated, not deleted.
- [ ] **Step 4:** All bats pass; shellcheck and `zsh -n config/zshrc` clean. Commit `feat: one step writes every theme file`.

### Task 3: `omamac theme`, reloads and doctor

**Files:** Modify `bin/omamac`, `lib/theme.sh`, `lib/doctor.sh`. Test: `test/omamac.bats` (or a new `test/theme_cmd.bats`), `test/doctor.bats`.

**Interfaces:**
- Produces: `theme_run [<id>]` in `lib/theme.sh`; `theme_reload` (the three reloads, each `|| true`, output to the log); doctor's `doctor_check_theme_files`, `doctor_check_starship`, `doctor_check_btop`; `doctor_offer` handles the neovim move-aside offer after the gone-choices offers.
- `bin/omamac theme` runs `trap omamac_failed ERR`, `OMAMAC_CMD=theme`, `omamac_choices` and `theme_run "${@:2}"`. More than one argument prints the usage and exits 2.

- [ ] **Step 1: Write the failing tests:**
  - `"theme dracula: saved, applied, reloaded, summary"`:
    - `choices.env` has `theme=dracula`, and the files hold Dracula;
    - the stub log has `pkill -USR2 -x ghostty`, `herdr server reload-config` and `pkill -USR2 -x btop`;
    - the output has `Theme: Dracula.`;
    - status 0.
  - `"nothing running: still exit 0"`: `pkill` and `herdr` stubs exit 1. Review Focus 4.
  - `"no id asks; picking one applies it"`: gum answers `nord`.
  - `"unknown id"`: `omamac theme bogus` exits 2 and lists the 13 ids.
  - `"same theme again changes nothing"`: mtimes unchanged; it still exits 0.
  - `"same theme again puts back a missing file"`: delete `starship.toml`, rerun, and it's back. Review Focus 2.
  - `"a failed write names the step"`: `~/.config/omamac` read-only, then the output has "omamac stopped while" and "omamac theme again". Restore permissions in teardown.
  - doctor:
    - `"own starship config is info"` and `"own btop config is info"`.
    - `"a missing theme file is a fail"`, with fix `omamac update`.
    - `"own nvim: info says themes don't reach neovim"`.
    - `"move-aside offered with a terminal, not without"`.
    - `"move aside renames and sets up"`: answer "Move it aside", then `~/.config/nvim.bak-<today>` holds the user's files and `~/.config/nvim` has omamac's marker.
    - `"move aside when the backup name is taken"`: the name gets `-<HHMMSS>`.
    - `"move aside, clone fails"`: `OMAMAC_TEST_LAZYVIM_URL` points at a missing repo. The backup holds the user's files, no `~/.config/nvim` exists, and the output names the backup and says to run the one-liner again. Review Focus 5.
- [ ] **Step 2:** Run them; they fail.
- [ ] **Step 3:** Implement. The no-id prompt is `ask_choose "Which theme?"` with the question's options, using `ask_need_tty` like `remove_run`. The move-aside offer uses `ask_choose` with `"Leave it:leave" "Move it aside:move"`; the rename is one `mv`.
- [ ] **Step 4:** All bats pass; shellcheck clean. Commit `feat: omamac theme switches everything; doctor covers themes`.

### Task 4: Summary, VM steps and docs

**Files:** Modify `install.sh`, `test/install.bats`, `test/fixtures/bare.steps.sh`, `README.md`, `CONTRIBUTING.md`.

- [ ] **Step 1:** The summary's Ghostty settings line becomes three settings: its colours, `command` (starts herdr) and `macos-option-as-alt`. Update `test/install.bats`. Every box line stays within 80 columns.
- [ ] **Step 2:** `bare.steps.sh`, after 4a's Ghostty and herdr checks, with them still running:
  1. Each id runs `omamac theme <id>`, then `nvim --headless "+Lazy! sync" +qa` must exit 0 with no `Error detected|E5108` (as the existing check does). Then `nvim --headless -c 'lua io.write(tostring(vim.g.colors_name))' -c qa` prints a name. Store the expected names in the steps file, one per id, as a zsh associative array. Each comes from that theme's `neovim.lua` (`colorscheme = "…"`, or the `colorscheme` call for ristretto).
  2. For one dark theme, Dracula: the Ghostty `+show-config --no-pager` `background` line equals the one in `themes/dracula/ghostty.conf`, and `herdr config check` passes in `zsh -ic`.
  3. After the loop, `pgrep -x ghostty` and `pgrep -f 'herdr server'` still find processes.
  4. Last: `omamac theme tokyo-night`, fingerprint, `omamac theme tokyo-night`, fingerprint, compare (the `fp` helper is already in the file).

  Match strings in the shell (`[[ … ]]`), never with `| grep -q`, and run `zsh -n` and shellcheck on the file.
- [ ] **Step 3: Docs.**
  - README:
    - The top paragraph says themes work and names `omamac theme`.
    - "What it changes" lists the theme files in `~/.config/omamac/`, the `STARSHIP_CONFIG` and btop alias rules, and that a user's own `~/.config/starship.toml` or `~/.config/btop/btop.conf` is kept and themes then don't reach that tool.
    - A btop note: settings saved from btop's menu go into omamac's file and don't last, and running `/opt/homebrew/bin/btop` without the alias makes btop write its own config.
    - `omamac theme [<theme>]` gets one line with the 13 ids.
    - The herdr note loses "(and, later, every theme switch)".
    - neovim: `omamac doctor` offers to move your own config aside.
  - CONTRIBUTING: where the themes come from (omawsl, MIT via Omarchy), and how `ghostty.conf` was converted.
- [ ] **Step 4:** All bats pass; shellcheck and `zsh -n` clean. Commit `feat: the summary, README and VM cover themes`.
- [ ] **Step 5 (controller):** whole-branch review, then merge `main` and push. Run `test/vm.sh phase-4b-themes bare` from a clean worktree of the pushed head, then open the PR.
