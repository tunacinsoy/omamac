# omamac configure and menus: plan

Spec: [`2026-11-24-configure-and-menus-design.md`](../specs/2026-11-24-configure-and-menus-design.md). Branch `configure-menus`, one PR, then tag `v0.2.0`.

**Hard rule:** never run `bin/omamac`, `install.sh`, `update.sh`, `boot.sh` or `bin/omamac-terminal` outside bats or a test VM; never source `.bats` files outside bats; never run `brew install/uninstall/upgrade`, `defaults write`, `killall Dock` or `sudo` on this Mac. Tests run as `(trap '' PIPE; bats test/)`, and the `1..N` count must match the `ok` count.

- [x] 1. `lib/configure.sh`: `configure_run [<setting> [on|off]]`, its menu, on (save, then `settings_apply <answer>`) and off (today's `remove_setting`/`remove_dock`, question optional). `settings_apply` takes optional answers. `bin/omamac` sources it and dispatches `configure`. Tests first in `test/configure.bats`. Move the setting tests from `test/remove.bats` there.
- [x] 2. `install` and `uninstall` are software only. `add_section` loses `macos`, and `ADD_KEYS` loses the five settings. Setting names and `macos` are refused with the pointer line and exit 2. `remove_run` loses the setting rows and names. `add_command` gives `omamac configure <setting>`. Update `dock.sh`'s fix line. Tests in `test/add.bats`, `test/remove.bats`, `test/update.bats` and `test/doctor.bats`.
- [x] 3. Section menus. `add_run` with no arguments asks the section, then the Apps group. `remove_run` with no name asks the section, skipping the menu when there is one. Tests in `test/add.bats` and `test/remove.bats`.
- [x] 4. Top-level menu in `lib/menu.sh`: `omamac` with no arguments in the terminal look runs the pick with `exec`, and prints the usage text otherwise. The usage text adds `configure`. Tests in `test/omamac.bats`.
- [x] 5. VM fixtures: `desktop`, `dock` and `full` steps use `configure … off`, and `desktop` also checks `configure window-margins on`. Docs: `docs/commands.md`, README, updating, uninstalling, vision.
- [ ] 6. Shellcheck, full bats, a fresh-eyes review of the whole branch, VM runs `bare`, `desktop`, `dock` and `full` (two at a time, a minute apart), PR, merge, tag `v0.2.0`, release, close #60.
