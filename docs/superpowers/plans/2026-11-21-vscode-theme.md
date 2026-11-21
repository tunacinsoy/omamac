# VS Code follows the theme: plan

Spec: [`2026-11-21-vscode-theme-design.md`](../specs/2026-11-21-vscode-theme-design.md). Branch `vscode-theme`, one PR.

- [x] 1. `themes/<id>/vscode.json` for the 13 themes, rendered once from omawsl. `test/themes.bats`: valid, named `omamac`, background equals Ghostty's.
- [x] 2. `lib/vscode.sh`: `vscode_theme_install` (build the `.vsix`, install, skip when equal, own-theme note), sourced by `bin/omamac`, `install.sh`, `update.sh`. Tests first in `test/vscode.bats`, with a fake `code` in the test Applications folder.
- [x] 3. Call it after `apps_install` in `apply_all` and after `theme_apply` in `theme_run`. Tests in `test/theme_cmd.bats` and the apply order.
- [x] 4. Doctor's VS Code line. Tests in `test/doctor.bats`.
- [x] 5. `apps.steps.sh` and `full.steps.sh` check the extension. README, CONTRIBUTING, vision.
- [ ] 6. Shellcheck, bats, review, VM runs `bare` and `apps`, PR.
