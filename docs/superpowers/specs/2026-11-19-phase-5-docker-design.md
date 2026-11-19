# Phase 5: Docker and its background service — design

Status: draft · 2026-11-19 · Source of truth for the why: [`vision.md`](../../../vision.md)

## Intent

Phase 5 installs Docker the way the user chose at the first run. colima runs Docker from the command line as a background service that starts at login. Docker Desktop is the app. Either way the user gets `docker`, `docker compose`, `docker buildx` and lazydocker, `omamac update` keeps them current, and `omamac uninstall` removes them while leaving the user's images and volumes alone.

It is done when a container runs in the VM.

## Goals

- `docker=colima` installs the formulas `colima`, `docker`, `docker-compose`, `docker-buildx` and `lazydocker`, links the two plugins where `docker` finds them, and starts colima as a Homebrew service (now and at each login).
- `docker=docker-desktop` installs the cask `docker-desktop` and the formula `lazydocker`. The summary and the README say to open Docker Desktop once to finish its setup.
- `omamac install` asks the Docker question when the answer is `none`.
- `omamac update` upgrades, by name, what the Docker answer installed, and only for that answer.
- `omamac uninstall colima` and `omamac uninstall docker-desktop` remove what omamac installed for that answer, keep the user's Docker data, and save `docker=none`.
- `omamac doctor` reports a missing piece (✗, with the fix), and colima not starting at login or a Docker Desktop installed by hand (ℹ).
- The Docker question offers No Docker, colima and Docker Desktop. OrbStack is dropped (Tuna, 2026-11-19; see "Vision updates").

## Non-goals (later phases)

- Removing Docker's data on uninstall (`colima delete`, `--zap`). Phase 6 brings the "app only, or app with settings and data?" question for apps, and Docker Desktop joins it there. In Phase 5 the data always stays.
- Adopting a Docker Desktop installed by hand (Phase 6). Until then it is used as it is and never upgraded, like a hand-installed Ghostty.
- colima's size (CPUs, memory, disk). colima's defaults stay; a user who wants more runs `colima start --cpu … --memory …` once, and colima keeps it.
- Docker's credential store. `docker login` with Homebrew's `docker` keeps credentials in `~/.docker/config.json`; see "Left for later phases".
- Migrations. No install holds `docker=orbstack`: before Gate B, omamac runs only in throwaway VMs.

## Anti-goals

- omamac deletes a container, image or volume, or anything under `~/.colima` or Docker Desktop's data.
- omamac writes `~/.docker/config.json`. (colima writes its own `currentContext` there when it starts; that's colima's.)
- omamac restarts a colima or Docker Desktop that's running. A re-run, update or doctor must never stop the user's containers. Only uninstall stops colima.
- omamac starts colima's service again after the user stopped it (`brew services stop colima`).
- A sudo prompt hidden under a spinner. When a step needs the password outside the one-liner, omamac asks for it in the open first.
- omamac removes quarantine or weakens Gatekeeper. The VM steps file does what the user's hands would, never omamac.
- A second run, update or uninstall changes anything.

## Constraints

- bash 5 after `boot.sh`; `set -Eeuo pipefail` with the `ERR` trap. Prompts read `$OMAMAC_TTY`; nothing is pre-selected.
- Gate files change only in a PR about the gate.
- Facts checked on 2026-11-19 (Homebrew's formula and cask data, the casks' source, and a probe VM on macOS 27.2):
  - **Versions:** colima 0.10.3 (depends on lima 2.3.0), docker 29.9.3, docker-compose 5.7.1, docker-buildx 0.39.0, lazydocker 0.25.2, cask `docker-desktop` 4.99.0 (`auto_updates`, conflicts with `rancher`).
  - **No nested virtualization in the test VM.** In a Tart macOS VM, `kern.hv_support` is 0, and `tart run --nested` says "macOS virtual machines do not support nested virtualization". colima's default VM (Apple's Virtualization framework) fails to start, and Docker Desktop's and OrbStack's engines can't start either.
  - **colima under emulation does run in the VM.** `colima start --arch x86_64 --vm-type qemu --cpus 2 --memory 2` (with the formulas `qemu` and `lima-additional-guestagents`) started in 216 s, and `docker run --rm hello-world` pulled and ran in 8 s. Started by launchd instead, the same emulated VM timed out after 2 min ("context deadline exceeded"). So the VM test starts it from the shell.
  - **colima's service:** the label is `sh.brew.colima`, the plist goes to `~/Library/LaunchAgents/`, and it runs `colima start -f`. `brew services start colima` exits 0 even when colima then fails (status `error`); Homebrew's `keep_alive: successful_exit` means a failed start isn't retried. A second `brew services start colima` exits 1, so omamac first reads whether the service is registered (the `registered` field of `brew services info colima --json`). `brew services stop colima` stops the VM and removes the plist; a second stop exits 0 with a warning.
  - **Plugins:** Homebrew's `docker` doesn't find Homebrew's `docker-compose` and `docker-buildx` (their caveats suggest `cliPluginsExtraDirs` in `~/.docker/config.json`). Symlinks in `~/.docker/cli-plugins/`, docker's own plugin folder, work: `docker compose version` and `docker buildx version` answered in the VM.
  - **colima writes `~/.docker/config.json`** (`currentContext: colima`) when it starts. The context `colima` points at `~/.colima/default/docker.sock`.
  - **OrbStack can't install unattended.** Its cask runs `orbctl _internal brew-postflight` from the app during `brew install`. The app is quarantined, so macOS stops it at `_dyld_start` until someone clicks Open (31 min in the VM; removing quarantine and restarting `syspolicyd` didn't release it). Tuna dropped OrbStack on 2026-11-19.
  - **Docker Desktop's cask** runs nothing from the app at install; its postflight only links `kubectl` when `/usr/local/bin/kubectl` is missing. It links `docker`, `docker-credential-desktop`, `docker-credential-osxkeychain`, `kubectl` and `kubectl.docker` into `/usr/local/bin`, `docker-compose` into `/usr/local/cli-plugins`, and zsh completions to `$OMAMAC_BREW_PREFIX/share/zsh/site-functions/_docker` and `_docker-compose`. In a clean VM over SSH it installed in 42 s and uninstalled cleanly, and Homebrew asked for the password both times (for the `/usr/local` links). Its uninstall quits Docker Desktop, unloads `com.docker.helper`, `com.docker.socket` and `com.docker.vmnetd`, and deletes the two privileged helpers. `~/.docker` didn't exist after install and uninstall (the app was never opened).
  - **Docker Desktop and Homebrew's `docker`** both install a `_docker` completion. With the formula installed, the cask's install likely fails on that file; 5b's first VM run or a bats-free probe confirms it before 5b's plan.
  - **Docker Desktop's terms:** free for personal use, education, non-commercial open source and small businesses; larger companies need a paid plan.

## Approaches

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| What "background services" means | colima runs as a Homebrew service (`brew services start colima`), so Docker is there at each login | The roadmap's phase scope. Docker Desktop starts itself once opened, from its own setting. Dropped: a launchd plist of omamac's own (Homebrew already ships one). |
| When omamac starts the service | Once: when it isn't registered and omamac's marker `~/.local/state/omamac/colima-service` doesn't exist; the marker is written right after the start | A re-run never starts it again, so a user's `brew services stop colima` stays stopped, and a run that failed before the start still starts it next time. Doctor shows ℹ with the command to start it. Dropped: starting it on every run (it would undo the user's stop); starting it only in the run that installs colima (a half-finished run would never start it). |
| How `docker` finds compose and buildx | Symlinks `~/.docker/cli-plugins/docker-compose` and `docker-buildx` → `$OMAMAC_BREW_PREFIX/opt/<formula>/bin/<formula>` | A drop-in folder: the vision's rule lets omamac add its own file there and leave the user's files alone. Dropped: `cliPluginsExtraDirs` in `config.json` (a JSON file with no include, edited only as a last resort). |
| A file already at a plugin path | Left alone; doctor says the user's own plugin is used (ℹ) | Never overwrite what the user made. |
| Docker data on uninstall | Always kept; uninstall says where it stays | Deleting images and volumes is not reversible. Phase 6's zap question will offer it for Docker Desktop with the other apps. |
| Upgrading Docker Desktop | The same path as Ghostty: no `--greedy`, only when `brew outdated --cask` lists it, App Management checked first | It updates itself. One function for both apps. |
| The password outside the one-liner | Before a Docker Desktop cask step in `install`, `update`, `uninstall` or doctor's reinstall: one line saying why, then `sudo -v` in the open | Homebrew needs it for the `/usr/local` links. `ui_run` hides brew's output under a spinner, so brew's own prompt would be hidden. The one-liner already holds sudo for the whole run. |
| colima's dependencies on uninstall | Left installed (`lima`) | The cloud CLIs do the same. `brew autoremove` would reach the user's own formulas. |
| "A container runs in the VM" | colima, started from the shell under emulation in the steps file, runs `hello-world` | The only engine that runs in a macOS VM. The emulation flags are test-only, like Phase 4's quarantine stand-in. colima starting at login on Apple's Virtualization framework is checked at Gate B. Docker Desktop's first container too. |
| OrbStack | Dropped from the question | Tuna, 2026-11-19: it can't install unattended or be tested in the VM. |
| Splitting the work | A gate PR, then 5a (colima), then 5b (Docker Desktop) | Small steps, each proven in the VM on its own. |

Everything except dropping OrbStack is Claude's call within the vision.

## Pull requests

1. **Gate PR (`gate-phase-5`).** `test/fingerprint.sh` learns what Phase 5 writes, so the VM's "second run changes nothing" covers it.
2. **5a (`phase-5a-colima`).** The Docker question without OrbStack, `lib/docker.sh` with colima, the plugin links and the service, `omamac install`, `update`, `uninstall colima` and doctor. This spec, its plan and the vision update ride along. VM fixtures: `colima` (new) and `bare`.
3. **5b (`phase-5b-docker-desktop`).** Docker Desktop: install, the App Management upgrade, `uninstall docker-desktop`, doctor. VM fixture: `docker-desktop` (new).

Each branches from `main` after the one before it merges.

## Design

### Gate PR

`test/fingerprint.sh` adds, each only when it exists:

- `brew services list`, one `service: <name> registered` or `service: <name> not registered` line per service. Not the status: colima's own state (`started`, then `error` once its VM fails in the test VM) can change between the two fingerprints without omamac doing anything.
- Every entry under `~/.docker`, `~/Library/LaunchAgents`, `/usr/local/bin` and `/usr/local/cli-plugins`: a hash for a file, `<path> -> <target>` for a symlink. `~/.docker/config.json` is included: colima writes it, and a change there is still a change.

On today's `main` the new lines are the same before and after a run, so `bare` still passes. The gate PR's own VM run proves it.

### The question

`lib/questions.sh`: `"No Docker:none" colima:colima "Docker Desktop:docker-desktop"`, with a help line: "colima runs Docker in the background from the command line. Docker Desktop is an app; larger companies need a paid plan for it." A saved `docker=orbstack` is now an invalid answer, which `choices_load` already reports. `test/install.bats` (`docker=orbstack`) and `test/ask.bats` (the option order) change with it.

### colima (5a)

New `lib/docker.sh`, sourced where `lib/clis.sh` is, and called from `apply_all` after `clis_install`:

- **`docker_install`**, for `docker=colima`:
  1. `brew install` only the missing ones of `colima docker docker-compose docker-buildx lazydocker`, in one call.
  2. Plugin links, for `docker-compose` and `docker-buildx`: if the path doesn't exist, create the link (and `~/.docker/cli-plugins/`) to `$OMAMAC_BREW_PREFIX/opt/<formula>/bin/<formula>`. If it's omamac's link, nothing. Anything else is left alone, with one ℹ line: a user's link that points at nothing (Docker Desktop leaves one when its app is trashed) gets "Your docker-compose link in ~/.docker/cli-plugins points at nothing. Remove it, then run omamac update."
  3. If the marker `~/.local/state/omamac/colima-service` doesn't exist: if the service isn't registered, `brew services start colima`; then write the marker. The run's summary gets: "colima starts Docker in the background now and at each login. The first start downloads Linux and takes a few minutes."
- **`docker_install`**, for `docker=none`: nothing.
- **Summary lines.** `docker_install` adds its lines to `DOCKER_NOTES` (an array, like `SETTINGS_REFUSED` is a flag). `install_summary`, `add_run`'s closing box and update's closing box print them, before the log line (update can be the run that starts the service, when the one-liner failed before it). `install_summary`'s "Installed:" line also names Docker, and `add_run`'s names the pick, only for `colima`: Docker Desktop installs nothing in 5a.
- **`omamac install`**: `ADD_KEYS` gains `docker`. `add_run` gets a branch for single questions: asked only when the answer is `none`, with all three options ("No Docker" first, so Enter alone adds nothing). A pick of `none` is skipped in both of `add_run`'s loops; another pick replaces the saved `none` (not `choices_add`, which is for multi answers).
- **`omamac update`**: with `docker=colima`, `update_upgrade` adds the installed ones of the five formulas to its by-name list (pinned ones are kept, as today). With `docker=docker-desktop`, it adds `lazydocker`. With `none`, nothing: a user's own `docker` is theirs. Upgrading colima doesn't restart it.
- **`omamac uninstall colima`**:
  - Not the answer: "colima isn't installed by omamac." and exit 0.
  - Shows "colima: colima, docker, docker-compose, docker-buildx and lazydocker. Your images, containers and volumes stay in ~/.colima." and asks `Remove colima?` (default No).
  - On yes: `brew services stop colima` if registered; `colima stop` if `colima status` says it runs; remove omamac's two links (only links pointing at Homebrew's plugins) and `~/.docker/cli-plugins` if that leaves it empty; `brew uninstall` the installed ones of the five formulas; delete the marker; save `docker=none`, last.
  - `remove_run` dispatches `colima` and `docker-desktop` by name with a `case`, as it does `desktops`, not through `REMOVE_KEYS` (that would accept `none`). Both join the "It can remove" list. `omamac uninstall` with no name offers the Docker answer when it isn't `none`, and the "nothing to remove" message names Docker too.
- **doctor:**
  - ✗ "colima: you chose it, but Homebrew no longer has <formulas>", in today's "Languages and cloud CLIs" check (renamed "Your tools"). It adds one entry, the answer `colima`, to `DOCTOR_GONE`, not one per formula. `doctor_offer` offers Reinstall (`docker_install`) or Leave for it; dropping it is `omamac uninstall colima`, printed as the fix. (`choices_drop` is for multi answers only.)
  - ✗ "docker can't find compose (or buildx)" when omamac's link is missing or dangling; fix `omamac update`. ℹ when the user's own file is at the path. ✗ "your link in ~/.docker/cli-plugins points at nothing" when the user's link is dangling; fix "Remove it, then run omamac update" (omamac never deletes it).
  - ℹ "colima doesn't start at login. To start it: brew services start colima" when the service isn't registered. A registered service in `error` is ℹ too ("colima didn't start; see $OMAMAC_BREW_PREFIX/var/log/colima.log"), not ✗: it's colima's state, not omamac's, and it's what the VM shows.

### Docker Desktop (5b)

- **`docker_install`**, for `docker=docker-desktop`: `brew install lazydocker` if missing. If Homebrew's `docker` formula is installed and the cask isn't, stop with ✗: "Homebrew's docker is installed, and Docker Desktop brings its own. Fix: brew uninstall docker, then omamac update." (as for Terraform; if the conflict fact above turns out false, this check goes). Then the cask, with the same three states as Ghostty (`missing`: install, or reinstall when Homebrew lists it; `brew`: nothing; `hand`: "Docker Desktop is already installed, not through Homebrew. omamac won't update it."). Summary line: "Open Docker Desktop once to finish its setup." `install_summary` and `add_run` then name Docker for `docker-desktop` too.
- **`omamac update`**: `update_upgrade_ghostty` becomes `update_upgrade_app <cask>`, called for `ghostty` and, when it is the answer, `docker-desktop`. The closing ✗ line names the apps that weren't upgraded.
- **`omamac uninstall docker-desktop`**: shows "Docker Desktop: the app and lazydocker. Your images, containers and volumes stay." If Homebrew manages the app, it checks App Management first (the vision: uninstall changes an app), and without it stops, changes nothing and shows the click, as update does. On yes: `brew uninstall --cask docker-desktop` (Homebrew asks for the password for its privileged parts), `brew uninstall lazydocker` if installed, save `docker=none`. A hand-installed Docker Desktop is left as it is: "Docker Desktop wasn't installed by omamac, so it stays." and the answer is saved `none`.
- **doctor:** ✗ when Homebrew no longer has the cask or lazydocker (one `docker-desktop` entry, offered as above); ℹ for a hand-installed app.
- **The password:** each cask step outside the one-liner is preceded by "Docker Desktop needs your password for its links in /usr/local." and `sudo -v`.

### Fixtures and VM runs

- **5a, `colima.env`:** `bare` with `docker=colima`. `colima.steps.sh`:
  1. The service is registered (`brew services info colima --json`), the two links point at Homebrew's plugins, and `docker compose version`, `docker buildx version` and `lazydocker --version` succeed.
  2. `omamac update` twice, with fingerprints compared.
  3. The stand-in for real hardware (test-only, with a comment saying why): `brew install qemu lima-additional-guestagents`, `brew services stop colima`, `colima delete -f`, `colima start --arch x86_64 --vm-type qemu --cpus 2 --memory 2`, then `docker run --rm hello-world` prints "Hello from Docker!".
  4. `omamac uninstall colima`: the five formulas, the links and the marker are gone, `~/.colima` is still there, and `docker=none` is saved. A second uninstall changes nothing (fingerprints). Step 3 already stopped the service, so uninstall stopping a registered one is covered by bats, not here.
- **5a, `bare`:** unchanged steps; `docker=none` installs nothing.
- **5b, `docker-desktop.env`:** `bare` with `docker=docker-desktop`. `docker-desktop.steps.sh`:
  1. `/Applications/Docker.app` exists, Homebrew lists the cask, `/usr/local/bin/docker` links into it, and `lazydocker --version` succeeds.
  2. `omamac update` twice, with fingerprints compared.
  3. The stand-in for typing the password: pipe the image's public password into `sudo -S -v` (the steps run with stdin from `/dev/null`), before `omamac uninstall docker-desktop`. The app, the cask and the links are gone, and `docker=none` is saved. A second uninstall changes nothing.
  The engine can't start in a macOS VM, so the first container on Docker Desktop is for Gate B.

### bats

- fake-brew learns `services info --json`, `services start` (exit 1 when already registered, as Homebrew does) and `services stop`; a fake `colima` answers `status` and `stop`.
- Install: only missing formulas are installed; the service is started once (no marker, not registered), never when registered or when the marker exists; a run that failed before the start starts it next time; a second run calls no `brew services start`; links are created, a correct link is left, a foreign file is left with the ℹ line; `DOCKER_NOTES` reaches both summaries.
- `omamac install`: the Docker question is asked only for `none`; "No Docker" adds nothing; a pick replaces `none`.
- `omamac uninstall none` and `omamac uninstall docker` are refused like any unknown name.
- Update: the installed Docker formulas are upgraded by name, only for the matching answer; with `none`, a user's own `docker` isn't upgraded; nothing restarts colima.
- Uninstall: the order (service stop, colima stop, links, formulas, answer last); only omamac's links are removed; nothing under `~/.colima` is touched; not the answer exits 0; a second uninstall calls no brew.
- Docker Desktop (5b): the three cask states; the `docker` formula conflict; `sudo -v` before each cask step outside the one-liner; uninstall stops without App Management; a hand-installed app isn't uninstalled; `update_upgrade_app` keeps Ghostty's tests passing.
- doctor: each ✗ and ℹ above; exit code non-zero only for ✗.
- hygiene: the never-touch list gains `~/.docker/config.json`. No script in `bin` or `lib` calls `colima delete`.

### Docs

- **README:**
  - The top says Docker is installed.
  - "After install": for Docker Desktop, "Open Docker Desktop once to finish its setup."
  - "What it changes": the Docker formulas or cask, the two plugin links, colima's login service.
  - The uninstall names `colima` and `docker-desktop`, and that Docker's data stays (with where).
  - One line: to stop colima starting at login, `brew services stop colima`; omamac won't start it again.

## Vision updates in this change

- Docker is one choice: colima, Docker Desktop or none. OrbStack is out: its install stops at macOS's "Open?" dialog, so it can't run unattended or be tested in the VM (Tuna, 2026-11-19). The lines at "What the user experiences" (the colima → OrbStack example), the scope list, Gate B's tool list and the settled decision change with it, and the decisions log gets the dated entry.
- The roadmap's "background services" reads: colima runs as a Homebrew service that starts at login.

## Left for later phases

- Phase 6: Docker Desktop in the "app only, or with data?" uninstall question and in adoption.
- Gate B: colima starting at login on real hardware; the first container on Docker Desktop; whether colima's default size (2 CPUs, 2 GiB) is enough.
- For Tuna: `docker login` with colima stores credentials unencrypted in `~/.docker/config.json` (Docker prints a warning). `docker-credential-helper` with `credsStore: osxkeychain` would fix it, but needs omamac to write that file.

## Left to the builder

- Exact wording of messages and summary lines.
- How fake-brew models `brew services`.
- Confirming the `_docker` completion conflict before 5b's plan.
