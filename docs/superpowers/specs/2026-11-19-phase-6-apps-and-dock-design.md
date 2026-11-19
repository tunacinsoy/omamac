# Phase 6: desktop apps, adoption and the Dock — design

Status: draft · 2026-11-19 · Source of truth for the why: [`vision.md`](../../../vision.md)

## Intent

Phase 6 installs the desktop apps the user picked at the first run, Wispr Flow included. A catalog app the user installed by hand is offered to Homebrew. Uninstalling an app asks whether its settings and data go too. On opt-in, the Dock holds the apps omamac installed instead of Apple's, and it can hide itself.

It is done when apps install, update and uninstall cleanly in the VM, including ones already there by hand or through Homebrew, and when the Dock holds the installed apps and uninstall restores the old Dock.

## Goals

- Every app picked in the seven app groups, and Wispr Flow on yes, is installed as a Homebrew cask. An app Homebrew already has is taken on as it is.
- Each app is one small file in `apps/`: its cask, its app name, and the permissions it asks for. The run's summary and the README's "After install" are built from those files.
- The apps that need the password to install (Zoom, Google Drive) and Docker Desktop's cask share one Homebrew step, right after "Install?". Homebrew asks once for all of them. The summary before "Install?" says so.
- `omamac install` asks again the app groups and Wispr Flow, with only the apps not picked yet.
- `omamac update` upgrades a chosen app only when Homebrew lists it as outdated, and only when the terminal has App Management. No `--greedy`.
- `omamac uninstall <app>` asks "Also remove its settings and data?" (Enter alone is no), shows what goes, asks "Remove …?", then runs `brew uninstall --cask`, with `--zap` on yes. `omamac uninstall docker-desktop` asks the same.
- A catalog app found in Applications but not in Homebrew is offered to Homebrew as soon as it is picked: "Let Homebrew take over Spotify?". On yes, `brew install --cask --adopt`. On no, it leaves the picks. A hand-installed Ghostty or Docker Desktop stays as today (used, never updated); doctor shows the command that hands Ghostty over.
- On `dock=yes`: Apple's apps and the Downloads stack leave the Dock, the user's own items stay, omamac's apps are added after them, and suggested and recent apps are turned off. The earlier Dock is saved first; `omamac uninstall dock` puts it back.
- On `dock_autohide=yes`: the Dock hides. `omamac uninstall dock-autohide` puts the earlier value back.
- `omamac doctor` reports a chosen app that is gone (✗, with Reinstall offered), one installed by hand (ℹ, with the adopt command), and Dock settings that drifted (✗).

## Non-goals (later phases)

- Apps outside the catalog. omamac never scans Applications for other hand-installed apps.
- The full VM run of every app (Phase 7). Each PR's fixture installs a few apps.
- Moving apps to desktops. It stays a README step.
- Removing a Docker Desktop that was installed by hand. It stays, as in 5b.
- Adopting Ghostty or Docker Desktop. The vision offers adoption for catalog apps, at the moment they are picked; Ghostty is never picked, and a "no" for either could not be saved, so every run would ask again. Adopting Docker Desktop is also unprobed (its own `docker` links in `/usr/local`).
- colima's data. `omamac uninstall colima` keeps `~/.colima` as in 5a; the data question is for apps.

## Anti-goals

- omamac bypasses Homebrew's sudo reset (`HOMEBREW_SUDO_CHECKED`, `SUDO_ASKPASS`) or stores the password.
- omamac overwrites an app the user installed by hand: no `brew install --cask --force`, and no `--adopt` for an app whose cask runs an installer package (it would reinstall the app over the user's copy).
- `--zap` without the user's yes.
- A re-run puts back an app the user took out of the Dock, or adds Apple's apps back.
- omamac uninstalls an Apple app, or a cask the user installed with Homebrew outside omamac.
- A sudo prompt hidden under a spinner.
- A second run, update or uninstall changes anything.

## Constraints

- bash 5 after `boot.sh`; `set -Eeuo pipefail` with the `ERR` trap. Prompts read `$OMAMAC_TTY`; nothing is pre-selected.
- Gate files change only in a PR about the gate.
- Facts checked on 2026-11-19 (Homebrew's cask data, Homebrew's source, and a probe VM on macOS 27.2 after main's one-liner with the `bare` fixture):
  - **Casks:** `brave-browser`, `google-chrome`, `firefox`, `whatsapp`, `telegram`, `signal`, `discord`, `slack`, `zoom`, `spotify`, `vlc`, `cap`, `dropbox`, `google-drive`, `visual-studio-code`, `raycast`, `obsidian`, `wispr-flow`. Every one has `auto_updates`. None is deprecated or disabled. Brave, Chrome, Signal, Spotify, Discord, Cap, Wispr Flow and Obsidian need macOS 12 or 13 or later; Raycast is arm64 only.
  - **Installs:** 16 casks installed one by one over SSH in 8 to 24 s each, with no prompt (Chrome's first try failed on a dropped download, and the retry passed). `zoom` and `google-drive` run an installer package, so Homebrew asked for the password once each. Installed in one `brew install --cask zoom google-drive`, Homebrew asked once for both. No app stayed open after its install: Zoom's package opens Zoom, and Homebrew closes it. Zoom's package leaves `zoom.us.app` owned by root, so a write into it fails with "Permission denied" (VM run 1 of 6a's apps fixture).
  - **Extras:** `google-drive` also puts Google Docs, Sheets and Slides in Applications; `visual-studio-code` links `code`, `obsidian` links `obsidian`, `vlc` and `firefox` link a command into `$OMAMAC_BREW_PREFIX/bin`. `dropbox` prints a caveat about a kernel extension.
  - **Uninstalls:** `brew uninstall --cask` asked for the password for `discord`, `dropbox`, `zoom` and `google-drive` (launchd services, packages, files under `/Library`), not for `vlc`. `--zap` on `vlc` moved its `~/Library` files to the Trash and asked nothing. `--zap` on `google-drive` couldn't remove its login item (System Events wanted Automation access), warned and exited 0.
  - **Adoption:** with `auto_updates`, `--adopt` checks no version and doesn't write into the app: Homebrew deletes its own download and records the cask (`cask/artifact/moved.rb`). In the VM, a hand-installed VLC (the same version), Signal (an older one), Discord (a newer one) and Ghostty were each adopted with exit 0, the app's inode unchanged, and `brew list --cask` listing them. `zoom` "adopted" ran its installer package again (password, the app replaced).
  - **The password:** Homebrew resets sudo the first time a command needs it and asks itself (`Library/Homebrew/utils/sudo.sh`, "Reset sudo timestamp to avoid running unauthorised sudo commands"). The reset happens once per `brew` command.
  - **The Dock:** in the VM the Dock runs (the GUI session is logged in). A fresh `persistent-apps` holds 18 Apple apps, every one under `file:///System/` (Safari under `/System/Volumes/Preboot/Cryptexes/`). `persistent-others` holds `file:///Users/admin/Downloads/`. `show-recents` and `autohide` are absent. `defaults export com.apple.dock`, `plutil -remove` and `-insert … -append` on the copy, `defaults import` and `killall Dock` left exactly Ghostty and VLC, no Downloads, `show-recents` 0; the Dock filled in each new tile's bundle id and bookmark itself. `plutil -convert json` fails on this plist (it holds data and dates), so the code reads it with `plutil -extract … raw`.
  - **Outdated:** right after installing, `brew outdated --cask` and `brew outdated --cask --greedy` list nothing.
  - **Second probe (6a's plan):** `brew install --cask google-drive docker-desktop` asked for the password once for both. `brew uninstall --cask google-drive` also took Google Docs, Sheets and Slides out of Applications, asked once, and warned that it couldn't remove its login item (System Events needs Automation access), exit 0. `brew uninstall --zap --cask docker-desktop` over SSH asked once, moved `~/.docker` and Docker's `~/Library` folders to the Trash, removed its links in `/usr/local`, exit 0.

## Approaches

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| Zoom and Google Drive need the password | Kept. They and Docker Desktop's cask share one `brew install --cask …` right after "Install?"; the summary before "Install?" says Homebrew will ask once more | Tuna, 2026-11-19: they are in high demand, and one early prompt keeps the rest of the run unattended. Dropped: bypassing Homebrew's reset (it switches off a check Homebrew added on purpose, through an internal variable); dropping both apps. |
| Upgrading apps | Like Ghostty: only when `brew outdated --cask` lists the app, App Management checked first, no `--greedy` | Tuna, 2026-11-19. Every catalog app updates itself; `--greedy` would download apps again that already updated, and quit them while open. `--greedy` stays for the cloud CLI casks. |
| A catalog file | `apps/<id>`, `key=value` lines read as data: `cask`, `app`, `password` (`yes` when installing asks), `allow` (one permission line, may repeat) | The vision: one small file per app, with its permissions. The id, label, group and order stay in `lib/questions.sh`, where the questions already are. Dropped: one table for all apps (the vision asks for a file each); sourcing the files (read as data, like `choices.env`). |
| Adopting | `brew install --cask --adopt` for a catalog cask without an installer package; asked as each app is picked, before "Install?" | Homebrew leaves the app in place. Installer-package apps (Zoom, Google Drive) are told: "Zoom is already installed, not through Homebrew. Homebrew can only take it over by installing it again, so omamac leaves it." and leave the picks. |
| App Management for adopting | Not checked | `--adopt` doesn't write into the app (Homebrew's source, above). Upgrade and uninstall still check, as today. |
| App Management for installer-package apps | Not checked on upgrade or uninstall | Their app is root-owned, so the write test can't reach it, and Homebrew changes it with sudo through the package. Docker Desktop's app is the user's, so it is still checked. |
| "Nothing pre-selected" for the data question | A yes/no, "Also remove VLC's settings and data?", Enter alone is no | omamac's yes/no questions all work this way, and the vision's own "(y/n)" questions too. The safer answer is what Enter gives, and "Remove VLC?" confirms either way. |
| Password prompts on uninstall | Every app uninstall runs in the open (`ui_run_open`), after "Homebrew may ask for your password." | Homebrew asks for some casks and not others (launchd services, packages, files under `/Library`), and that changes with each cask's version. A spinner would hide the prompt. |
| How the Dock is changed | `defaults export` to a copy, `plutil` edits, one `defaults import`, one `killall Dock` | One write, no new formula, probed in the VM. Dropped: `dockutil` (a formula omamac would own, many writes). |
| Which Dock items are Apple's | An app whose URL starts with `file:///System/`, or whose bundle id is one of the apps Apple preinstalls in `/Applications` on a new Mac: `com.apple.iWork.Keynote`, `com.apple.iWork.Numbers`, `com.apple.iWork.Pages`, `com.apple.iMovieApp`, `com.apple.garageband10` | macOS's own apps live on the system volume; the five are the ones a new Mac adds to `/Applications` (the VM image has none, so Gate B checks them). Anything else the user pinned stays. |
| The Downloads stack | The `persistent-others` item whose URL is the user's Downloads folder | The vision names it. Other folders the user added stay. |
| omamac's apps in the Dock, in order | Ghostty, the catalog apps in catalog order, then Docker Desktop | Ghostty is the app every omamac user opens first. Each is added only if it is in Applications and not already in the Dock. |
| When the Dock is cleaned | Once: when `dock=yes` and the record `~/.local/state/omamac/dock-before.plist` doesn't exist | A re-run never undoes the user's own Dock changes. |
| Adding apps later | `~/.local/state/omamac/dock-added` lists every app omamac has put in the Dock or found there. Each run adds every omamac app that is in Applications and not in that list, then adds it to the list | An app installed later (`omamac install`, a re-run, doctor's Reinstall, a password-step app) reaches the Dock, a run that failed before the Dock step catches up next time, and a tile the user removed is never put back. |
| Suggested and recent apps, auto-hide | Settings keys in `lib/settings.sh`: `com.apple.dock show-recents boolean false` (under `dock`) and `com.apple.dock autohide boolean true` (under `dock_autohide`) | The existing record, put-back, doctor and update cover them. |
| Splitting the work | A gate PR, then 6a (apps), 6b (adoption), 6c (the Dock) | Small steps, each proven in the VM on its own. |

The first two rows are Tuna's; the rest are Claude's calls within the vision.

## Pull requests

1. **Gate PR (`gate-phase-6`).** The VM loop learns what Phase 6 needs:
   - `test/fingerprint.sh` lists Applications and the Dock;
   - `test/vm.exp` answers "Let Homebrew take over …?" and "Also remove …'s settings and data?";
   - `test/vm.sh` runs a fixture's `before.sh` before the one-liner.
2. **6a (`phase-6a-apps`).** The catalog files, the app installs with the shared password step, `omamac install`, update, `omamac uninstall <app>` with the data question (Docker Desktop too), doctor and the summary lines. This spec, its plan and the vision update ride along. VM fixtures: `apps` (new) and `bare`.
3. **6b (`phase-6b-adoption`).** The adoption question at the first run and in `omamac install`, for catalog apps; doctor's ℹ lines with the adopt command. VM fixture: `adopt` (new, with `before.sh`).
4. **6c (`phase-6c-dock`).** Dock cleanup, Dock auto-hide, the Dock in `omamac install`, uninstall and doctor. VM fixture: `dock` (new, with `before.sh`).

Each branches from `main` after the one before it merges.

## Design

### Gate PR

- **`test/fingerprint.sh`** adds:
  - one `application: <name>` line per entry in `/Applications`;
  - the Dock: `dock-app <nn>: <url>` and `dock-other <nn>: <url>`, numbered so `sort` keeps the order. These come from `defaults read com.apple.dock persistent-apps` (and `persistent-others`), `_CFURLString` only: the Dock rewrites its own bookmarks and GUIDs.
  - `com.apple.dock show-recents` and `com.apple.dock autohide` in the defaults list.
- **`test/vm.exp`** answers each distinct "Let Homebrew take over …?" and "Also remove …'s settings and data?" once with y, like "Remove …?". The VM then exercises adoption and `--zap`; "no" is covered by bats.
- **`test/vm.sh`**: if `test/fixtures/<fixture>.before.sh` exists, it runs in the VM after the fixture is copied and before the one-liner, in `zsh -eux` like the steps file. It sets the VM up the way a used Mac would be (a hand-installed app, a saved Dock), with no Homebrew yet.

On today's `main`, the new lines are the same before and after a run, so `bare` still passes. The gate PR's own VM run proves it.

### The catalog (6a)

`apps/<id>` for each option of the seven app groups, and `apps/wispr-flow`:

```
cask=cap
app=Cap.app
allow=Cap: allow Screen Recording, and Camera and Microphone if you use them.
```

- `lib/apps.sh` reads every file at source time, as data (`key=value`, no `$(…)` ever runs), into `APP_CASK[id]`, `APP_BUNDLE[id]`, `APP_PASSWORD[id]` and `APP_ALLOW[id]` (lines joined with a newline). It adds each cask to `CASK_APP`, so `core_cask_state` works for apps too. A bad line stops with the file's name and line.
- `password=yes`: `zoom`, `google-drive`. `allow` lines: Cap, Wispr Flow ("Wispr Flow: allow Microphone and Accessibility."), Zoom ("Zoom: allow Camera and Microphone, and Screen Recording to share."). Others get lines when Gate B finds their prompts.
- `apps_chosen`: the picked ids in question order (the seven groups, then `wispr-flow` when `wispr_flow=yes`).
- Wispr Flow is a yes/no answer, not a pick in a group. Three helpers hide that, and every caller (install, `omamac install`, uninstall, doctor and its offers) uses them: `apps_key <id>` (the answer's key: `apps_media`, …, or `wispr_flow`), `apps_label <id>`, and `apps_drop <id>` (`choices_drop`, or `wispr_flow=no`).
- bats: every option has a file, every file is an option, every file has `cask` and `app`, and the README's "After install" holds every `allow` line.

### Installing (6a)

`apply_all` runs, in this order:

1. `DOCKER_NOTES=()` moves here from `docker_install`, so the password step's notes survive.
2. **The password step** (`apps_install_password`, first, replacing 5b's Docker Desktop cask step): the casks that will ask for the password: chosen apps with `password=yes` and Docker Desktop's cask when `docker=docker-desktop`, each only when missing. One line, "Homebrew asks for your password for Zoom and Docker Desktop.", then one `brew install --cask …` through `ui_run_open`. A cask Homebrew lists whose app is gone needs `brew reinstall --cask`; that is a second call, so Homebrew may ask twice in that rare case (an app trashed by hand).
3. Docker, the zsh file, the theme, the core tools and so on, as today. `docker_install_desktop` keeps lazydocker and its hand-installed line. doctor's Reinstall for Docker Desktop runs the password step, then `docker_install`.
4. **`apps_install`**, after the cloud CLIs: for each chosen app, by `core_cask_state`: `missing` → `brew install --cask` (or `reinstall` when Homebrew lists it), one `ui_run` per app ("Installing VLC"), so a failure names the app, and nothing for a `password=yes` app (the password step's); `brew` → nothing; `hand` → "VLC is already installed, not through Homebrew. omamac won't update it.", for password apps too (6b replaces this with adoption). Then "✓ Your apps are installed" when any app is chosen.
5. Settings, as today.

- **Before "Install?"**: when the password step will run, `install_questions` and `add_run` print "Homebrew asks for your password once more, after you confirm, for Zoom." under the summary box. No printed line may hold the text `Install?`: `vm.exp` answers its first sighting, and a `y` sent before gum's prompt is lost. A bats test checks it.
- **Summary**: `install_summary`'s "Installed:" line names the apps; then the `allow` lines of the installed apps; then, when any app was chosen, "The first time you open each app, macOS asks you to confirm; click Open." `add_run`'s box names the picks and adds the same lines.
- **`omamac install`**: `ADD_KEYS` gains the seven app groups and `wispr_flow`, first, in question order. Multi and yes/no already work.

### Updating (6a)

- `update_upgrade_app` takes the label and whether Homebrew asks for the password. Update calls it for Ghostty, Docker Desktop (when chosen) and each chosen app that Homebrew manages.
- One `brew outdated --cask --quiet <casks…>` for all of them first, instead of one call each. Only the listed ones go on to the App Management check and the upgrade; installer-package apps skip the check, as on uninstall. The closing ✗ line still names the apps that weren't upgraded.
- The outdated password apps (and Docker Desktop) are upgraded in one `brew upgrade --cask …` in the open, after the same line as the install, so Homebrew asks once.
- The other apps (and Ghostty) are upgraded one call each, also in the open, after "Homebrew may ask for your password." once: an upgrade runs the old version's uninstall steps, which ask for the password for some casks (Discord, Dropbox).
- update's closing ✗ line joins every app in `UPDATE_NOT_UPGRADED` with `clis_join` (today it names only the first two).
- `apply_all` puts back a chosen app that is missing, as it does a CLI.

### Uninstalling (6a)

`omamac uninstall <id>` for a catalog id (`vlc`, `vscode`, `wispr-flow`), and `docker-desktop`:

1. Not picked: "VLC isn't installed by omamac." and exit 0.
2. Installed by hand (`hand`): "VLC: installed by hand, so the app stays. omamac only forgets your pick." `Remove VLC?` drops the pick only, then "✓ VLC is removed from your answers".
3. Homebrew manages it: App Management is checked before any question, as for Docker Desktop. Without it, stop, change nothing, show the click. Not checked for installer-package apps (Zoom, Google Drive): their app is root-owned, and Homebrew removes it with sudo.
4. Only when Homebrew lists the cask (with no cask, a yes would delete nothing): "Also remove VLC's settings and data?" after a help line: "On yes, Homebrew also deletes what VLC keeps in ~/Library." For Docker Desktop: "On yes, Homebrew also deletes Docker Desktop's images, containers and volumes, and ~/.docker (Docker's settings and saved logins)." The cask's zap list holds `~/.docker`, `~/Library/Containers/com.docker.docker` and `~/Library/Group Containers/group.com.docker`; 6a's plan probes the zap in the VM.
5. One box: "VLC: the app." or "VLC: the app, with its settings and data." Then `Remove VLC?`.
6. "Homebrew may ask for your password.", then `brew uninstall --cask [--zap] <cask>` through `ui_run_open`, only when Homebrew lists the cask. Then the pick is dropped and saved, last (`wispr_flow=no` for Wispr Flow).

- `omamac uninstall` with no name offers the chosen apps too, and the "It can remove" list names them.
- Docker Desktop's uninstall keeps lazydocker's removal and its hand-installed rule from 5b; only the data question is new.

### doctor (6a)

A new check, "Your apps", after "Your tools":

- ✗ "VLC: you chose it, but it's gone from Applications", fix "omamac update puts it back; omamac uninstall vlc drops it". The id joins `DOCTOR_GONE`; `doctor_offer` offers Leave, Reinstall (`apps_install <id>`, or the password step for a password app) or Remove it from my answers.
- ℹ "VLC: installed by hand, so omamac won't update it". In 6b the fix is "To let Homebrew take it over: brew install --cask --adopt vlc" (no fix for installer-package apps).
- ✓ "Your apps" when every chosen app is there.

### Adoption (6b)

- **When it's asked.** After the questions are loaded or asked and before the summary box: `ask_adopt` goes through the chosen catalog apps. For each one in state `hand`, it prints "Spotify is already installed, but not through Homebrew. Homebrew can take it over, so it's updated and managed like your other apps." and asks `Let Homebrew take over Spotify?` (Enter alone is no).
  - yes: the id goes into `APPS_ADOPT`, for this run only.
  - no: the app leaves its picks; the summary shows the picks without it, and they are saved after "Install?". So the next run doesn't ask again.
  - An installer-package app isn't asked: the line from Approaches, and it leaves the picks.
- `omamac install` asks it for the new picks, before its box.
- **Applying.** `apps_install` adopts an app that is in `hand` and in `APPS_ADOPT`: `brew install --cask --adopt <cask>`. Not in `APPS_ADOPT` (update, or a run where the app appeared after the questions): the hand-installed line, as in 6a; for a non-password app it ends with the adopt command, so a run that failed after a yes (`omamac install` then says to run `omamac update`) still shows how to finish.
- Idempotent: an adopted app is `brew` from then on, so nothing is asked again. A run that stopped before adopting asks again next time.
- **Ghostty:** doctor's ℹ for a hand-installed Ghostty gains the fix "To let Homebrew take it over: brew install --cask --adopt ghostty" (probed). Docker Desktop's ℹ stays as in 5b.
- **Fixture `adopt`:** `bare` with `apps_media=vlc`. `adopt.before.sh` installs VLC the way a user would: it downloads the app's disk image from the URL in Homebrew's public cask data (`formulae.brew.sh/api/cask/<cask>.json`, read with `/usr/bin/jq`), copies the app into `/Applications`, and marks it as downloaded (a quarantine attribute, test-only, as a browser would). The one-liner asks the question and `vm.exp` says yes. Steps: Homebrew lists the cask, the app's inode is the one `before.sh` recorded, `omamac update` twice changes nothing, and `omamac uninstall vlc` removes it.

### The Dock (6c)

- **`settings.sh`**: `SETTINGS_KEYS_dock=("com.apple.dock show-recents boolean false")`, `SETTINGS_KEYS_dock_autohide=("com.apple.dock autohide boolean true")`. `settings_apply`, `settings_uninstall`, doctor and `remove_setting` (`dock-autohide`) loop over them like the other answers.
- **`lib/dock.sh`**, `dock_apply`, called by `settings_apply`; it sets `SETTINGS_DOCK=1` when it imports, so the Dock restarts once per run:
  - `dock=yes` and no record: export the Dock to a copy; write the record (the whole export from before the first cleanup; uninstall reads only its two arrays); edit the copy: remove every `persistent-apps` item that is Apple's (Approaches) and the `persistent-others` item for `file://$HOME/Downloads/`, then append omamac's apps (Ghostty, the chosen catalog apps, Docker Desktop) that are in Applications and not yet in the Dock. `defaults import`. If the import fails, delete the record and fail the step, so the next run starts over. Then write every omamac app found in the Dock to `dock-added`, added or not.
  - `dock=yes` with the record: append omamac's apps that are in Applications and not in `dock-added` (and not already in the Dock), then add them to `dock-added`.
  - A new tile holds only `tile-type file-tile` and the app's file URL; the Dock fills in the rest (probe).
- **Uninstall**:
  - `omamac uninstall dock`: export the Dock, put the record's two arrays back in the copy, import, restart the Dock, then `settings_uninstall dock` for `show-recents`; delete the record and `dock-added`; save `dock=no`, last. The box says: "Dock cleanup: your Dock goes back to how it was before omamac cleaned it. Changes you made to it since are undone."
  - `omamac uninstall <app>`, when `dock=yes`: its tile leaves the Dock (one export, `plutil -remove`, import) and its line leaves `dock-added`. `omamac uninstall docker-desktop` takes its tile out too. An app uninstalled while `hand` (installed by hand; omamac only forgets it) keeps its tile.
- **doctor**: "Dock cleanup" ✓ when the record exists and `show-recents` holds; ✗ "omamac hasn't cleaned the Dock" (no record), fix `omamac update`; ✗ for a drifted `show-recents`, as for the other settings. "Dock auto-hide" like the other settings.
- **Fixture `dock`:** `bare` with `apps_media=vlc dock=yes dock_autohide=yes`. `dock.before.sh` saves the Dock's URLs to a file. Steps:
  1. The Dock is exactly Ghostty and VLC, `persistent-others` is empty, `show-recents` is 0 and `autohide` is 1.
  2. `omamac update` twice changes nothing.
  3. `omamac uninstall vlc`: VLC leaves the Dock.
  4. `omamac uninstall dock`: the Dock's URLs match the saved file.
  5. `omamac uninstall dock-autohide`: `autohide` is absent.

### Fixtures and VM runs (6a)

- **`apps.env`**: `bare` with `apps_media=vlc`, `apps_screen_recording=cap`, `apps_communication=zoom`, `apps_developer=vscode`, `wispr_flow=yes`. `apps.brew-passwords` holds `1` (Zoom).
- **`apps.steps.sh`**:
  1. The five apps are in Applications, Homebrew lists the five casks, and `$(brew --prefix)/bin/code` is a link that resolves into Visual Studio Code.app. Nothing runs an app's binary: it would wait on macOS's first-open check, as `az` did in 3c.
  2. `omamac update` twice, with fingerprints compared.
  3. `defaults write org.videolan.vlc omamac-test -bool true`, and `~/Library/Preferences/org.videolan.vlc.plist` exists. `omamac uninstall vlc` (vm.exp says yes to the data question): VLC.app and that file are gone, and the pick is dropped.
  4. `omamac uninstall zoom`: Homebrew asks for the password (the fixture's one), and Zoom is gone.
  5. A second `omamac uninstall vlc` changes nothing.
- **`bare`**: unchanged; no apps.
- **`docker-desktop`**: also runs in 6a, with `apps_communication=zoom` added, so one Homebrew prompt covers Zoom and Docker Desktop (`.brew-passwords` stays `1`). Its steps check Zoom too; the uninstall answers yes to the data question, so it zaps Docker Desktop.

### bats

- fake-brew learns `--adopt`, `--zap`, `outdated` for several casks, and the casks in `install`/`uninstall` calls.
- Catalog: the file rules above; a bad line stops with its file and line.
- Install: one password step for Zoom, Google Drive and Docker Desktop together, in the open, before anything else; none when nothing needs it; the line before "Install?"; per-app installs; `brew` and `hand` states; summary lines from `allow`; a second run calls no brew install.
- `omamac install`: the app groups and Wispr Flow come first, with only unpicked apps.
- Update: one outdated call; only listed apps upgrade; App Management stops one; password apps in the open; no `--greedy` for apps.
- Uninstall: the order (App Management, data question, box, Remove?, brew, save); `--zap` only on yes; hand-installed drops the pick only; not picked exits 0; Docker Desktop's data question.
- doctor: each line above; `DOCTOR_GONE` and the three offers for an app.
- Adoption (6b): asked only in `hand`; yes adopts; no drops the pick and the summary shows it; installer-package apps aren't asked; Ghostty and Docker Desktop aren't asked; asked nothing in update.
- Wispr Flow through every helper: install, `omamac install`, uninstall (`wispr_flow=no`), doctor's three offers.
- Dock (6c): with a fake `defaults` and `plutil` working on a plist file: Apple's items (both rules) and Downloads are removed, the user's items stay, omamac's apps are added in order and once; an app in `dock-added` is never added again; an app installed in a run that failed before the Dock step is added next run; the record is written once and never rewritten; a failed import removes it; uninstall puts both arrays back; an uninstalled app's tile goes; doctor's lines.
- hygiene: no script in `bin`, `lib`, `install.sh` or `update.sh` sets `HOMEBREW_SUDO_CHECKED` or `SUDO_ASKPASS`, or passes `--force` to a cask command; `--zap` appears only in the uninstall path; `--greedy` only for the cloud CLI casks.

### Docs

- **README:**
  - The top: apps and the Dock are installed; "Apps and the Dock settings come later" goes.
  - "Install": Homebrew asks for the password once more right after "Install?" if you chose Zoom, Google Drive or Docker Desktop (once for all of them).
  - "After install": each `allow` line, and "The first time you open each app, macOS asks you to confirm; click Open."
  - "Keeping it up to date": apps update themselves; omamac upgrades one only when Homebrew lists it as outdated.
  - "What it changes": the casks; adoption; the Dock (what leaves, what's added, `dock-before.plist`); `show-recents` and `autohide`.
  - Uninstall: app ids, the data question, `dock` and `dock-autohide`.

## Vision updates in this change

- **The password.** Docker Desktop's exception covers every cask that needs the password (today Zoom and Google Drive too): one Homebrew step right after "Install?", which asks once for all of them; the summary before "Install?" says so (Tuna, 2026-11-19). The catalog rule reads "installs as a cask with no prompts other than that one password", and step 2 of "What the user experiences", the settled decision and the decisions log change with it.
- **Updating apps.** Apps are upgraded only when Homebrew lists them as outdated, after the App Management check, without `--greedy`; `--greedy` stays for the cloud CLI casks (Tuna, 2026-11-19). The `omamac update` bullet, the settled decision and the decisions log change with it.
- **App Management.** `--adopt` leaves the app in place (Homebrew's source), so it needs no App Management; upgrade and uninstall still check. The "App Management comes first" bullet changes.
- **Installer-package apps.** An app whose cask runs an installer package (Zoom, Google Drive) can't be adopted without being reinstalled, so omamac leaves a hand-installed copy alone and out of the picks. One sentence in "Installed by hand".
- **The Dock order.** "omamac's apps" are Ghostty, the catalog apps in catalog order, then Docker Desktop.
- **The data question.** "App only, or with its settings and data?" is asked as "Also remove VLC's settings and data?", where Enter alone is no, like omamac's other yes/no questions. One clause in "Uninstalling asks, then confirms".

## Left for later phases

- Gate B: the permission prompts each app shows on first launch, for the `allow` lines (only Cap, Wispr Flow and Zoom have one today); whether Google Drive's and Dropbox's system extensions need a click; the Dock on real hardware.
- Carried from 5b, now closed by Non-goals: adopting Ghostty and Docker Desktop isn't offered; doctor prints the command for Ghostty.
- For Tuna: Google Drive brings Google Docs, Sheets and Slides into Applications; its uninstall removes them too. Its login item stays after uninstall unless the terminal has Automation access to System Events (Homebrew warns).

## Left to the builder

- Exact wording of messages and summary lines.
- How fake-brew models `--adopt` and `--zap`, and how the Dock tests fake `defaults`.
