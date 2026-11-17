# Phase 2: first-run questions — design

Status: built · 2026-11-17 · Source of truth for the why: [`vision.md`](../../../vision.md)

## Intent

Phase 2 adds the conversation at the start of a run: omamac asks all its first-run questions before changing anything, shows one summary, asks "Install?", and saves the answers in `~/.local/state/omamac/choices.env`. A re-run finds the answers and skips the questions. Tests pre-fill that file from a fixture, the same path a re-run takes.

Nothing chosen is installed yet; Phases 3 to 6 act on the saved choices. This phase only asks, confirms and saves.

It is done when: answers are saved; re-runs skip them; nothing is pre-selected. Proven in the VM with the `bare` fixture (questions skipped, summary shown, "Install?" answered, second run changes nothing) and in bats for the question screens.

## Goals

- On a run with no saved choices, `install.sh` asks the ten question groups in the vision's order, then shows a summary and "Install?", before writing any file.
- On "yes", the answers are saved, then the Phase 1 steps run as before. On "no" or Ctrl-C, nothing more is written.
- A saved answer is never asked again. A question with no saved answer is asked, so a later phase that adds a question asks only that one.
- `choices.env` is read as data, never run as code, and a broken file stops the run with the line at fault and the fix.
- Enter alone never opts in to anything: yes/no questions default to No, multi-selects start empty, and Docker lists "No Docker" first. The theme question has no "none", so Enter there picks the highlighted theme, which installs nothing extra.
- `omamac doctor` reports whether the saved choices are present and valid.

## Non-goals (later phases)

- Installing or applying any choice: theme (4), apps and Wispr Flow (6), desktop and Dock settings (4, 6), languages and cloud CLIs (3), Docker (5).
- The "let Homebrew take it over?" adoption question. It needs the cask names and the Applications check, which come with the app catalog in Phase 6; it slots in right after each app group's question.
- `omamac install`. It reuses these questions but has nothing to install until Phase 3, so it keeps its "not available yet" message.
- doctor *offering* fixes as questions. The Phase 1 spec placed it here; it moves to the first phase with a fix worth offering (reinstall a removed package, Phase 3). Today every doctor fix is "run the one-liner again", and an offer in the VM's `omamac doctor` would wait on a question no one answers.
- Migrations and `~/.local/state/omamac/version`. No released install has old choices to migrate.
- An answers file for users. Fixtures stay a test mechanism, undocumented in the README.

## Anti-goals

Failure even if it technically works:

- Anything is selected before the user picks it, or Enter alone says yes to anything.
- A file is written, or anything installed, before "Install?" is answered yes.
- A re-run asks a question that already has a saved answer, or rewrites `choices.env` when nothing changed.
- `choices.env` is `source`d, so a crafted value runs code.
- Saying no traps the user: answers not yet saved are asked again on the next run. (Answers already saved stay saved on "no": changing one later is uninstalling one thing and installing another, as the vision settles; there is no "edit answers".)
- A prompt is cut off before the user sees what they're agreeing to.
- A question's text names keys that gum 2 doesn't use (gum 2 toggles with x or Tab, not Space, and draws its own key help).

## Constraints

- After `boot.sh`'s `exec`, `install.sh`'s stdin is the spent `curl` pipe. Every prompt reads `/dev/tty` explicitly (from the Phase 1 "left for later" list). `boot.sh` has already checked that `/dev/tty` is readable.
- gum 2.0.2 (Homebrew's current), verified on the dev Mac through `expect`:
  - `gum choose --label-delimiter=:` shows the label and prints the value, so options can be `Tokyo Night:tokyo-night`.
  - `gum choose --no-limit`: x or Tab toggles; Enter with nothing toggled prints nothing and exits 0. gum shows its own key-help line.
  - `gum confirm --default=false`: Enter means No (exit 1); `y` means yes (exit 0), `n` no (exit 1).
  - Ctrl-C exits 130 from both, printing nothing.
  - In a 0×0 terminal (expect's default) gum draws nothing at all. With a size set it draws, and draws a `confirm` prompt twice (first frame and a redraw).
  - gum cuts a prompt or header off at the terminal's edge rather than wrapping it (found in the whole-branch review). So every question text stays at most 76 characters, and any longer explanation is a help line printed before the prompt, where the terminal wraps it.
- `install.sh` runs under `set -Eeuo pipefail` with an `ERR` trap; a prompt's non-zero exit must be handled where it's called, not left to the trap.
- bash 5 from here on, so associative arrays are fine.
- Gate files (`test/vm.exp`, `test/fingerprint.sh`, …) change only in a PR whose purpose is the gate.

## Approaches

| Approach | Trade-off | Verdict |
| --- | --- | --- |
| **One question table in bash; gum `choose`/`confirm` read `/dev/tty`; `choices.env` parsed line by line into an associative array and checked against the table** | One place lists every question, its options and its key, so asking, summarising, validating and doctor all read the same table. Strict parsing keeps the file data. | **Chosen** |
| `source choices.env` like omawsl's saved choices | Shortest code, but a value like `$(…)` runs, and a typo is silently a new variable | Dropped (secure by default) |
| One file per question or per app now (the vision's "one small file per app") | The catalog files need cask names and permissions, which Phase 6 defines; making them now means guessing that format | Dropped for now: the app list lives in the table; Phase 6 moves it into per-app files and keeps the same ids |
| A plain `read -r` "Install? (y/n)" line instead of `gum confirm` | Prints once and needs no terminal size, so `expect` matches it trivially; but it's unstyled and needs Enter after the letter | Dropped: `vm.exp` can handle gum with a terminal size and a one-answer rule |

Tuna handed the how to Claude once the vision was agreed; this design is Claude's call throughout, within what `vision.md` settles.

## Design

### Two pull requests

1. **Gate PR (`gate-install-prompt`), first.** Teaches the VM loop to answer "Install?" and to fingerprint the saved choices. Its purpose is the gate, as the rule for gate files requires. On today's `main` nothing asks "Install?", so its own VM run with `bare` passes unchanged.
2. **Phase 2 PR (`phase-2-first-run-questions`).** Everything else. Built on top of the gate branch while that PR waits, rebased onto `main` once Tuna merges it, then VM-tested and opened.

### Gate PR changes

- **`test/vm.exp`**
  - Gives its terminal a size (`stty_init "rows 50 cols 120"`), so `ssh -t` forwards a real size and gum in the VM draws its screens.
  - On the first `Install?` it sends `y`. Further matches in the same run are redraws of that prompt and are ignored. (A second real "Install?" in one run would not be answered and hits the timeout; one run asks once.)
  - The `Install?` pattern comes before the generic `(y/n)` / `[y/N]` pattern, which still fails the run on any other prompt.
  - `test/vm_exp.bats` gets tests: a fake ssh that prints `Install?` twice and reads one key gets exactly one `y`; a fake ssh that asks `Continue? (y/n)` still fails.
- **`test/fingerprint.sh`** adds `shasum -a 256 ~/.local/state/omamac/choices.env`, so a second run that rewrites the saved choices fails the VM loop.
- **`test/vm.sh`**: only the step 3 comment changes ("where Phase 2 will read it" → "where install.sh reads it").

### The question table: `lib/questions.sh`

Each question has a key (its line in `choices.env`), a kind, its text (at most 76 characters), an optional help line printed before it, and for `single` and `multi` its options as `Label:value`. Order is the vision's: most visible to most technical.

| # | Key | Kind | Text (draft; final wording is the builder's, fewest plain words) | Options (value) |
| --- | --- | --- | --- | --- |
| 1 | `theme` | single | Pick a theme for the terminal, editor and prompt. *Help:* You can change it later with omamac theme. | Catppuccin (`catppuccin`), Dracula (`dracula`), Everforest (`everforest`), Gruvbox (`gruvbox`), Kanagawa (`kanagawa`), Matte Black (`matte-black`), Nord (`nord`), One Dark (`one-dark`), Osaka Jade (`osaka-jade`), Ristretto (`ristretto`), Rosé Pine (`rose-pine`), Solarized (`solarized`), Tokyo Night (`tokyo-night`) |
| 2 | `apps_browsers` | multi | Browsers | Brave (`brave`), Chrome (`chrome`), Firefox (`firefox`) |
| 3 | `apps_communication` | multi | Communication | WhatsApp (`whatsapp`), Telegram (`telegram`), Signal (`signal`), Discord (`discord`), Slack (`slack`), Zoom (`zoom`) |
| 4 | `apps_media` | multi | Media | Spotify (`spotify`), VLC (`vlc`) |
| 5 | `apps_screen_recording` | multi | Screen recording | Cap (`cap`) |
| 6 | `apps_storage` | multi | Storage and sync | Dropbox (`dropbox`), Google Drive (`google-drive`) |
| 7 | `apps_developer` | multi | Developer | VS Code (`vscode`) |
| 8 | `apps_productivity` | multi | Productivity | Raycast (`raycast`), Obsidian (`obsidian`) |
| 9 | `wispr_flow` | yesno | Install Wispr Flow for voice dictation? *Help:* Wispr Flow turns your speech into text in the cloud. | |
| 10 | `desktops` | yesno | Make desktops behave like workspaces? *Help:* Desktops keep their order, switching to an app goes to its desktop, and Reduce motion turns on, which shortens animations everywhere. | |
| 11 | `window_margins` | yesno | Add margins between tiled windows? | |
| 12 | `dock` | yesno | Clean up the Dock? *Help:* Apple's apps and Downloads leave the Dock (not your Mac), and the apps omamac installs take their place. | |
| 13 | `dock_autohide` | yesno | Hide the Dock when you're not using it? | |
| 14 | `languages` | multi | Programming languages | Ruby on Rails (`ruby`), Node.js (`node`), Go (`go`), PHP (`php`), Python (`python`), Elixir (`elixir`), Rust (`rust`), Java (`java`) |
| 15 | `cloud_clis` | multi | Cloud command-line tools | Azure CLI (`azure`), AWS CLI (`aws`), Google Cloud CLI (`gcloud`), GitHub CLI (`gh`), Terraform (`terraform`) |
| 16 | `docker` | single | How should Docker run? | No Docker (`none`), colima (`colima`), OrbStack (`orbstack`), Docker Desktop (`docker-desktop`) |

Before the first app group, one plain line says these are desktop apps installed with Homebrew and that picking none is fine.

Values are stable ids: later phases map them to formulas, casks and mise names, and Phase 6 keeps the app ids when it moves apps into catalog files. One key per app group (not one `apps` key) keeps every question one key, and joining the groups in table order gives the catalog order the Dock needs.

### Asking

- **single**: `gum choose --header "<text>" --label-delimiter=: <options…>`, no `--selected`. Enter picks the option under the cursor, which starts on the first, so a single question whose answer can be "nothing" lists that answer first (Docker). *(Claude's call, from the builder check.)*
- **multi**: the same with `--no-limit`. Nothing toggled is a valid answer: none.
- **yesno**: `gum confirm --default=false "<text>"`. Exit 0 → `yes`, exit 1 → `no`.
- Every call reads `< "$OMAMAC_TTY"` (`/dev/tty`, overridable by the existing `OMAMAC_TEST_TTY` seam). If that isn't readable, omamac stops before the first prompt: a failed redirect would make a yes/no prompt exit 1, which reads as "no".
- Exit 130 (Ctrl-C) from any prompt: print "Stopped. Nothing else was changed." and exit 130. Any other unexpected exit is an error with the question named.
- Only questions whose key is missing from the loaded choices are asked. Answers collect in memory; nothing is written yet.
- Questions are laid out with `lib/ui.sh` as gum styles them, consistent with Phase 1 output.

### Summary and "Install?"

- A `ui_box` with one line per question: a short label and the answer as labels, e.g. `Theme: Tokyo Night`, `Browsers: Brave, Firefox`, `Communication: none`, `Wispr Flow: no`, `Docker: colima`. Shown on every run, including re-runs where nothing was asked.
- Then `gum confirm --default=false "Install?"`, reading the tty.
  - yes → save choices (below), then the Phase 1 steps (zsh file, two lines, final summary).
  - no → "Stopped. Nothing else was changed." Exit 0: the user chose to stop; nothing failed. Nothing new is saved. If questions were asked in this run, the message adds "The next run asks those questions again."; answers saved by an earlier yes stay as they are.
  - 130 → as above, exit 130.

`install.sh`'s order becomes: load choices → ask missing → summary → Install? → save → Phase 1 steps. So nothing in `install.sh` writes before the yes.

### `choices.env`: `lib/choices.sh`

**Format.** UTF-8 text, one `key=value` per line, keys in table order, written by omamac:

```
# omamac's saved answers. omamac reads this file as data; it is never run.
theme=tokyo-night
apps_browsers=brave firefox
apps_communication=
…
wispr_flow=no
…
docker=none
```

- `single`: one value from the options. `multi`: zero or more values separated by one space, no duplicates; any order is read, and omamac writes them in table order. `yesno`: `yes` or `no`.
- An empty `multi` (`apps_media=`) means "answered: none". A missing key means "not asked yet".

**Reading** (`choices_load <file>`), never `source`:
- Missing file → no answers.
- Blank lines and lines starting with `#` are skipped.
- Every other line must match `^[a-z_]+=[a-z0-9 -]*$`, name a key in the table, appear once, and hold a valid value for its kind. Anything else stops the run before any question, naming the file, the line number and the problem, with the fix: "Delete that line, then run the one-liner again."
- Values are checked against the table, so a value can only ever be one of the ids above.

**Saving** (`choices_save <file>`): render every key in table order to a temp file in the same folder, then `mv` it into place only if it differs from the current file (`cmp -s`), as Phase 1 does for the zsh file. A second run with nothing new leaves the file and its mtime alone. Creates `~/.local/state/omamac` if missing.

### `omamac doctor`

One new check, "Saved answers", using `choices_load`:
- ✓ the file is valid and every question has an answer.
- ✗ missing: "omamac doesn't know your answers. Fix: run the one-liner".
- ✗ invalid: the parser's message and fix.
- ✗ incomplete: "a question has no answer yet. Fix: run the one-liner; it asks only that one".

Boy-scout fix while in the file: doctor's `git status` runs with `GIT_OPTIONAL_LOCKS=0`, so a read-only check never takes git's index lock (from the Phase 1 "left for later" list).

### Fixtures

`test/fixtures/bare.env` becomes a complete "nothing optional" answer set: `theme=tokyo-night` (a theme has no "none"), every `multi` empty, every `yesno` `no`, `docker=none`. It stays the fixture for this phase's VM run, since Phase 2 installs nothing.

A bats test loads every `test/fixtures/*.env` with `choices_load` and fails if any is invalid or incomplete. An incomplete fixture would make the VM wait on a question until `vm.exp` times out; this catches it in seconds instead.

### bats

`test/helpers/fake-gum` learns `choose` and `confirm`: it logs its arguments to `STUB_LOG`, reads the next answer from a queue file (`T_GUM_ANSWERS`: one line per prompt, e.g. `tokyo-night`, `brave firefox`, `exit 1`, `exit 130`), checks its stdin is `OMAMAC_TEST_TTY`, and prints or exits accordingly.

Tests (`test/questions.bats`, `test/choices.bats`, additions to `install.bats` and `doctor.bats`):
- Fresh run: all 16 prompts in table order; Docker's first option is `No Docker:none`; no prompt has `--selected`; every `confirm` has `--default=false`; answers saved in canonical form; Phase 1 files written after.
- Re-run with a full file: no question asked, the summary and "Install?" shown, `choices.env` byte-identical with the same mtime.
- Partial file: only the missing keys are asked; the saved ones are kept as they were.
- "Install?" no: exit 0, no `choices.env`, no zsh file, no added lines.
- Ctrl-C at a question and at "Install?": exit 130, nothing written.
- Parser: comment and blank lines; unknown key; duplicate key; bad value per kind; a duplicate multi value is rejected; multi values out of order are read and saved in table order; a `$(touch …)` value is rejected and nothing is created; Windows line endings rejected with a clear message.
- Summary: labels, "none" for empty multi.
- Every fixture is valid and complete.
- The existing never-touch test covers the new files as it is. The "no apt, Windows or WSL" test becomes case-sensitive for "Windows" (the OS's name), since "tiled windows" speaks of macOS windows; apt and WSL stay case-insensitive.
- Every question text is at most 76 characters, and every summary line fits an 80-column box with every option picked.

### Docs

- **README.md**
  - Top: "Today the one-liner installs Homebrew, bash, gum and the `omamac` command, and asks the first-run questions; it saves your answers but doesn't install your picks yet."
  - Install: "First it asks a few questions (theme, apps, macOS settings, languages, Docker), shows your answers and asks "Install?". Nothing is chosen for you: press x or Tab to pick, Enter to go on. After that it runs on its own." Plus: answering no stops the run; the next run asks again.
  - What it changes: `~/.local/state/omamac`: logs and your saved answers.
- **CONTRIBUTING.md:** fixtures must answer every question (the bats test checks); how to add a question (one row in the table, a value in every fixture).

### Vision updates in this change

None needed: the phase stays within the vision. Two calls are recorded here rather than in the vision's settled decisions, since they are the how: yes/no questions and "Install?" default to No, and the app list lives in the question table until Phase 6.

## Left to the builder

- Exact wording of the questions, the intro line, the summary labels and messages, within the vision and "fewest plain words".
- How the question table is laid out in bash, and the helper names.
- `vm.exp`'s exact patterns, after watching a real gum run in a VM.
