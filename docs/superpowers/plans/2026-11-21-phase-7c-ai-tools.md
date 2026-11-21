# Phase 7c: AI tools — implementation plan

**Goal:** two new menus before Gate B: coding agents (terminal) and AI apps (desktop).

**Spec:** `docs/superpowers/specs/2026-11-21-phase-7c-ai-tools-design.md`. The why: `vision.md`, Decisions log 2026-11-21.

**Hard rule:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats or a test VM; never source `.bats` files outside bats; never run `brew install/uninstall/upgrade`, `defaults write` or `sudo` on this Mac.

- [ ] Task 1: questions `apps_ai` and `coding_agents`; five `apps/` files; `lib/clis.sh` gains the ids, `CLI_KEYS`, `clis_chosen`, `clis_key`, `clis_label`; apply, update, doctor, uninstall, install and the summary read both CLI keys. Every fixture answers both.
- [ ] Task 2: existing tests follow (counts, lists, messages); new tests for the agents: install (formula and cask), update (formula upgrade, greedy cask), uninstall, doctor, `omamac install` offering them, and the ids unique across every question that `omamac uninstall` reads.
- [ ] Task 3: fixtures: `cloud` installs every agent and uninstalls one formula and one cask; `apps` installs every AI app; `full` installs and uninstalls all ten.
- [ ] Task 4: README, CONTRIBUTING.
- [ ] Task 5: fresh review; VM runs (`bare`, `languages`, `cloud`, `apps`, `adopt`, `docker-desktop`, then `full` and `colima` side by side); PR; merge; Gate B issue gains the new checks and the split into what Claude checks and what needs Tuna's eyes.
