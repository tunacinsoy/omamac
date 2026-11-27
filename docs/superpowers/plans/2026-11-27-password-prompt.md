# Password prompt — plan

Spec: `docs/superpowers/specs/2026-11-27-password-prompt-design.md`. Branch `password-prompt`. TDD per task; run only the touched bats files and shellcheck.

1. **`lib/ui.sh` helpers** — `_ui_brew_line <offset>` (last `==>` line since offset), `_ui_phase` and `_ui_reason` (plain words for it), `_ui_who <title>` (who needs the password, and need/needs, its/their), `_ui_sudo_state <pid>` (none, running, waiting). Tests in `test/ui.bats`.
2. **The live row** — `ui_run_download open` (and `ui_run_open` in the terminal look) draws from the start with the phase, keeps two lines under it, stops redrawing while sudo runs, labels the prompt once when sudo waits. Tests in `test/ui.bats` with a stand-in sudo.
3. **Callers** — drop the "Homebrew may ask" and "asks for your password for" lines in `update.sh`, `lib/apps.sh` (at the step, not before "Install?"), `lib/remove.sh`, `lib/docker.sh`; fix their bats.
4. **Docs and vision** — `docs/updating.md`, `docs/uninstalling.md`, `docs/install.md`, `docs/what-it-changes.md`, `vision.md`.
5. **PR, VM, merge** — push, PR, `test/vm.sh password-prompt full`, merge when bats + vm are green.
