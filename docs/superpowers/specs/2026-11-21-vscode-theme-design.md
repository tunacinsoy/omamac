# VS Code follows the theme: design

Status: draft · 2026-11-21 · Issue [#39](https://github.com/tunacinsoy/omamac/issues/39) · Source of truth for the why: [`vision.md`](../../../vision.md) (Decisions log, 2026-11-21)

## Intent

On the used-Mac run before Gate B, the terminal and neovim followed `omamac theme` and VS Code didn't. Tuna asked for VS Code to follow too, as it does in omawsl.

## The idea

omamac installs a small VS Code extension of its own, `omamac.omamac-theme`. It holds one colour theme, named `omamac`, with the chosen theme's colours, and it makes `omamac` VS Code's default theme (`contributes.configurationDefaults`). omamac never writes the user's `settings.json`.

Checked on 2026-11-21 with VS Code 1.147 in throwaway `--user-data-dir` and `--extensions-dir` folders:

- `code --install-extension omamac-theme.vsix` installs it. The `.vsix` is a zip holding only `extension/package.json` and `extension/themes/omamac.json`.
- With no `workbench.colorTheme` in `settings.json`, VS Code opens in the `omamac` theme (Tokyo Night's `#1a1b26` background). No `settings.json` is written.
- After a reinstall with Catppuccin's colours, an open window keeps the old colours. The next time VS Code opens, it shows Catppuccin.
- A `workbench.colorTheme` the user set, in a `settings.json` with comments, wins at once.
- VS Code copies the theme file as it is (`cmp` equal), but rewrites its own copy of `package.json`.
- A reinstall takes under a second.

## Approach

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| How the colours reach VS Code | omamac's own extension, which sets the default theme | No write to the user's `settings.json`, so no JSON-with-comments editing, and a theme the user picked wins by itself. Dropped: omawsl's merge into `settings.json` (a lot of careful code; a broken file breaks the editor), and marketplace theme extensions (someone else's colours and code). |
| Where the colours come from | `themes/<id>/vscode.json`, rendered once from omawsl's `vscode-theme.json.tpl` (Omarchy's, MIT) and its `vscode-palette.json` | The same way each `ghostty.conf` was converted once. The 13 backgrounds equal the Ghostty ones (a test checks this). Dropped: rendering at run time (more code; the result never changes between runs). |
| When it is installed | After the apps, on every run and every `omamac theme`, only when VS Code is installed | `code` is in the app (`Visual Studio Code.app/Contents/Resources/app/bin/code`), so it works for a VS Code omamac didn't install too. |
| A second run | Skipped when the installed `themes/omamac.json` equals the chosen theme's file | Runs stay idempotent. `package.json` can't be compared, because VS Code rewrites it. |
| Light or dark | `uiTheme` is `vs` for a light theme (`"type": "light"`), else `vs-dark` | VS Code bases the colours omamac's file doesn't set on it. rose-pine is the one light theme. |
| The user's own theme | Kept; omamac says so, as for starship and btop | `"workbench.colorTheme"` in `~/Library/Application Support/Code/User/settings.json` |
| An open VS Code | Shows the new theme the next time it opens, like neovim | The CLI can't reload a running window. |
| Uninstall | `omamac uninstall vscode`'s "Also remove" removes `~/.vscode`, the extension with it | The cask's zap already lists it. |
| Doctor | One line when VS Code is installed: ok, info (own theme), or fail with `omamac update` | |

## Done when

- bats passes, with tests for the install, the skip, the light theme, the user's own theme, a missing VS Code, a failed install, the theme command and doctor.
- The `apps` VM run checks the extension is installed with the chosen theme's file. `bare` passes (no VS Code, nothing happens).
- Gate B: on the real Mac, VS Code opens in omamac's theme and follows `omamac theme` the next time it opens.
- README, vision and CONTRIBUTING say it.
