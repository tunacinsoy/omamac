# omamac configure, and menus for every command: design

Status: draft · 2026-11-24 · Issue [#60](https://github.com/tunacinsoy/omamac/issues/60) · Release 0.2.0 · The why: [`vision.md`](../../../vision.md) (Decisions log, 2026-11-24)

## Intent

The first run does two jobs: it **installs** software and **configures** macOS. After that, every change went through `install` or `uninstall`, so turning a setting on or off meant "installing" or "uninstalling" it. A bare `omamac install` also walked through every question again, starting at the apps, to reach the one section the user wanted.

What a user remembers is `omamac` and whether they want to install, remove or change something. Each command asks the next question, so no name has to be remembered. Named forms stay as shortcuts.

Tuna's calls (2026-11-24, #60):

- Settings leave `install` and `uninstall` entirely. Those two handle software only.
- A new `omamac configure` handles the five macOS settings.
- It ships as 0.2.0. The release breaks commands that worked in 0.1.0 and adds a new one.

## Commands

### `omamac` with no arguments

In a terminal (stdout is one, gum is there and the terminal can be opened), it asks:

```
What do you want to do?
  Install something        → omamac install
  Remove something         → omamac uninstall
  Change a macOS setting   → omamac configure
  Switch the theme         → omamac theme
  Update everything        → omamac update
  Check everything         → omamac doctor
```

The pick runs that command as if it had been typed (`exec` of `bin/omamac <command>`), so its errors, exit codes and "run omamac X again" lines are the command's own. Esc or Ctrl-C stops, as at every pick list. Anywhere else (piped, in bats without the terminal look), it prints the usage text and exits 0, as now. `omamac help` always prints the usage text.

### `omamac install`

| Form | Asks |
| --- | --- |
| `omamac install` | "What do you want to install?" with the sections that still have something to add: Apps, Languages, Cloud CLIs, Coding agents, Docker (only while the answer is No Docker). Then that section's question. |
| `omamac install <section>…` | Unchanged, except there is no `macos` section. |
| `omamac install <name>…` | Unchanged, except setting names are not install names. |

- Choosing **Apps** asks "Which apps?" with the app groups that still have an app to add, plus Wispr Flow while it's no. Then only that group's question. `omamac install apps` still asks every group, as before.
- With nothing left anywhere: "You've picked everything omamac offers here." exit 0, no menu (as now).
- After the section's question, everything is as now: adopt questions, the summary, Homebrew's password note, "Install?", save, apply.
- `omamac install macos`, or a setting name (`desktops`, `window-margins`, `desktop-widgets`, `dock`, `dock-autohide`): stops before asking anything. It prints `dock-autohide is a macOS setting: run omamac configure dock-autohide` (for `macos`: `The macOS settings moved: run omamac configure`) and exits 2.

### `omamac uninstall`

| Form | Asks |
| --- | --- |
| `omamac uninstall` | "What do you want to remove?" with the sections that have something omamac installed: Apps, Languages, Cloud CLIs, Coding agents, Docker. Then that section's list, with Nothing first, as today's list. With one section only, its list comes straight away. |
| `omamac uninstall <name>` | Unchanged for software. A setting name stops with the same line and exit 2 as under `install`. |

The setting rows leave the list, and the "It can remove" list no longer names settings.

### `omamac configure` (new)

| Form | Does |
| --- | --- |
| `omamac configure` | "What do you want to change?" One row per setting with its current state: `Desktops as workspaces (on)`, `Window margins (off)`, `Desktop widgets (off)`, `Dock cleanup (on)`, `Dock auto-hide (off)`. Then as `configure <setting>`. |
| `omamac configure <setting>` | A box with what changes, then "Turn on Dock auto-hide?" or "Turn off Dock auto-hide?". A no changes nothing. |
| `omamac configure <setting> on\|off` | No question. Already in that state: `Dock auto-hide is already on.` exit 0. |

The setting names are `desktops`, `window-margins`, `desktop-widgets`, `dock` and `dock-autohide`: the question keys with dashes, the same names `install` and `uninstall` took in 0.1.0.

**Turning on** sets the answer to yes and saves it first, then applies only that setting (`settings_apply` given that one answer; for `dock` it runs the Dock cleanup too). Saving first matches install, so a failure is finished by `omamac update`, and the stop line says so. On success: `✓ Dock auto-hide is on`.

**Turning off** is today's `remove_setting` / `remove_dock`: put the earlier values back, then save the answer as no last, so a failure leaves it yes for a rerun. Its box says what goes back, as today's Removes box does. For `dock`: your Dock goes back to how it was before omamac cleaned it, and changes since are undone. On success: `✓ Dock auto-hide is off`.

- A setting with no saved answer (a question added after the first run) counts as off. A no at its question saves no, so update stops naming it.
- Unknown name: `omamac doesn't know 'x'. Settings: desktops, window-margins, desktop-widgets, dock, dock-autohide.` exit 2. A software name (`go`, `vlc`): `go isn't a setting: run omamac install go or omamac uninstall go.` exit 2.
- A third word other than `on` or `off`, or more words: usage, exit 2.
- It needs saved answers like the other commands (`omamac_choices`).
- Only `configure` with no setting needs the terminal before the question. `on` and `off` work without one, so the VM's steps can run them with no prompt.

### Where omamac points to a command

- `add_command` (update's "a question was added" line, doctor's fix line for a missing answer) gives `omamac configure <setting>` for the five settings. Doctor keeps one command per setting: `configure` takes one name.
- `dock_put_back`'s damaged-record fix: `delete that file, then run omamac configure dock off again`.
- The usage text adds `configure` and says each command asks when given no name.

## Approach

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| Old setting names under install/uninstall | A pointer line and exit 2, no alias | Tuna: install is only for installing. An alias would keep two ways to do one thing. Exit 2 is what every unknown name already gets. |
| `on`/`off` | Asks nothing | The word is the answer, as `omamac theme nord` is. It also keeps `test/vm.exp`, a gate file, unchanged: the VM steps use `on`/`off`, and bats covers the questions. |
| Turning on | Applies that one setting, not `apply_all` | Nothing else needs to run: no Homebrew, no configs. `settings_apply` takes an optional list of answers, defaulting to all five, so update and the first run keep calling it as before. |
| Code | A new `lib/configure.sh`. `remove_setting` and `remove_dock` move there as the off half, with the question optional. A new `lib/menu.sh` holds the top-level menu. `add_run` and `remove_run` get their section menus. | Settings code in one place. `remove.sh` becomes software only, which matches the command. |
| Theme in `configure` | Left out | `omamac theme` already exists and is in the top-level menu. |
| An "Everything you skipped" item in the install menu | Left out | That walk-through is what #60 is about. `omamac install apps languages …` still asks several sections in one go. |

## Docs

- New `docs/commands.md`: a "You want to… / Run / Or, if you know the name" table (`omamac` first, for "not sure"), then every name each command takes, grouped as the menus are. Each setting gets one line and a link to its section in `what-it-changes.md`.
- README: the daily-commands table opens with "Type `omamac` and it asks what you want." It gains a `omamac configure` row and links to `docs/commands.md`.
- `docs/updating.md`: the install section is software only, and a configure section is added. `docs/uninstalling.md`: the macOS settings part points to configure.
- `vision.md`: the commands list, the "no edit answers command" settled decision (settings now change with `configure`, software still by uninstall and install), and a Decisions log line.
- CONTRIBUTING: no rule changes. The fixture rule for macOS settings and the Dock stays.

## Tests

bats, tests first:

- `omamac` with no arguments: the menu in the terminal look, with each pick running its command (checked through the stub log); the usage text outside it.
- install: the section menu (only sections with something left, Docker only at none), the Apps group menu, Wispr Flow in it, nothing left, `macos` and each setting name refused with exit 2 and nothing asked.
- uninstall: the section menu, one section going straight to its list, no setting rows, setting names refused.
- configure: the menu with states; on and off by question (yes and no); `on` and `off` with no question; already on, already off; the unanswered setting (no saves no); `dock` off putting the Dock back; `dock` on running the cleanup; unknown name; software name; a bad third word; failure while turning on says `omamac update`.
- `add_command` and doctor's fix line for a missing setting answer.
- Existing tests that use `install`/`uninstall` for settings move to `configure`.

VM (no gate file changes): `desktop.steps.sh`, `dock.steps.sh` and `full.steps.sh` use `omamac configure <setting> off` where they used `uninstall`. Running it again must change nothing. `desktop.steps.sh` also turns `window-margins` back on with `configure … on`, checks the key, and turns it off again. Runs: `bare`, `desktop`, `dock`, `full`.

## Release

After the PR merges: tag `v0.2.0` on `main` and publish a GitHub release. Its notes start with what moved (`omamac install|uninstall <setting>` → `omamac configure <setting> [on|off]`), then the menus. Then close #60.

## Done when

- Every bullet under Tests is green in bats. `bare`, `desktop`, `dock` and `full` pass in the VM.
- Docs and vision say it.
- `v0.2.0` is tagged and released.
