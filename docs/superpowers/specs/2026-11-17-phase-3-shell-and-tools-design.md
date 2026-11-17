# Phase 3: shell, prompt, editor, monitor, languages, cloud CLIs, herdr — design

Status: draft · 2026-11-17 · Source of truth for the why: [`vision.md`](../../../vision.md)

## Intent

Phase 3 is the first phase that installs what the user picked. After "Install?", omamac installs the core terminal tools for everyone, sets up zsh with omawsl's aliases and prompt, gives neovim and herdr their configs, and installs the languages and cloud CLIs saved in `choices.env`. After the run, `omamac update`, `omamac install` and `omamac uninstall` manage them.

It is done when: each tool installs, updates and uninstalls idempotently in the VM.

## Goals

- The core installs on every run with no question: starship, neovim, btop, mise, herdr, and the tools omawsl's aliases and LazyVim need (eza, bat, zoxide, fzf, ripgrep, fd, lazygit, tree-sitter-cli). jq comes with herdr's config (3b), which needs it.
- A new terminal window has omawsl's aliases, the starship prompt, nvim as `$EDITOR`, mise's languages on the PATH and zsh completion.
- On a fresh Mac, `nvim` opens LazyVim, and herdr uses omawsl's config and key bindings.
- The languages and cloud CLIs in `choices.env` are installed.
- `omamac update` pulls omamac, rewrites omamac's own files and upgrades what omamac installed. A second update changes nothing.
- `omamac install` offers the languages and cloud CLIs not yet picked, and installs the new picks.
- `omamac uninstall <thing>` removes one language or cloud CLI after a confirmation; a second run says it isn't installed and changes nothing.
- `omamac doctor` reports missing core tools, choices removed behind omamac's back, and user configs omamac leaves alone; for a removed choice it offers to reinstall it or drop it.

## Non-goals (later phases)

- Ghostty, and opening it straight into herdr (Phase 4). Phase 3's zsh never starts herdr.
- Themes (Phase 4): no starship palette or `STARSHIP_CONFIG`, no btop theme; herdr's config keeps omawsl's fixed theme line. The doctor offer to move a user's `~/.config/nvim` aside comes with themes too, since themes are what it unlocks.
- The App Management check. It guards changes to apps in `/Applications`; Phase 3 installs none (the `gcloud-cli` cask installs into Homebrew's own folders).
- `omamac install` and `uninstall` for apps, macOS settings and Docker. Each phase adds its own; Phase 3 handles only `languages` and `cloud_clis`.
- Migrations. Nothing released has old state to move.
- fastfetch and lazydocker. lazydocker can come with Docker (Phase 5).
- PHP. Dropped from the languages question for now (Tuna, 2026-11-17): mise builds it from source on macOS, needing build libraries nothing would own. In the vision's Backlog.

## Anti-goals

- A user file gets more than its one include line, or a user's own config (`~/.config/nvim`, `~/.config/starship.toml`, `~/.config/herdr/config.toml`, `~/.config/mise/config.toml`) is written.
- An omamac command names a formula, cask or mise tool outside omamac's lists. (Homebrew may still upgrade a dependency or dependent of a named formula; that is Homebrew's own rule and stays as is.)
- `omamac uninstall` removes a language version another of the user's mise configs still uses, or a Homebrew tap.
- A second run, update or uninstall changes anything.
- Something is installed before "Install?" is answered yes.
- The one-liner upgrades anything. A re-run only installs what's missing; upgrading is `omamac update`'s job.

## Constraints

- bash 5 everywhere after `boot.sh`; `set -Eeuo pipefail` with the `ERR` trap in `install.sh` and `update.sh`.
- Prompts read `$OMAMAC_TTY`; nothing is pre-selected; Enter alone never says yes.
- Every install is a Homebrew formula or cask, except languages, which mise installs.
- Gate files change only in a PR about the gate.
- Facts checked on 2026-11-17:
  - Homebrew has bottles for `eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli neovim btop starship mise herdr gh jq awscli`; azure-cli and gcloud-cli are casks (azure-cli's formula is gone, checked 2026-11-17); Terraform needs `hashicorp/tap`.
  - herdr reads `~/.config/herdr/config.toml`, or the file in `HERDR_CONFIG_PATH`. Its config has no include. omawsl notes herdr runs custom commands without the shell's PATH additions.
  - mise loads `~/.config/mise/conf.d/*.toml` before `~/.config/mise/config.toml`, so the user's file wins over omamac's.
  - mise also reads config from the current folder and its parents; an untrusted one there stops some commands.
  - `mise prune --tools <tool>` deletes only versions no tracked config selects.
  - mise installs Ruby (Apple Silicon), Erlang, Python, Node, Go and Java precompiled by default; PHP's backend (`vfox:jdx/vfox-php`) compiles.
  - macOS's `nc` has `-U` but no `-q` (omawsl's helper uses `-q1`).

## Approaches

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| Where omamac's zsh settings live | A file in the checkout, `config/zshrc`, copied to `~/.config/omamac/zshrc` | Reviewable as a file, not a heredoc. Copied, not sourced from the checkout, so `omamac update` is what changes it, as the vision says. |
| herdr's config | omamac's file in `~/.config/omamac/`, chosen through `HERDR_CONFIG_PATH`, which omamac's zshrc sets only when the user has no `~/.config/herdr/config.toml` and hasn't set the variable | herdr has no include. Tuna chose (2026-11-17) to leave a user's own config alone, as with `~/.config/nvim`, and let doctor explain (ℹ). Editing their TOML, or overriding it wholesale, were dropped. The same rule covers starship in Phase 4. |
| mise | omamac's tools in `~/.config/mise/conf.d/omamac.toml` (a drop-in), generated from `choices.env` | The vision's drop-in rule: the user's `config.toml` is never touched (`mise use -g` would write it). A version the user pins in their own config wins, by the same decision. |
| neovim | LazyVim's starter cloned into `~/.config/nvim` only when that folder doesn't exist, plus `lua/plugins/omamac.lua` (an empty spec now, Phase 4's theme hook) | The vision's folder rule. The extra file marks the folder as set up by omamac, so doctor can tell it from the user's own. |
| herdr's key-binding helper | Written fresh as `bin/omamac-herdr-mode`, from omawsl's behaviour | The vision copies configs as is but writes code fresh. The config needs the helper for omawsl's Ctrl g modes. |
| Updating omamac's code mid-command | `omamac update` pulls, then `exec`s the new checkout's `update.sh` | The running script is the old code; `exec`ing the new file runs the updated steps in the same run. |
| Splitting the work | A gate PR, then 3a, 3b, 3c | Small steps, each proven in the VM on its own (below). |

Tuna decided the core list, the user-config rule and dropping PHP on 2026-11-17 (see "Vision updates"). Everything else here is Claude's call within the vision.

## Pull requests

1. **Gate PR (`gate-phase-3`).** The VM loop runs a fixture's steps file after the two runs and answers "Remove …?" confirmations. Adds `bare.steps.sh` (`omamac doctor`) so the new step runs in its own VM pass on today's `main`.
2. **3a (`phase-3a-core-tools`).** Core formulas, `config/zshrc`, LazyVim, `omamac update`, doctor's core and neovim checks. This spec, the plan and the vision update ride along. VM fixture: `bare`.
3. **3b (`phase-3b-herdr-config`).** jq, herdr's config and `bin/omamac-herdr-mode`. VM fixture: `bare`.
4. **3c (`phase-3c-languages-and-clis`).** Languages, cloud CLIs, `omamac install`, `omamac uninstall`, doctor's drift check and offer. VM fixtures: `languages` and `cloud`.

Each branches from `main` after the one before it merges.

## Design

### Gate PR

- **`test/vm.sh`**
  - The one-liner runs in `zsh -lic` (from the Phase 2 "left for later" list), so `.zshrc` and omamac's zshrc load as in a Terminal window.
  - New last step, `steps`: if `test/fixtures/<fixture>.steps.sh` exists, download it in the VM to a temp file and run it with `zsh -lic 'zsh -eux -o pipefail <file> </dev/null'`, so a command in it can't read the script from stdin. It must exit 0. Then `omamac doctor` once more.
- **`test/vm.exp`** answers `y` once to each distinct prompt text matching `Remove [^?]*\?` in a command, like "Install?" (gum redraws a prompt, so a repeat of the same text is ignored; a different text is a new prompt). Any other y/n prompt still fails.
- **`test/fingerprint.sh`** adds, when they exist: `brew tap`, `/opt/homebrew/bin/mise ls --installed` run from `$HOME`, and hashes of every file under `~/.config/nvim` and `~/.config/mise/conf.d`. On `main` none exist, so the output is unchanged.
- **`test/vm_exp.bats`**: a fake ssh printing `Remove Go?` twice then `Remove Rust?` gets exactly two `y`s.
- **`test/fixtures/bare.steps.sh`**: `omamac doctor`.

A steps file is a fixture, not a gate file: it says what a fixture exercises, like the `.env` beside it.

### The core (3a)

`lib/core.sh` lists the core formulas once:

```
starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli
```

(3b adds `jq`.) `core_install` runs one `brew install` with the formulas `brew list --formula` doesn't have, under `ui_run`; nothing missing, nothing run. A formula the user already had through Homebrew is kept as it is.

### omamac's zsh file (3a)

`config/zshrc` replaces the heredoc in `install.sh`. Its content is omawsl's `configs/bashrc`, translated to zsh, keeping only what applies on a Mac:

1. omamac's `bin` on the PATH (as today).
2. History: `HISTSIZE` and `SAVEHIST` raised to at least 10000 and 20000 (never lowered), `setopt append_history hist_ignore_dups hist_ignore_space`.
3. `EDITOR` and `VISUAL` are `nvim` when it exists.
4. Completion: Homebrew's `share/zsh/site-functions` on `fpath`, then `compinit`, only if nothing ran it yet. Case-insensitive completion and ↑/↓ prefix history search, from omawsl's `inputrc`.
5. omawsl's aliases, each guarded on its tool as in omawsl: `ls`, `lsa`, `ll`, `lt`, `lta`, `tree` (eza); `cat` (`bat --paging=never`); `ff` (fzf with bat preview); zoxide with `cd=z`; `..`, `...`, `....`; fzf's key bindings (`source <(fzf --zsh)`); `g`, `gcm`, `gcam`, `gcad`; `d`; `lzg`, `lzd`; `n`; `r` after mise.
6. `mise activate zsh`, guarded on mise.
7. `starship init zsh`, guarded on starship, last, as starship asks.

The WSL, apt-name (`batcat`, `fdfind`), zellij, font-mode and multiplexer parts of omawsl's file are left out. 3b adds the `HERDR_CONFIG_PATH` lines.

omamac writes the file with the same compare-then-move it uses today, so a second run leaves it alone.

### neovim (3a)

If `~/.config/nvim` doesn't exist: `git clone --depth 1 https://github.com/LazyVim/starter` into a temp folder in `~/.config`, delete its `.git`, add `lua/plugins/omamac.lua` (`-- Set up by omamac.` and `return {}`), then `mv` it into place, so a failed clone never leaves a half folder. If the folder exists, nothing is written; the installer prints one ℹ line when it lacks omamac's file: "Your own neovim config is kept."

LazyVim installs its plugins the first time `nvim` opens; omamac doesn't start it.

### `lib/apply.sh` (3a)

The steps the one-liner and `update` share, so they can't drift apart: write omamac's own files (zsh file now; herdr's config in 3b; mise's drop-in in 3c), `core_install`, the neovim setup, and the chosen languages and cloud CLIs (3c). Apply only installs what's missing; it never upgrades.

The include lines in `~/.zprofile` and `~/.zshrc` stay in `install.sh` only. If the user removed one, `update` doesn't put it back; doctor reports it and the one-liner restores it, as today.

### `omamac update` (3a)

`bin/omamac update`:

1. `git -C ~/.local/share/omamac pull --ff-only` on the checked-out branch (`main` for users; the test branch in the VM). Local changes or a diverged branch stop the run with the fix.
2. `exec` the new checkout's `update.sh`.

`update.sh`, with no questions, logging to a new file in `~/.local/state/omamac/logs/` (as `boot.sh` does, newest 10 kept):

1. Load `choices.env`; stop if missing or invalid, pointing to the one-liner.
2. `apply` (above).
3. Upgrade what omamac installed, by name: `brew upgrade` the installed formulas among the core, bash, gum and chosen cloud CLIs; `brew upgrade --cask --greedy gcloud-cli` when chosen (3c); `mise upgrade` the chosen languages' tools, then `mise prune --tools` them, then the rails check (3c). `brew upgrade` refreshes Homebrew's data itself and does nothing for what's current, so a second update changes nothing.
4. A short summary: "omamac and your tools are up to date." plus the log path.

### herdr's config (3b)

- `config/herdr.toml` is omawsl's `configs/herdr.toml` with `@OMAWSL_ROOT@/bin/omawsl-herdr-mode` replaced by `@OMAMAC_HELPER@`, and comments about zellij or omawsl reworded to stand on their own. Key bindings and settings are unchanged, plus one line, `onboarding = false` (see "What herdr writes" below).
- omamac writes it to `~/.config/omamac/herdr.toml` (compare-then-move), with `@OMAMAC_HELPER@` replaced by the absolute path of `bin/omamac-herdr-mode` under `$HOME`. The file is omamac's: every run that applies omamac's files (the one-liner, `omamac update`, later `omamac theme`) rewrites it.
- omamac's zshrc exports `HERDR_CONFIG_PATH` to that file only if the variable is unset and `~/.config/herdr/config.toml` doesn't exist or is herdr's own (see "What herdr writes"). Otherwise the user's config is used; the installer and doctor say so (ℹ).
- `bin/omamac-herdr-mode` is written fresh to do what omawsl's helper does: the pane, tab, resize, move and session modes behind Ctrl g p/t/r/m/o, and the direct Alt chords. It calls `/opt/homebrew/bin/herdr` and `/opt/homebrew/bin/jq` by full path, runs under `/opt/homebrew/bin/bash`, and talks to herdr's socket with `nc -U` (no `-q`). Each mode's keys match omawsl's `docs/keys.md`.
- **What herdr writes** (checked in herdr 0.9.5's source, 2026-11-17): herdr writes to the file `HERDR_CONFIG_PATH` names, never to `~/.config/herdr/config.toml` when the variable is set. It writes `onboarding = false` when its first-run screen is closed, and theme, sound, toast and status-icon choices from its settings screen (Ctrl g ,). So:
  - omamac's file sets `onboarding = false`. Otherwise herdr's first-run screen would come back after every update, which rewrites the file. That screen only opens herdr's settings, which stay one key away.
  - Changes made in herdr's settings screen, or by hand, to omamac's file don't last: the next update or theme switch writes omamac's file again, so herdr always follows omamac's theme and key bindings. The README says so. Someone who wants their own herdr settings writes `~/.config/herdr/config.toml`; omamac never touches it (and then omamac's settings don't reach herdr). Tuna decided this on 2026-11-17, replacing a first version that left a changed file alone and so cut herdr off from omamac's themes.
  - With `HERDR_CONFIG_PATH` unset, closing the first-run screen makes herdr create `~/.config/herdr/config.toml` holding only `onboarding = false` and a newline (for example, herdr started in the window that ran the one-liner, before omamac's zsh file loaded). That file is herdr's, not the user's: a `~/.config/herdr/config.toml` whose whole content is `onboarding = false` (trailing newlines ignored) doesn't count as the user's config in zshrc, the installer or doctor. A symlink always counts as the user's. omamac leaves the file where herdr put it.
  - Dropped: leaving a changed file alone (herdr would stop following omamac's theme), keeping a backup, and carrying herdr's sound and toast choices over (Tuna: omamac handles herdr's settings; one's own go in `~/.config/herdr/config.toml`).
- Phase 4 starts herdr from Ghostty, where zsh may not run first, so Phase 4 passes `HERDR_CONFIG_PATH` itself (Ghostty's `env`).

### Languages (3c)

PHP leaves the `languages` question (`lib/questions.sh`), so its options are Ruby on Rails, Node.js, Go, Python, Elixir, Rust and Java. `~/.config/mise/conf.d/omamac.toml` is generated from the answer:

| id | mise tools |
| --- | --- |
| `ruby` | `ruby`, then `gem install rails` under that Ruby when `gem list -i rails` says it's missing |
| `node` | `node` |
| `go` | `go` |
| `python` | `python` |
| `elixir` | `erlang`, `elixir` |
| `rust` | `rust` |
| `java` | `java` |

Each tool is `"latest"`. Applying: write the file (compare-then-move), then `mise install <its tools>`, then the rails check. Every mise call runs from `$HOME` and names its tools, so a project's `mise.toml` in the current folder is never installed or trusted by omamac. A language that can't install cleanly fails the VM run; it is fixed or raised to Tuna, never skipped.

### Cloud CLIs (3c)

| id | Homebrew |
| --- | --- |
| `azure` | cask `azure-cli` |
| `aws` | `awscli` |
| `gcloud` | cask `gcloud-cli` |
| `gh` | `gh` |
| `terraform` | `hashicorp/tap/terraform` (tapped first, only when chosen) |

Installed with one `brew install` per kind for whatever isn't installed, checked by full name (`hashicorp/tap/terraform`, so homebrew/core's old `terraform` doesn't count as it). Homebrew can't install both, so with homebrew/core's `terraform` installed omamac stops before installing anything: "Terraform from homebrew/core is installed, and omamac installs HashiCorp's. Fix: brew uninstall terraform, then run omamac update."

### `omamac install` (3c)

1. Load choices (stop if invalid).
2. For `languages` and `cloud_clis`, ask the multi question with only the options not yet chosen. A question with nothing left is skipped. Nothing left anywhere: "You've picked everything omamac offers here." and exit 0.
3. Show only the additions, then "Install?" (default No).
4. On yes: save the merged choices, then `apply`. On no: nothing changes.

The Phase 2 question code gains a way to ask a multi question with a subset of its options.

### `omamac uninstall` (3c)

- `omamac uninstall <id>` for any language or cloud CLI id. A core tool's name (any formula in the core list, or `zsh`): "<name> is part of omamac's core and can't be removed on its own." exit 1. An unknown name: says so and lists what can be removed, exit 2. Not chosen: "<label> isn't installed by omamac." exit 0, nothing changed.
- No name: a single choice of the chosen languages and cloud CLIs, with "Nothing" first. Nothing chosen: says so, exit 0.
- Shows what goes (`Node.js: mise's node`, `Terraform: hashicorp/tap/terraform`), then `Remove <label>?` (default No).
- On yes, in this order, so a failure leaves the choice saved and doctor reporting it:
  - language: regenerate the drop-in without it, then `mise prune --tools <its tools>` from `$HOME` (a version another config still uses stays);
  - cloud CLI: `brew uninstall <formula or cask>` by full name; taps are never removed (one may hold the user's other tools);
  - then save the choices without it.

### `omamac doctor` (3a, 3b, 3c)

New checks, same ✓ ✗ ℹ format:

- **Core tools** (3a): ✗ lists the missing formulas, fix `brew install <them>`.
- **neovim config** (3a): ℹ only when `~/.config/nvim` exists without `lua/plugins/omamac.lua`: "your own neovim config is kept". Missing folder: ✗, fix "run the one-liner".
- **herdr config** (3b): ✓ omamac's file present and in use; ℹ when the user's own config is used; ✗ when omamac's file is missing, fix `omamac update`.
- **mise drop-in** (3c): ✗ if `conf.d/omamac.toml` doesn't match the choices, fix "omamac update".
- **Chosen languages and cloud CLIs** (3c): ✗ for each one Homebrew or mise no longer has.

After the report, for each chosen thing that is gone, and only when a terminal is there, doctor asks (single choice, "Leave it" first): "Leave it", "Reinstall it", "Remove it from my answers". The vision's "doctor offers fixes as questions" starts here. In the VM nothing is gone, so nothing is asked.

### Fixtures and VM runs

- `bare.env` (unchanged) with `bare.steps.sh` (3a): `omamac update`, record `fingerprint.sh`, `omamac update` again, record again, compare; `nvim --headless +qa` exits 0; `zsh -ic 'alias ls'` shows eza.
- 3b adds: in a new interactive shell, `HERDR_CONFIG_PATH` is omamac's file and `herdr config check` passes.
- `languages.env` (3c): every language, nothing else. `languages.steps.sh`: each language's command runs (`ruby -v`, `rails -v`, `node -v`, `go version`, `python -V`, `elixir -v`, `cargo -V`, `java -version`); `omamac update` twice with fingerprints compared; `omamac uninstall go`, then `mise ls --installed go` is empty and `go` is gone from `choices.env`; a second `omamac uninstall go` exits 0 and leaves the fingerprint unchanged.
- `cloud.env` (3c): every cloud CLI. `cloud.steps.sh`: `az version`, `aws --version`, `gcloud version`, `gh --version`, `terraform version`; update twice; uninstall `terraform` and `gcloud`, twice each, with the same checks.

If `languages` runs past about 30 minutes, it splits in two fixtures; the builder decides from the first run.

### bats

- `fake-brew` learns `upgrade`, `uninstall`, `tap` and `--cask`; a new `fake-mise` handles `install`, `upgrade`, `prune`, `ls`, `exec`.
- Core: one `brew install` with only the missing formulas; none when all are there.
- zsh file: copied from `config/zshrc`; unchanged on a second run; `zsh -n` accepts it; a shell with none of the tools prints nothing.
- neovim: cloned only when the folder is missing; a failed clone leaves no folder; an existing folder is untouched.
- update: pulls, `exec`s the new `update.sh`, upgrades only by name from omamac's lists, writes no include line, logs to its own file.
- install.sh: a re-run calls no `upgrade`.
- herdr: the written config names the helper by absolute path; it passes `herdr config check` where herdr is present (skipped otherwise); the helper's key handling is tested with herdr stubbed.
- `omamac install`: offers only unpicked options; nothing left → message; no → nothing saved.
- uninstall: each branch above, including core names, unknown names, not chosen, Ctrl-C, no, and that no `untap` is ever called.
- mise calls run from `$HOME` with tool names.
- doctor: each new check; the offer appears only with a terminal and a gone choice.
- hygiene: the never-touch list gains `~/.config/starship.toml`, `~/.config/herdr/config.toml`, `~/.config/mise/config.toml`, and `~/.config/nvim` when it existed before the run.

### Docs

- **README**: the top says what the one-liner now installs; "What it changes" lists the core formulas, `~/.config/nvim` (only if absent), `~/.config/mise/conf.d/omamac.toml`; that a user's own neovim, herdr or mise config is kept; "After install" says `nvim` installs its plugins the first time it opens; `omamac install`, `update` and `uninstall` get one line each; how to undo by hand grows with them.
- **CONTRIBUTING**: steps files; the fake mise.

## Vision updates in this change

All decided by Tuna on 2026-11-17, recorded in "Settled decisions" and the "Decisions log":

- The core gains eza, bat, zoxide, fzf, ripgrep, fd, lazygit and tree-sitter-cli; jq comes along for herdr's key bindings.
- A tool that reads one config file with no include (herdr, starship): omamac's file is used through the tool's env var when the user has none; a user's own file is left alone and doctor explains (ℹ), like `~/.config/nvim`. A version pinned in the user's own mise config wins over omamac's.
- PHP leaves the languages list for now; it goes to the Backlog.

## Left for later phases

- Phase 4: themes for starship, btop, neovim and herdr; Ghostty sets `HERDR_CONFIG_PATH` when it starts herdr; doctor's offer to move `~/.config/nvim` aside.
- Phase 4 and 6: `omamac install` and `uninstall` for the settings and apps they bring.
- Phase 5: lazydocker with Docker.

## Left to the builder

- Exact wording of messages and the summary.
- Whether any language needs a mise setting to finish within the time budget.
- The herdr helper's internal structure.
