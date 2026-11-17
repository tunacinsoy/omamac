# Phase 3c: languages, cloud CLIs, install and uninstall — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the languages and cloud CLIs in `choices.env` are installed by the one-liner and upgraded by `omamac update`; `omamac install` adds more, `omamac uninstall` removes one; doctor reports drift and offers to fix it.

**Architecture:** `lib/languages.sh` maps language ids to mise tools, writes the drop-in `~/.config/mise/conf.d/omamac.toml` and runs mise from `$HOME` by tool name. `lib/clis.sh` maps cloud CLI ids to Homebrew formulas and the one cask. `apply_all` calls both, so the one-liner, `update`, `install` and doctor's reinstall share them. `lib/add.sh` (`omamac install`) and `lib/remove.sh` (`omamac uninstall`) sit on top, using new prompt helpers in `lib/ask.sh`.

**Tech Stack:** bash 5, Homebrew, mise, gum, bats-core, shellcheck, Tart.

**Spec:** `docs/superpowers/specs/2026-11-17-phase-3-shell-and-tools-design.md`, sections "Languages (3c)", "Cloud CLIs (3c)", "`omamac install` (3c)", "`omamac uninstall` (3c)", "`omamac doctor`", "`omamac update`" step 3, "Fixtures and VM runs" and "bats" (the why: `vision.md`). Read both before any task.

## Global Constraints

- **Hard rule for every implementer and reviewer:** never run `bin/omamac`, `install.sh`, `update.sh` or `boot.sh` outside bats, and never source `.bats` files outside bats. They act on the real `$HOME`.
- bash 5, `set -Eeuo pipefail`; `install.sh`, `update.sh` and `bin/omamac install|uninstall` run under an `ERR` trap that names `OMAMAC_STEP`. `boot.sh` is not touched.
- Languages question, exactly: `"Ruby on Rails:ruby" Node.js:node Go:go Python:python Elixir:elixir Rust:rust Java:java` (PHP is gone).
- Language → mise tools: `ruby`→`ruby`, `node`→`node`, `go`→`go`, `python`→`python`, `elixir`→`erlang elixir`, `rust`→`rust`, `java`→`java`. Each `= "latest"`. Ruby also gets the `rails` gem.
- Cloud CLI → Homebrew: `azure`→`azure-cli`, `aws`→`awscli`, `gh`→`gh`, `terraform`→`hashicorp/tap/terraform` (after `brew tap hashicorp/tap`, only when chosen and not tapped), `gcloud`→cask `gcloud-cli`.
- Every mise call: `$OMAMAC_BREW_PREFIX/bin/mise`, run in a subshell that `cd`s to `$HOME` first, naming its tools. Never `mise use`, never a bare `mise install` or `mise prune`.
- Never written: `~/.config/mise/config.toml`, `~/.config/nvim` when it existed, `~/.config/starship.toml`, `~/.config/herdr/config.toml`. Never called: `brew untap`, `brew autoremove`, a bare `brew upgrade`.
- Apply only installs what's missing: a language whose tools mise already has is not passed to `mise install` (so a re-run never fetches a newer "latest"); upgrading is `update`'s job.
- omamac's files are written compare-then-move with `apply_put`; the drop-in is written on every apply, also when no language is chosen (empty `[tools]`).
- Prompts: nothing pre-selected, Enter alone never says yes, every prompt reads `$OMAMAC_TTY`, Ctrl-C exits 130 with "Stopped. Nothing else was changed."
- Gate files (`test/vm.exp`, `test/vm.sh`, `test/fingerprint.sh`, `test/image.sh`, `.github/workflows/bats.yml`, `.github/rulesets/main.json`) are not changed.
- Tests never touch the network or a real mise or Homebrew.
- Run tests as `(trap '' PIPE; bats test/)`; the `1..N` count must equal the `ok` count. Shellcheck: `git ls-files '*.sh' '*.bash' bin/omamac bin/omamac-herdr-mode test/helpers/fake-* | xargs shellcheck`.
- Messages: fewest plain words, ✓ ✗ ℹ via `lib/ui.sh`. Users never see apt, Windows or WSL.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Review Focus

1. **A language the user pins in their own mise config** (`~/.config/mise/config.toml` says `node = "20"`): omamac's drop-in still says latest, mise picks the user's pin, and `omamac uninstall node` keeps that version, saying mise kept it. Test in Task 5 (fake-mise keeps a tool listed in `T_MISE_KEEP`).
2. **A choice removed behind omamac's back, then `omamac uninstall` of it** (`brew uninstall gh` by hand): uninstall skips the brew call, drops the choice, exits 0. Test in Task 5.
3. **A failure halfway through uninstall** (`brew uninstall` refuses because another formula needs it): the choice stays saved, the run says what stopped, and doctor reports it. Test in Task 5.
4. **`omamac install` with nothing picked, or "no" at Install?**: nothing saved, nothing installed, exit 0. Tests in Task 4.
5. **homebrew/core's old `terraform` already installed**: it doesn't count as the chosen `hashicorp/tap/terraform`, so omamac installs the tap one and doctor doesn't call it present. Test in Task 2.

---

## File map

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/questions.sh`, `lib/languages.sh`, `lib/paths.sh`, `lib/apply.sh`, `install.sh`, `update.sh`, `test/helpers/fake-mise`, `test/helpers/fake-brew`, `test/languages.bats`, `test/choices.bats`, `test/install.bats` | PHP out; the drop-in; installing languages | 1 |
| `lib/clis.sh`, `lib/apply.sh`, `install.sh`, `update.sh`, `test/helpers/fake-brew`, `test/clis.bats` | installing cloud CLIs | 2 |
| `update.sh`, `test/update.bats` | upgrading languages and cloud CLIs | 3 |
| `lib/ask.sh`, `lib/choices.sh`, `lib/add.sh`, `bin/omamac`, `test/ask.bats`, `test/choices.bats`, `test/add.bats`, `test/omamac.bats` | `omamac install` | 4 |
| `lib/remove.sh`, `bin/omamac`, `test/remove.bats`, `test/omamac.bats` | `omamac uninstall` | 5 |
| `lib/doctor.sh`, `bin/omamac`, `test/doctor.bats` | drift checks and the offer | 6 |
| `test/fixtures/{languages,cloud}.{env,steps.sh}`, `README.md`, `CONTRIBUTING.md` | VM fixtures; docs | 7 |
| — | review, VM runs, PR, merge | 8 |

---

### Task 1: PHP out; languages install through the drop-in

**Files:**
- Create: `lib/languages.sh`, `test/helpers/fake-mise`, `test/languages.bats`
- Modify: `lib/questions.sh:48-49`, `lib/paths.sh`, `lib/apply.sh`, `install.sh`, `update.sh` (source `lib/languages.sh` before `lib/apply.sh`), `test/helpers/fake-brew` (`install mise` links fake-mise to `$prefix/bin/mise`, like gum), `test/choices.bats`, `test/install.bats`

**Interfaces:**
- Produces:
  - `OMAMAC_MISE_DROPIN=$HOME/.config/mise/conf.d/omamac.toml`, `OMAMAC_MISE_USER_FILE=$HOME/.config/mise/config.toml` in `lib/paths.sh`.
  - `declare -gA LANGUAGE_TOOLS` (the Global Constraints map, values space-separated).
  - `languages_render`: prints the drop-in for `CHOICES[languages]`: a comment line `# Written by omamac from your answers; omamac rewrites it. Your own pins go in ~/.config/mise/config.toml.`, `[tools]`, then `<tool> = "latest"` per tool in table order.
  - `languages_write_dropin`: renders to a temp file beside the drop-in, then `apply_put`.
  - `languages_has <tool>`: 0 if mise lists an installed version (`mise ls --installed --no-header <tool>` prints something); 1 if not; 2 if mise fails.
  - `languages_install [<id>…]`: default the chosen ids; one `mise install <tools…>` (under `ui_run "Installing <labels>"`) for the tools mise doesn't have; then `languages_rails` when `ruby` is among the ids; ✓ "Languages are installed" when any id was given or chosen, silent otherwise.
  - `languages_rails`: `mise exec ruby -- gem list --installed --exact rails` false → `ui_run "Installing Rails" … mise exec ruby -- gem install rails --no-document`.
  - `apply_all` order: zsh file, herdr, drop-in, core, neovim, languages (cloud CLIs join in Task 2).
- fake-mise (bash 3.2 safe): logs `mise <args>` to `$STUB_LOG`; exits 97 with "fake-mise: not run from HOME" when `$PWD != $HOME`; state in `$OMAMAC_TEST_BREW_PREFIX/mise/<tool>`. `install <tools…>` creates each (fails all with exit 1 when `T_MISE_FAIL=1`); `ls --installed --no-header <tool>` prints `<tool> 1.0` if present; `upgrade` logs only; `prune --tools <tools…>` removes each not named in `T_MISE_KEEP` (space-separated); `exec ruby -- gem list … rails` exits 0 iff `mise/rails` exists; `exec ruby -- gem install rails …` creates it.

- [ ] **Step 1: Write the failing tests** in `test/languages.bats` (sources `paths ui questions choices languages apply` in a bash 5 subshell, like `test/core.bats`):
  - "the drop-in lists each chosen language's tools as latest": `CHOICES[languages]="ruby elixir"` → file holds exactly the comment, `[tools]`, `ruby = "latest"`, `erlang = "latest"`, `elixir = "latest"`.
  - "no language: the drop-in has an empty [tools]".
  - "a second write leaves the drop-in and its mtime alone".
  - "the user's mise config.toml is never written": pre-create it with `node = "20"`; checksum and mtime unchanged after `languages_write_dropin` and `languages_install`.
  - "installs only tools mise lacks, in one call, from HOME": `node python` chosen, fake-mise has `node` → the log has exactly one `mise install python`; run from `cd /tmp` to prove the subshell `cd`.
  - "all present: no mise install".
  - "ruby: rails installed once": first run logs `gem install rails`; second run logs none.
  - "a mise failure returns non-zero and shows the log" (`T_MISE_FAIL=1`).
  - `test/choices.bats`: "languages has no php": `question_values languages` is `ruby node go python elixir rust java`; a file with `languages=php` fails to load.
  - `test/install.bats`: "installs the chosen languages after Install?" (FRESH_ANSWERS picks `node python`: log has `mise install node python`); add `~/.config/mise/config.toml`, `~/.config/starship.toml` and `~/.config/herdr/config.toml` to "never-touch list stays untouched" (the spec's hygiene line).
- [ ] **Step 2: Run them; they fail** — `(trap '' PIPE; bats test/languages.bats test/choices.bats test/install.bats)`.
- [ ] **Step 3: Implement** `lib/languages.sh`, the paths, the question line, `apply_all`'s new steps (`OMAMAC_STEP="writing ~/.config/mise/conf.d/omamac.toml"`, then `'installing your languages'`), the sourcing, fake-mise and fake-brew's link.
- [ ] **Step 4: Run the whole suite and shellcheck.** Expected: all pass, counts match.
- [ ] **Step 5: Commit** — `feat: install the chosen languages with mise`.

---

### Task 2: cloud CLIs install with Homebrew

**Files:**
- Create: `lib/clis.sh`, `test/clis.bats`
- Modify: `lib/apply.sh`, `install.sh`, `update.sh` (source it), `test/helpers/fake-brew`

**Interfaces:**
- Produces:
  - `declare -gA CLI_FORMULA=([azure]=azure-cli [aws]=awscli [gh]=gh [terraform]=hashicorp/tap/terraform)`, `declare -gA CLI_CASK=([gcloud]=gcloud-cli)`.
  - `clis_where <installed|missing> <id>…`: ids in that state, one per line, in the given order. Formulas by full name from one `brew list --formula --full-name -1`, casks from one `brew list --cask -1`. Non-zero if Homebrew can't list.
  - `clis_install [<id>…]`: default the chosen ids. For the missing ones: `brew tap hashicorp/tap` if terraform is missing and `brew tap` doesn't list `hashicorp/tap`; one `brew install <formulas…>`; one `brew install --cask <casks…>`; each under `ui_run`. ✓ "Cloud CLIs are installed" when any id was given or chosen.
  - `clis_what <id>`: `azure-cli`, `hashicorp/tap/terraform`, or `the gcloud-cli cask` (for uninstall's summary).
  - `apply_all`: cloud CLIs last (`OMAMAC_STEP='installing your cloud CLIs'`).
- fake-brew learns: `install a/b/c` records `a/b` in `Cellar/c/.tap`; `list --formula --full-name -1` prints `a/b/c` for those and the plain name otherwise; `install --cask <c…>` / `list --cask -1` use `Caskroom/`; `tap` with no args prints `$prefix/taps` lines, `tap <name>` appends to it; `uninstall [--cask] <name>` removes the Cellar or Caskroom entry (by the last `/` part), and fails with "Error: <name> is required by other" when `T_BREW_UNINSTALL_FAIL=1`. Every call stays logged.

- [ ] **Step 1: Write the failing tests** in `test/clis.bats`:
  - "installs formulas in one call, the cask in another": `aws gcloud gh` chosen → `brew install awscli gh` and `brew install --cask gcloud-cli`.
  - "terraform: taps first, only when not tapped"; second run: no `brew tap hashicorp/tap`, no install.
  - "no terraform chosen: never taps".
  - "homebrew/core's terraform doesn't count": Cellar has plain `terraform` → `brew install hashicorp/tap/terraform` runs.
  - "all present: no brew install".
  - "brew can't list: fails, installs nothing" (`T_BREW_LIST_FAIL=1`).
- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement** `lib/clis.sh`, `apply_all`'s step, the sourcing, the fake-brew additions.
- [ ] **Step 4: Run the suite and shellcheck.** Expected: all pass; install.bats now logs `brew install gh` from FRESH_ANSWERS.
- [ ] **Step 5: Commit** — `feat: install the chosen cloud CLIs with Homebrew`.

---

### Task 3: `omamac update` upgrades them

**Files:**
- Modify: `update.sh` (`update_upgrade`), `test/update.bats`

**Interfaces:**
- Consumes: `clis_where`, `CLI_FORMULA`, `CLI_CASK`, `LANGUAGE_TOOLS`, `languages_rails`.
- Produces: `update_upgrade` (formulas) then `update_upgrade_casks`, then `update_upgrade_languages`.
  - Formulas: the installed core, bash, gum and chosen cloud formulas (full names), pinned ones left out by comparing the last `/` part with `brew list --pinned`; one `brew upgrade`.
  - Cask: `brew upgrade --cask --greedy gcloud-cli` when gcloud is chosen and installed.
  - Languages: `mise upgrade <tools…>`, then `mise prune --tools <tools…>` with `MISE_YES=1` in its environment (prune may confirm each version; the user chose to update), then `languages_rails` when ruby is chosen. Nothing chosen → no mise call.

- [ ] **Step 1: Write the failing tests** in `test/update.bats` (setup copies `lib/languages.sh` and `lib/clis.sh` into origin via `lib/`, already covered):
  - "upgrades chosen cloud formulas by full name": choices with `terraform gh` → one `brew upgrade` naming `hashicorp/tap/terraform` and `gh` among the core.
  - "gcloud: one greedy cask upgrade".
  - "languages: mise upgrade, prune, then rails" for `ruby go`: log order `mise upgrade ruby go`, `mise prune --tools ruby go`, `mise exec ruby -- gem list …`.
  - "no languages: no mise call at all" (bare.env).
  - "a second update changes no file" still passes with languages chosen.
- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite and shellcheck.**
- [ ] **Step 5: Commit** — `feat: omamac update upgrades the chosen languages and cloud CLIs`.

---

### Task 4: `omamac install`

**Files:**
- Create: `lib/add.sh`, `test/add.bats`
- Modify: `lib/ask.sh`, `lib/choices.sh`, `bin/omamac`, `test/ask.bats`, `test/choices.bats`, `test/omamac.bats`

**Interfaces:**
- Produces:
  - `ask_one <key> [<value>…]`: with values, offers only those options (in table order); sets `CHOICES[key]` to the picks only.
  - `ask_yes <text>`: confirm, default No; 0 yes, 1 no, 130 → `ask_stopped`; needs the tty. `ask_install` becomes `ask_yes "Install?"`.
  - `ask_choose <header> <Label:value>…`: single choice; sets `ASK_PICKED` (a global, because `ask_stopped` must exit the script, not a `$(…)` subshell).
  - `choices_add <key> <id>…` and `choices_drop <key> <id>`: update `CHOICES[key]`, normalised, table order.
  - `add_run`: the spec's four steps. Questions asked: `languages`, `cloud_clis`, each with only its unpicked values, skipped when none are left. Nothing left anywhere → "Everything omamac offers here is installed." exit 0. Nothing picked → "Nothing picked, so nothing changed." exit 0. Otherwise `ui_box` with one line per question that gained picks (`Languages: Go, Rust`), `ask_yes "Install?"`; no → "Stopped. Nothing else was changed." exit 0; yes → `choices_save`, `log_start`, `apply_all`, `ui_box "Installed: <labels>" "Log: …" "Open a new terminal window to use them."`.
  - `bin/omamac`: sources everything `install.sh` does plus `lib/log.sh` and `lib/add.sh`; `install` sets `trap omamac_failed ERR` (prints "omamac stopped while $OMAMAC_STEP." and "Fix the problem and run omamac <cmd> again.", exit 1) and runs `add_run`; extra args → usage, exit 2. Missing choices file → "omamac doesn't know your answers. Fix: run the one-liner." exit 1; invalid → `choices_load`'s message, exit 1. The trap is set only for install and uninstall: doctor returns 1 on a ✗ and must not trip it.

- [ ] **Step 1: Write the failing tests:**
  - `test/ask.bats`: "ask_one with values offers only those"; "ask_yes: yes 0, no 1, Ctrl-C 130"; "ask_choose sets ASK_PICKED; Ctrl-C exits 130".
  - `test/choices.bats`: "choices_add keeps table order and skips repeats"; "choices_drop of the last id leaves an empty answer".
  - `test/add.bats` (runs `"$BASH5" "$REPO_ROOT/bin/omamac" install` with a sandbox HOME guard like update.bats; checkout = `$REPO_ROOT`'s files is fine since install doesn't pull): "offers only unpicked options" (choices `node`, gum log shows no `Node.js` option); "nothing left: says so, asks nothing"; "nothing picked: nothing saved, no Install?"; "no at Install?: choices.env unchanged, no mise or brew install"; "yes: saves the merged answers and installs only the additions"; "Ctrl-C at a question: exit 130, nothing saved"; "no choices file: stops with the fix".
  - `test/omamac.bats`: "commands not built yet say so" now covers only `theme`.
- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite and shellcheck.**
- [ ] **Step 5: Commit** — `feat: omamac install adds languages and cloud CLIs`.

---

### Task 5: `omamac uninstall`

**Files:**
- Create: `lib/remove.sh`, `test/remove.bats`
- Modify: `bin/omamac`, `test/omamac.bats`

**Interfaces:**
- Consumes: `ask_yes`, `ask_choose`, `choices_drop`, `languages_write_dropin`, `languages_has`, `clis_where`, `clis_what`, `CORE_FORMULAS`.
- Produces: `remove_run [<name>]`:
  - Core name (`CORE_FORMULAS`, `bash`, `gum` or `zsh`; bash and gum are omamac's own, so they count as core): "<name> is part of omamac's core and can't be removed on its own." exit 1.
  - Unknown: "omamac can't remove '<name>'. It can remove: ruby, node, go, python, elixir, rust, java, azure, aws, gcloud, gh, terraform." exit 2.
  - Not chosen: "<label> isn't installed by omamac." exit 0, no file touched (no log either: `log_start` only after the confirmation).
  - No name: nothing chosen → "omamac installed no languages or cloud CLIs, so there's nothing to remove." exit 0, no prompt; else `ask_choose "What should omamac remove?" "Nothing:none" <chosen labels>`; `none` → exit 0.
  - `ui_box "<label>: mise's <tools joined by ' and '>"` or `"<label>: <clis_what>"`, then `ask_yes "Remove <label>?"`; no → "Nothing was removed." exit 0.
  - Yes, in this order: language → `choices_drop` in memory, `languages_write_dropin`, `MISE_YES=1 mise prune --tools <tools>` from `$HOME`, then any tool `languages_has` still finds → ℹ "mise kept <tool>: another of your mise configs uses it."; cloud CLI → `brew uninstall [--cask] <full name>` only if `clis_where installed` lists it. Then `choices_save`, ✓ "<label> is removed". `OMAMAC_STEP` names each step.
  - `bin/omamac uninstall [<name>]` under the same ERR trap; more than one name → usage, exit 2.

- [ ] **Step 1: Write the failing tests** in `test/remove.bats`: "a core name is refused" (`herdr`, `zsh`, `gum`: exit 1, message); "an unknown name lists what can go" (exit 2); "not chosen: exit 0, no file changed (snapshot like update.bats)"; "go: drop-in loses go, mise prune --tools go from HOME, choices lose go"; "a second uninstall go changes nothing"; "a pinned tool mise keeps is reported" (`T_MISE_KEEP=node`); "terraform: brew uninstall hashicorp/tap/terraform, never untap"; "gcloud: brew uninstall --cask gcloud-cli"; "removed by hand: no brew call, choice dropped"; "brew refuses: exit 1, choice still saved" (`T_BREW_UNINSTALL_FAIL=1`); "no at Remove?: nothing changes"; "Ctrl-C at Remove?: exit 130"; "no name: Nothing first, then the chosen labels"; "no name, nothing chosen: no prompt". `test/omamac.bats` drops `uninstall` from "not built yet".
- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite and shellcheck.**
- [ ] **Step 5: Commit** — `feat: omamac uninstall removes one language or cloud CLI`.

---

### Task 6: doctor's drift checks and offer

**Files:**
- Modify: `lib/doctor.sh`, `bin/omamac`, `test/doctor.bats`

**Interfaces:**
- Consumes: `languages_render`, `languages_has`, `clis_where`, `ask_choose`, `choices_drop`, `languages_install`, `clis_install`, `languages_write_dropin`, `log_start`.
- Produces:
  - `doctor_check_choices` sets `DOCTOR_HAS_CHOICES=1` on ✓. The two new checks run after it; without loaded choices each is ℹ "skipped, your saved answers can't be read".
  - `doctor_check_mise_dropin`: ✓ "mise drop-in" when the file equals `languages_render`; else ✗ "~/.config/mise/conf.d/omamac.toml doesn't match your answers", fix `omamac update`.
  - `doctor_check_chosen`: fills `DOCTOR_GONE` with gone ids (a language is gone when any of its tools is missing; a CLI when `clis_where missing` lists it). None → ✓ "Languages and cloud CLIs". Each gone → ✗ "<label> — you chose it, but <mise|Homebrew> no longer has it", fix "omamac update puts it back; omamac uninstall <id> drops it". mise not executable or Homebrew can't list → ℹ "skipped, … can't list what's installed" (the core check already names it).
  - `doctor_offer`: after the report, only when `DOCTOR_GONE` is non-empty and `$OMAMAC_TTY` is readable; per id `ask_choose "<label> is gone. What should omamac do?" "Leave it:leave" "Reinstall it:reinstall" "Remove it from my answers:drop"`. reinstall → `log_start` once, then `languages_install <id>` or `clis_install <id>`; drop → `choices_drop`, `choices_save`, `languages_write_dropin` for a language, ✓ "<label> is dropped from your answers". Doctor's exit status stays the report's.
  - The file header no longer says read-only: it reports, then offers fixes as questions.
  - `bin/omamac` sources `lib/languages.sh`, `lib/clis.sh`, `lib/ask.sh`, `lib/log.sh` before `lib/doctor.sh` (Task 4 may already have).

- [ ] **Step 1: Write the failing tests** in `test/doctor.bats`: `healthy_mac` also writes the drop-in (as it does herdr's file); "healthy Mac" counts 14 ✓; "drop-in missing or edited: ✗ with omamac update"; "a chosen language gone: ✗ naming it" (choices `go`, fake-mise empty); "a chosen CLI gone: ✗"; "Leave it: nothing changes"; "Reinstall it: mise install go runs"; "Remove it from my answers: choices and drop-in lose it"; "no terminal: no offer" (`OMAMAC_TEST_TTY` set to a missing path); "nothing gone: no prompt" (fake-gum with no answers queued would exit 99, so a prompt fails the test).
- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite and shellcheck.**
- [ ] **Step 5: Commit** — `feat: doctor reports gone languages and cloud CLIs and offers a fix`.

---

### Task 7: VM fixtures and docs

**Files:**
- Create: `test/fixtures/languages.env`, `test/fixtures/languages.steps.sh`, `test/fixtures/cloud.env`, `test/fixtures/cloud.steps.sh`
- Modify: `README.md`, `CONTRIBUTING.md`

- [ ] **Step 1: Fixtures.** Each `.env` is `bare.env` with `languages=ruby node go python elixir rust java` or `cloud_clis=azure aws gcloud gh terraform`. Each steps file starts like `bare.steps.sh` (the `fp` helper, update twice, fingerprints compared), then:
  - languages: `ruby -v`, `rails -v`, `node -v`, `go version`, `python -V`, `elixir -v`, `cargo -V`, `java -version`, each in `zsh -ic` so mise's activate puts them on the PATH; then `omamac uninstall go`; `[[ -z $(cd ~ && mise ls --installed --no-header go) ]]`; `[[ $(grep '^languages=' ~/.local/state/omamac/choices.env) != *go* ]]`; record `fp`; `omamac uninstall go` again; `fp` unchanged; `omamac doctor`.
  - cloud: `az version`, `aws --version`, `gcloud version`, `gh --version`, `terraform version`; then for `terraform` and `gcloud`: uninstall, check Homebrew no longer has it (`if brew list --formula hashicorp/tap/terraform >/dev/null 2>&1; then exit 1; fi`, and `--cask gcloud-cli`), `fp`, uninstall again, `fp` unchanged; `omamac doctor`.
  - Under `zsh -e` a `! cmd` line never stops the script, so every negative check is written `if …; then exit 1; fi` or as a `[[ … ]]` test.
  - `test/choices.bats`'s fixture check covers the new `.env` files; run it.
- [ ] **Step 2: README.** Top paragraph: the one-liner now installs your languages and cloud CLIs too; apps, Docker and macOS settings come later; `theme` says "not available yet". "What it changes": the chosen languages (mise) and cloud CLIs (Homebrew, Terraform from `hashicorp/tap`), `~/.config/mise/conf.d/omamac.toml` (omamac rewrites it; your own pins in `~/.config/mise/config.toml` win and are never touched). One line each: `omamac install` (adds languages and cloud CLIs you didn't pick), `omamac uninstall <name>` (removes one, after asking; a version another mise config uses stays; Homebrew taps stay). Undo by hand: replace "There is no uninstall command yet" with: `omamac uninstall` removes your picks one at a time; for the rest, the current steps.
- [ ] **Step 3: CONTRIBUTING.** The fake mise (`test/helpers/fake-mise`, its `T_*` knobs), and that `bare`, `languages` and `cloud` are the fixtures a change to languages or CLIs runs.
- [ ] **Step 4: Run the suite** (hygiene greps the docs). Expected: all pass.
- [ ] **Step 5: Commit** — `docs: languages, cloud CLIs, install and uninstall`.

---

### Task 8: Review, VM runs, PR, merge

- [ ] **Step 1:** `git fetch origin && git rebase origin/main`. Expected: `git diff origin/main --stat` lists no gate file.
- [ ] **Step 2:** Whole-branch review (superpowers:requesting-code-review) against the spec and this plan, with the hard rule in the brief. Each fix its own commit; suite green with matching counts; shellcheck clean.
- [ ] **Step 3:** `git push -u origin phase-3c-languages-and-clis`, then `test/vm.sh phase-3c-languages-and-clis bare`, `… cloud`, `… languages` on the same head commit. Each must print `✓ … passed`; each posts `vm`, so a later pass never hides an earlier fail: stop at the first fail, fix, push, and run all three again. If `languages` runs past about 30 minutes, split it into two fixtures (the spec allows it). A language that can't install cleanly is fixed or raised to Tuna, never skipped.
- [ ] **Step 4:** PR "Phase 3c: languages, cloud CLIs, install and uninstall": what it does, decisions made here (bash and gum count as core in uninstall; apply never passes an installed language to `mise install`; prune runs with `MISE_YES=1`), the three VM results. Merge once `bats` and `vm` are green and review findings are fixed; post "Phase 3: passed" with "Left for later phases" (3b's list minus what 3c did, plus anything new).
