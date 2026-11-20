# Phase 7: docs, the full run and v1 — design

Status: draft · 2026-11-20 · Source of truth for the why: [`vision.md`](../../../vision.md)

## Intent

Phase 7 makes omamac ready for a stranger, proves every option in one VM run, hands the Mac to Tuna for Gate B, and tags v1 once Gate B passes.

It is done when Gate B has passed, every issue Gate B raised is fixed or moved past v1 by Tuna, and `v1.0.0` is tagged with a GitHub release.

## Goals

- The items parked in earlier phases' "Left for later phases" lists are each settled: fixed, filed as an issue for after v1, put on the Gate B checklist, or closed because they no longer hold.
- The README reads as a finished product for a stranger with a new Mac: what omamac is, what to do before, the one-liner, the clicks after, and how to keep it up to date and undo it. Every manual step is in it. It says how long the run takes, from a measured run.
- One VM run installs every option at once (`full`), and the `colima` fixture runs on the same commit, so every answer has been installed together on one head.
- Gate B has one GitHub issue with a checklist: the steps from the vision and the "to check by living with it" items.
- After Gate B, `v1.0.0` is a tag on `main` with a GitHub release whose notes are short: what v1 does, the known gap, the link to the README.

## Non-goals

- New features or options. The v1 scope stays as the vision describes it.
- Refactors of working code (the duplicated install/uninstall/doctor lookups from 3c). Filed for after v1: v1's code is proven as it is.
- Removing omamac itself (the known v1 gap, in the Backlog).
- Running Gate B. Tuna does it on the real Mac; omamac still never runs on the development Mac before then.
- Pointing the one-liner or `omamac update` at the tag. Both keep following `main`, as the vision says; the tag marks the release.

## Anti-goals

- A fix that changes behaviour the vision settled, without Tuna.
- A gate file changed to turn a red check green.
- Docs that describe what the code doesn't do.
- The tag before Gate B passes.

## Constraints

- bash 5 after `boot.sh`; `set -Eeuo pipefail` with the `ERR` trap. Prompts read `$OMAMAC_TTY`; nothing is pre-selected.
- Gate files change only in a PR about the gate.
- Tart runs at most two macOS VMs at once, so `full` and `colima` can run side by side.
- `vm.exp`'s timer restarts only when a prompt it answers shows up, so after Homebrew's password prompt (the first step after "Install?") the rest of a first run must finish within 2700 s. `OMAMAC_VM_TIMEOUT`, set in the environment of `test/vm.sh`, overrides it. Earlier VM runs took 2.5 to 35 minutes; `full` installs far more, so the plan measures it.
- `vm.exp` caps password prompts per call: the first run allows 2 + the fixture's `.brew-passwords`, and all of `steps.sh` runs as one call allowing 1 + the same number (`test/vm.sh:124`, `:163`).
- `test/vm.sh` posts one `vm` status per commit, so with two runs on one commit the last to finish wins.
- `test/fingerprint.sh` needs the checkout and Homebrew, so it can't run in a `before.sh`.
- 13 of the 18 apps have never been installed or uninstalled in a VM; one may turn out to need the password. A `password=yes` fix to its catalog file lands in 7b.
- Facts checked on 2026-11-20 against `main` at 6d04933:
  - `test/vm.sh` names a VM `omamac-test-<sha7>-<stamp>`, so two runs of one commit started in the same second collide.
  - The README's top says "omamac is still being built", and "Install" says "Allow about 10 minutes".
  - `lib/ask.sh` already stops on any gum exit other than 0, 1 and 130 (`ask_broken`), so Phase 2's "a gum error on a yes/no reads as no" no longer holds.
  - Nothing unsets `GUM_*` variables. gum reads settings such as `GUM_CHOOSE_SELECTED` from the environment, so a user's own could pre-select options.
  - The README never mentions git identity, SSH keys or GitHub login, though the vision says it covers them (settled 2026-11-16).
  - Three parked items no longer hold: a doctor render failure now reads ✗ (`herdr_render` left doctor in f5709cc), every `run ! grep` targets a log that always exists, and the README names Ctrl g `,` once.

## Approaches

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| What to do with the parked items | One pass in 7a. Fix an item when a user can hit it and it shows a wrong message, fails silently, or breaks "nothing pre-selected", and when a test can't fail. Everything else becomes a GitHub issue labelled `after-v1`, or a Gate B checklist line | The reliability bar for v1 is "no silent failure, no wrong advice". Below that bar they block v1; above it, they wait, and an issue keeps them out of PR comments. Dropped: fixing everything (refactors carry risk into Gate B); fixing nothing (silent failures stay). |
| "Every option" in one run | A `full` fixture: every app, Wispr Flow, the four macOS settings, every language and cloud CLI, a theme other than the default, Docker Desktop. The `colima` fixture runs on the same commit | Docker is a single choice, so one run can't hold both. Docker Desktop goes in `full` because it shares the password step with Zoom and Google Drive, the most involved path. `colima` already proves a container runs. |
| What `full`'s steps check | Everything chosen is present, doctor passes, the Dock holds omamac's apps in order, `omamac theme` switches, update twice changes nothing; then every pick is uninstalled, and the Mac's settings and Dock are back; a second uninstall changes nothing | The vision's "done when" lines for Phases 3 to 6, together, on one Mac. |
| Where Gate B is tracked | One GitHub issue, "Gate B", with a checklist | Tuna ticks items on the real Mac and opens an issue for each thing that feels off. Dropped: a checklist file in the repo (it would need a PR for every tick). |
| What "release" is | A `v1.0.0` tag on `main` and a GitHub release, after Gate B | The vision has the one-liner and update follow `main`. Dropped: a `--version` command or a version file (no one needs them yet). |
| The README's length | Short sections first (before, install, after, update, themes, herdr); the long lists (files, settings, uninstall details) last, under their own headings | A stranger reads the top and skims the rest. All of it stays in one file, as the vision says the README holds the manual steps. |
| Splitting the work | A gate PR, 7a (the parked items), 7b (docs and the full run), Gate B, then one PR per Gate B issue and the tag | Small steps; the full run lands on the commit whose docs it measures. |

All rows are Claude's calls within the vision.

## Pull requests

1. **Gate PR (`gate-phase-7`).** `test/vm.sh` puts the fixture name in the VM name. `test/vm.exp` stops with a clear message when `OMAMAC_VM_MAX_PASSWORDS` or `OMAMAC_VM_TIMEOUT` isn't a whole number. A fixture may have `<fixture>.steps-passwords`, the cap for its steps, apart from `.brew-passwords`, so `full` can uninstall several password apps without loosening the first run's "asks once" check. `test/vm.sh` doesn't post success over a `vm` failure already on the commit, so a pass of one fixture can't hide another's fail; a re-run after a fix needs a new commit. The ruleset gets `require_extra_approval_for_unattributed_changes` only if GitHub's rulesets API accepts it; otherwise the item is closed as not applying. VM fixture: `bare`.
2. **7a (`phase-7a-parked`).** The pass over the parked lists (PR #8, #10, #11, #12, #16, #18 and #20's "Left for later phases"). This spec and its plan ride along. Known fixes, each checked against the code first:
   - `omamac` unsets every `GUM_*` variable before it asks anything.
   - Messages that name the wrong next step: `omamac install`'s failure says "run omamac update" when nothing was saved; `omamac uninstall herdr` without `choices.env`; the gum-failure line on `install` and `uninstall` says "Run the one-liner again"; doctor's Reinstall of one app ends with "Your apps are installed".
   - A regular file at `~/.local/share/omamac` gives network advice (`boot.sh`'s clone fails); it should say to move it away, as for a folder.
   - doctor's "Homebrew no longer has Docker Desktop" when only the app is gone (PR #16), if it still reads that way.
   - The test sandbox doesn't unset `STARSHIP_CONFIG`.

   The PR description lists every parked item with its outcome. VM fixtures: `bare` and one per area the fixes touch.
3. **7b (`phase-7b-docs`).** The README and CONTRIBUTING pass, the `full` fixture, and the run time measured on it. VM runs on its head: `full` and `colima`. On merge, the Gate B issue is opened.
4. **Gate B.** Tuna. Each thing that feels off is an issue.
5. **Fixes from Gate B.** One PR each, with its own fixture. A gate-file change goes first in its own PR.
6. **v1.** When the Gate B issue is closed: tag `v1.0.0` on `main`, publish the release, and update the vision's status line.

Each branches from `main` after the one before it merges.

## Design

### The `full` fixture

`test/fixtures/full.env`: `theme=catppuccin`; every app id in its group; `wispr_flow=yes`; `desktops`, `window_margins`, `dock`, `dock_autohide` all `yes`; every language; every cloud CLI; `docker=docker-desktop`.

`full.brew-passwords`: `1` (the install's shared step asks once for Zoom, Google Drive and Docker Desktop). `full.steps-passwords`: the Homebrew prompts the steps make (each password app's uninstall asks once).

`full.before.sh` saves, inside the VM, the Dock's two arrays and the macOS settings keys `fingerprint.sh` lists, read with `defaults` and `plutil` as `dock.before.sh` does.

`full.steps.sh`, in order:

1. Every app is in Applications and Homebrew lists every cask; every language is in `mise ls`; every cloud CLI's command is on the PATH; `docker` is a link into Docker Desktop (checked with `readlink`, never run: a binary in an app bundle can wait on macOS's first-open check).
2. The Dock's `persistent-apps` holds no Apple app and lists omamac's apps in order: Ghostty, the catalog apps in catalog order, Docker Desktop.
3. The theme files name catppuccin. `omamac theme dracula` rewrites them, and they name dracula.
4. `omamac doctor` passes. `omamac update` twice, with fingerprints compared.
5. Every pick is uninstalled through `omamac uninstall`: the apps, Wispr Flow, Docker Desktop, the languages, the cloud CLIs, `dock`, `dock-autohide`, `desktops`, `window-margins`. After each, its cask, tool or setting is gone or back, and its answer is dropped.
6. The Dock's arrays and the macOS settings match what `full.before.sh` saved.
7. A second `omamac uninstall` of one app changes nothing; `omamac doctor` passes.

The builder keeps the order that needs the fewest password prompts and the shortest run, and sets `OMAMAC_VM_TIMEOUT` only if a step goes quiet for longer than 2700 s.

### The README

- **Top:** what omamac is in two sentences, then what it installs, as a short list. "still being built" goes.
- **Before you begin:** as today, plus "Back up first if this Mac has anything on it."
- **Install:** the one-liner, the password, the questions, the second Homebrew prompt, and the measured time ("Allow about N minutes" from the `full` and `bare` runs, as a range).
- **After install:** every manual click, each one line, as today, plus one short item: omamac doesn't set up git identity, SSH keys or GitHub login, with the three commands that do (`git config --global user.name/user.email`, `ssh-keygen -t ed25519`, `gh auth login` if they chose the GitHub CLI).
- **Keeping it up to date, Themes, herdr:** as today, shortened where it repeats.
- **Uninstalling:** its own section, out of "What it changes": the ids, the data question, the settings, the Dock, Docker, and the known gap with the undo-by-hand steps.
- **What it changes:** the file and settings list, last.
- Fixes on the way: Ctrl g `,` named once.

### CONTRIBUTING

The full run before a release: `test/vm.sh <branch> full` and `test/vm.sh <branch> colima`, side by side, and how to raise the timeout (`OMAMAC_VM_TIMEOUT`) if `full` needs it.

### The Gate B issue

Title "Gate B". Body: the vision's steps (back up, erase, Setup Assistant, README only, the one-liner, a day of work), then the checklist from PR #20's "Gate B, to check by living with it" and any 7a adds, then "Open an issue for anything that feels off or any step the README missed."

### The release

Tag `v1.0.0` on `main`'s head after the last Gate B fix merges. Release notes: three lines on what v1 does, the known gap (omamac can't remove itself), the README link.

## Testing

- **bats:** every 7a fix has a test that fails without it. `GUM_*`: a test sets `GUM_CHOOSE_SELECTED` and checks the fake gum sees no `GUM_` variable. CI runs the suite; the `1..N` count and the `ok` count match.
- **VM:** the gate PR on `bare`; 7a on `bare` and the touched areas; 7b on `full` and `colima`.
- **Docs:** a bats check that the README lists every app id in `apps/` and every theme in `themes/`, if one doesn't exist already.

## Vision updates in this change

None. When v1 is tagged, the vision's status line says so.

## Left to the builder

- Exact wording of messages and README sentences.
- Which theme `full` starts with and switches to.
- The order of `full`'s uninstalls.
