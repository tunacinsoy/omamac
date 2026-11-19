# Phase 5a: colima — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** With `docker=colima`, the one-liner and `omamac update` install colima, docker, docker-compose, docker-buildx and lazydocker, link the two plugins into `~/.docker/cli-plugins/`, and start colima's Homebrew service once. `omamac install` asks the Docker question when the answer is `none`; `omamac uninstall colima` removes it all but the user's data; doctor reports what's missing. OrbStack leaves the question.

**Architecture:** New `lib/docker.sh` holds the formula list per answer, `docker_install` (called by `apply_all` after `clis_install`), the plugin links, the service with its marker, `docker_uninstall_colima` and `docker_check`. `lib/add.sh` gains a branch for single questions, `lib/remove.sh` dispatches `colima` by name, `update.sh` upgrades the answer's formulas, and `lib/doctor.sh` folds colima into its chosen-tools check.

**Tech Stack:** bash 5, Homebrew (`brew services`), bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-19-phase-5-docker-design.md`, sections "Constraints", "Approaches", "The question", "colima (5a)", "Fixtures and VM runs" (5a) and "bats". The why: `vision.md`. Read both before any task.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats, never source `.bats` files outside bats, and **never run `brew install`, `brew uninstall`, `brew services` or `colima` on this Mac**. Tests use fake-brew and fake-colima.
- Docker question options, exactly: `"No Docker:none" colima:colima "Docker Desktop:docker-desktop"`. Help line: "colima runs Docker in the background from the command line. Docker Desktop is an app; larger companies need a paid plan for it."
- colima's formulas, in this order: `colima docker docker-compose docker-buildx lazydocker`. Plugins: `docker-compose`, `docker-buildx`; link `$HOME/.docker/cli-plugins/<p>` → `$OMAMAC_BREW_PREFIX/opt/<p>/bin/<p>`.
- Service: `brew services info colima --json` prints a JSON array whose first object has `"registered": true|false` (read with `jq -r '.[0].registered'`). A second `brew services start colima` exits 1, so start only when not registered. `brew services stop colima` removes the plist; on an unregistered service it exits 0 with a warning.
- Marker: `OMAMAC_COLIMA_MARKER=$OMAMAC_STATE_DIR/colima-service` (in `lib/paths.sh`), an empty file written right after the start (or after finding it registered). With the marker present, omamac never starts the service. Uninstall deletes it.
- omamac never runs `colima delete`, never touches `~/.colima`, never writes `~/.docker/config.json`, and never restarts colima outside uninstall.
- Summary line, exact: "colima starts Docker in the background now and at each login. The first start downloads Linux and takes a few minutes." It goes into the array `DOCKER_NOTES` (reset at the top of `docker_install`), printed by `install_summary` and `add_run`'s closing box.
- Gate files are not changed (`test/fingerprint.sh` already covers this after the gate PR #13).
- Run tests as `(trap '' PIPE; bats test/)`, about 4 minutes, so run it in the background or with a long timeout. The `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac test/helpers/fake-* | xargs shellcheck`, and `zsh -n` on steps files. Steps files match strings with `[[ … ]]`, never `| grep -q`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A half-finished run:** `brew install` fails after colima is in, or `brew services start` fails. The next run must still start the service once (no marker yet), and never twice. Test in Task 1.
2. **A user's own plugin** (a file, or a link to somewhere else) at `~/.docker/cli-plugins/docker-compose`: install leaves it with one ℹ line, uninstall leaves it, doctor says ℹ. Test in Tasks 1, 3, 4.
3. **`docker=none` with the user's own `docker` formula:** update doesn't upgrade it, doctor doesn't report it, uninstall doesn't offer it. Test in Tasks 2, 4.
4. **A user who stopped the service** (`brew services stop colima`, marker present): a re-run, update and doctor don't start it again; doctor shows ℹ with the command. Test in Tasks 1, 4.
5. **`omamac install` with Enter alone** on the Docker question picks "No Docker" and changes nothing; `omamac uninstall none` is refused. Test in Tasks 2, 3.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/questions.sh` | options without OrbStack, the help line | 1 |
| `lib/docker.sh` | formulas per answer, `docker_install`, links, service, uninstall, doctor check | 1, 3, 4 |
| `test/helpers/fake-brew` | `services info --json`, `services start`, `services stop`; `install colima` links fake-colima; `install docker-compose`/`docker-buildx` create `opt/<f>/bin/<f>` | 1 |
| `test/helpers/fake-colima` | `status` (exit 0 when `$OMAMAC_TEST_BREW_PREFIX/colima-running` exists), `stop` (removes it) | 1 |
| `lib/paths.sh`, `lib/apply.sh`, `install.sh`, `update.sh`, `bin/omamac` | marker path, sourcing `lib/docker.sh` after `lib/clis.sh`, `docker_install` in `apply_all`, `DOCKER_NOTES` in the summary | 1 |
| `lib/add.sh`, `update.sh` | the Docker question in `omamac install`, upgrades by answer | 2 |
| `lib/remove.sh` | `omamac uninstall colima` | 3 |
| `lib/doctor.sh` | colima in "Your tools", the link and service lines | 4 |
| `test/fixtures/colima.env`, `test/fixtures/colima.steps.sh`, `README.md`, `CONTRIBUTING.md`, existing tests that name OrbStack | VM fixture and docs | 1, 4 |

### Task 1: Install colima, its links and its service

**Files:** Create `lib/docker.sh`, `test/helpers/fake-colima`, `test/docker.bats`. Modify `lib/questions.sh`, `lib/paths.sh`, `lib/apply.sh`, `install.sh` (sourcing, `install_summary`), `update.sh` and `bin/omamac` (sourcing), `test/helpers/fake-brew`, `test/install.bats:211-215` and `test/ask.bats:44` (OrbStack gone).

**Interfaces:**
- Produces `docker_formulas <answer>`: the formulas omamac installs for that answer, one per line (`colima`: the five; `docker-desktop` and `none`: nothing in 5a).
- Produces `docker_link_state <plugin>`: prints `ours` (a link to Homebrew's plugin), `missing` (nothing at the path) or `theirs` (anything else).
- Produces `docker_service_registered`: exit 0 registered, 1 not, 2 Homebrew failed (prints why).
- Produces `docker_install` and the array `DOCKER_NOTES`.

- [ ] **Step 1: Write the failing tests in `test/docker.bats`**

```bash
@test "colima: installs only the missing formulas, in one call"        # docker pre-installed → one "brew install colima docker-compose docker-buildx lazydocker"
@test "colima: links both plugins to Homebrew's"                        # readlink == $OMAMAC_TEST_BREW_PREFIX/opt/docker-compose/bin/docker-compose (and buildx)
@test "colima: leaves a user's plugin file alone"                       # file content unchanged; output has ℹ and docker-compose
@test "colima: starts the service once and writes the marker"           # one "brew services start colima" in stub_calls; marker exists; DOCKER_NOTES holds the summary line
@test "colima: a second run starts nothing and changes nothing"         # no second "services start"; links and marker unchanged
@test "colima: a registered service isn't started, the marker is written"
@test "colima: with the marker, a stopped service stays stopped"        # marker present, not registered → no "services start"
@test "colima: a failed install starts the service on the next run"     # T_BREW_FAIL=1 run fails, no marker; next run → one start
@test "none: installs nothing"                                          # no brew install, no ~/.docker
@test "the Docker question has no OrbStack"                             # question_values docker == "none colima docker-desktop"
@test "install summary prints the colima line"                          # run install_summary with DOCKER_NOTES set
```

- [ ] **Step 2: Run them and see them fail** — `(trap '' PIPE; bats test/docker.bats)`: fails, `docker_install: command not found`.

- [ ] **Step 3: Fakes.** fake-brew: `services info <f> --json` prints `[{"name":"<f>","registered":true|false}]` from whether `$prefix/services/<f>` exists; `services start <f>` exits 1 with "already started" when it exists, else creates it (`T_BREW_SERVICES_FAIL=1` makes start fail); `services stop <f>` removes it and exits 0. `install colima` links `fake-colima` to `$prefix/bin/colima`; `install docker-compose|docker-buildx` creates `$prefix/opt/<f>/bin/<f>`. All calls are logged as today. Wire `fake-colima` like `fake-mise`.

- [ ] **Step 4: Implement.** `lib/questions.sh` options and help per Global Constraints. `lib/docker.sh` with the interfaces above; `docker_install` per the spec's "colima (5a)" steps 1–3, using `core_where missing` for the formulas and `ui_run` for each brew call. `apply_all` calls it after `clis_install` with `OMAMAC_STEP='installing Docker'`. `install_summary` prints `DOCKER_NOTES` before the log line, and its "Installed:" text names Docker when the answer isn't `none`. Fix the two existing tests that use `orbstack`.

- [ ] **Step 5: Run the whole suite** — all pass, `1..N` equals the `ok` count; shellcheck clean.

- [ ] **Step 6: Commit** — `feat: install colima, its plugin links and its login service`.

### Task 2: `omamac install` asks Docker; `omamac update` upgrades it

**Files:** Modify `lib/add.sh`, `update.sh`. Test: `test/add.bats`, `test/update.bats`.

**Interfaces:** Consumes `docker_formulas`, `docker_install` (Task 1).

- [ ] **Step 1: Write the failing tests**

```bash
# test/add.bats
@test "install asks Docker only when the answer is none"     # docker=colima → no "How should Docker run?" prompt
@test "install: Enter on Docker picks No Docker, nothing changes"   # gum_answers none (and no other picks) → "Nothing picked", choices.env unchanged
@test "install: picking colima replaces none and installs it" # gum_answers colima yes → docker=colima saved; "brew install colima …" called; summary box holds the colima line
# test/update.bats
@test "update upgrades colima's installed formulas by name"   # docker=colima, lazydocker missing → "brew upgrade" args include colima docker docker-compose docker-buildx, not lazydocker
@test "update leaves the user's own docker alone with none"   # docker=none, docker in Cellar → "brew upgrade" args don't include docker
```

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Implement.** `ADD_KEYS=(languages cloud_clis desktops window_margins docker)`. In `add_run`'s first loop, a `single` question is asked only when the saved answer is `none`, with all its options (`ask_one docker`); a pick other than `none` goes into `picks`, and the saved answer is put back. In the second loop, a single pick sets `CHOICES[$key]` to the pick and the summary line is "Docker: <label>". `add_run`'s closing box prints `DOCKER_NOTES`. In `update_upgrade`, add the installed ones of `docker_formulas "${CHOICES[docker]:-none}"` to `installed` before the pinned filter.

- [ ] **Step 4: Run the whole suite**, then **Step 5: Commit** — `feat: omamac install asks Docker; update upgrades colima`.

### Task 3: `omamac uninstall colima`

**Files:** Modify `lib/docker.sh`, `lib/remove.sh`. Test: `test/remove.bats`.

**Interfaces:**
- Consumes `docker_formulas`, `docker_link_state`, `docker_service_registered` (Task 1).
- Produces `docker_uninstall_colima`: stops the service if registered, `colima stop` if `colima status` exits 0, removes `ours` links and an empty `~/.docker/cli-plugins`, `brew uninstall` the installed formulas (one call), deletes the marker. Returns non-zero on failure (the answer isn't saved then).

- [ ] **Step 1: Write the failing tests**

```bash
@test "uninstall colima: not the answer exits 0"                  # docker=none → "colima isn't installed by omamac.", status 0, no brew call
@test "uninstall colima: shows what goes and where data stays"   # output has "~/.colima"; "Remove colima?" asked
@test "uninstall colima: no changes nothing"                     # gum_answers no → no brew call, docker=colima kept
@test "uninstall colima: removes in order, answer last"          # stub_calls order: services stop, colima stop, brew uninstall colima docker docker-compose docker-buildx lazydocker; links and marker gone; docker=none
@test "uninstall colima: keeps a user's plugin and ~/.colima"    # theirs file stays; ~/.colima/default/x untouched
@test "uninstall colima: a second run changes nothing"           # second run: status 0, no brew call
@test "uninstall colima: a failed brew uninstall keeps the answer"  # T_BREW_UNINSTALL_FAIL=1 → status non-zero, docker=colima
@test "uninstall none and docker are refused"                    # status 2, "can't remove"
@test "uninstall with no name offers colima"                     # docker=colima → picker options include colima
```

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Implement.** In `remove_run`, a `case` on the name sends `colima` to a `remove_docker` function (shape of `remove_setting`: check the answer, `ui_box` "colima: colima, docker, docker-compose, docker-buildx and lazydocker. Your images, containers and volumes stay in ~/.colima.", `ask_yes "Remove colima?"`, `log_start`, `docker_uninstall_colima`, `CHOICES[docker]=none`, `choices_save`, `ui_ok`). The no-name picker adds the Docker answer when it isn't `none`; the "nothing to remove" text and the "It can remove" list name `colima`.

- [ ] **Step 4: Run the whole suite**, then **Step 5: Commit** — `feat: omamac uninstall colima keeps the user's Docker data`.

### Task 4: Doctor, the VM fixture and docs

**Files:** Modify `lib/docker.sh`, `lib/doctor.sh`, `README.md`, `CONTRIBUTING.md`. Create `test/fixtures/colima.env`, `test/fixtures/colima.steps.sh`. Test: `test/doctor.bats`.

**Interfaces:** Consumes Task 1's functions. Produces `docker_check` (prints doctor lines via `doctor_report`; returns 1 only for ✗).

- [ ] **Step 1: Write the failing tests**

```bash
@test "doctor: colima with everything in place is ✓"
@test "doctor: a missing colima formula is ✗ under Your tools"        # one "colima" line naming the missing formula; fix text "omamac update"; status 1
@test "doctor: a missing plugin link is ✗"                            # fix "omamac update"
@test "doctor: a user's own plugin is ℹ, not ✗"                       # status 0
@test "doctor: an unregistered service is ℹ with the command"         # "brew services start colima"; status 0
@test "doctor: offers to reinstall colima"                            # gum_answers Reinstall → docker_install runs (brew install called)
@test "doctor: with none, a user's own docker isn't reported"
```

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Implement.** `doctor_check_chosen` is renamed in its title to "Your tools"; with `docker=colima` and missing formulas it appends one `colima` entry to `DOCTOR_GONE` (`doctor_key colima` → `docker`, label "colima", tool Homebrew, fix "omamac update puts it back; omamac uninstall colima drops it"). `doctor_offer` for `docker`: Reinstall runs `docker_install`; there is no Drop (`choices_drop` is for multi answers), only Leave. `docker_check` adds the link (✗ / ℹ) and service (ℹ, also for status `error`, naming `$OMAMAC_BREW_PREFIX/var/log/colima.log`) lines; `doctor_run` calls it after `doctor_check_chosen`.

- [ ] **Step 4: VM fixture.** `colima.env` = `bare.env` with `docker=colima`. `colima.steps.sh` per the spec's 5a steps 1–4. Step 3 carries the comment: the macOS test VM has no nested virtualization, so colima runs under emulation, started from the shell (launchd's start times out under emulation); real hardware is for Gate B. `zsh -n` passes.

- [ ] **Step 5: Docs.** README: the top line names Docker; "What it changes" gains the five formulas, the two links and colima's login service; uninstall gains `colima` and "your Docker data stays in ~/.colima"; one line: "To stop colima starting at login: brew services stop colima. omamac won't start it again." CONTRIBUTING: a steps file may use test-only stand-ins (quarantine, colima's emulation), each with a comment saying what real hardware or the user does instead.

- [ ] **Step 6: Run the whole suite and shellcheck**, then **Step 7: Commit** — `feat: doctor checks colima; the colima VM fixture; docs`.

### Task 5: Review, VM runs, PR, merge

- [ ] Whole-branch review (fresh reviewer, the spec and this plan), findings fixed.
- [ ] Push; `test/vm.sh phase-5a-colima colima` and `test/vm.sh phase-5a-colima bare`, both from a checkout nobody commits to while they run.
- [ ] PR with "Decisions", spec and plan links, bats count, both VM results; merge when `bats` and `vm` are green.
- [ ] Post "Phase 5a: passed" with "Left for later phases" (carry PR #12's list).
