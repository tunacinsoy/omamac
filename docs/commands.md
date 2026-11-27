# Commands

Which command to run for what you want to change. You don't need to remember any of these: type `omamac` and it asks what you want, and each command asks what it needs when you name nothing after it.

[← Back to the README](../README.md)

## Which one?

| You want to… | Run | Or, if you know the name |
| --- | --- | --- |
| Not sure | `omamac` | |
| Add an app, language, cloud CLI, coding agent or Docker | `omamac install` | `omamac install go`, `omamac install languages` |
| Remove one of those | `omamac uninstall` | `omamac uninstall vlc` |
| Turn a macOS setting on or off | `omamac configure` | `omamac configure dock-autohide off` |
| Change the look | `omamac theme` | `omamac theme nord` |
| Make the terminal text bigger or smaller | `omamac font-size` | `omamac font-size 16` |
| Get the latest omamac, tools and apps | `omamac update` | |
| Check that everything is healthy | `omamac doctor` | `omamac doctor --all` |

`install` and `uninstall` are for software. `configure` is for macOS settings.

## omamac

With nothing after it, `omamac` asks what you want to do (install, remove, change a setting, switch the theme, update or check) and runs that command. Piped or in a script, it prints the usage text instead. `omamac help` always prints it.

## omamac install

With no name, it asks which section (only the ones with something left to add), and for Apps which group. Then it asks that one question, shows what it adds, and asks "Install?". See [Keeping it up to date](updating.md#omamac-install).

**Sections:** `apps`, `languages`, `cloud-clis`, `coding-agents` and `docker`. `omamac install apps` asks every app group, and sections can be mixed: `omamac install languages cloud-clis`.

**Names** (they ask nothing but "Install?", and several can go in one run):

- **Apps:** `brave`, `chrome`, `firefox`, `whatsapp`, `telegram`, `signal`, `discord`, `slack`, `zoom`, `spotify`, `vlc`, `cap`, `dropbox`, `google-drive`, `vscode`, `claude`, `chatgpt`, `copilot`, `antigravity`, `raycast`, `obsidian` and `wispr-flow`.
- **Languages:** `ruby` (with Rails), `node`, `go`, `python`, `elixir`, `rust` and `java`.
- **Cloud CLIs:** `azure`, `aws`, `gcloud`, `gh` and `terraform`.
- **Coding agents:** `claude-code`, `codex`, `copilot-cli`, `antigravity-cli` and `opencode`.
- **Docker:** `colima` or `docker-desktop`, one of the two.

## omamac uninstall

With no name, it asks which section (only the ones with something omamac installed), then what in it, with Nothing first. It takes the same names as `install` (not the sections), one at a time. See [Uninstalling](uninstalling.md).

## omamac configure

With no name, it lists the seven settings, each with whether it's on or off. Pick one, and it shows what changes and asks "Turn on …?" or "Turn off …?".

`omamac configure <setting>` asks only about that one. `omamac configure <setting> on` or `off` asks nothing.

- `desktops`: desktops keep their order, switching to an app goes to its desktop, Ctrl 1–6 jump to desktops 1 to 6, and Reduce motion turns on. [What it changes](what-it-changes.md#macos-settings)
- `window-margins`: tiled windows get margins between them. [What it changes](what-it-changes.md#macos-settings)
- `desktop-widgets`: widgets leave the desktop and Stage Manager. [What it changes](what-it-changes.md#macos-settings)
- `dock`: Apple's apps and Downloads leave the Dock (not your Mac), the apps omamac installs take their place, and suggested and recent apps turn off. Off puts your Dock back as it was before the cleanup, and changes you made to it since are undone. [What it changes](what-it-changes.md#dock-cleanup)
- `dock-autohide`: the Dock hides when you're not using it. [What it changes](what-it-changes.md#macos-settings)
- `tap-to-click`: a tap on the trackpad clicks. [What it changes](what-it-changes.md#macos-settings)
- `tap-to-drag`: a double tap on the trackpad, finger kept down on the second tap, drags; lifting it drops (dragging without Drag Lock). [What it changes](what-it-changes.md#macos-settings)

Off puts back the values you had before omamac changed them.

## omamac theme

With no name, it lists the 13 themes. `omamac theme nord` switches straight away. See [Themes](themes.md).

## omamac font-size

With no size, it lists 10 to 20, with a hint next to some for where each suits, and Default. `omamac font-size 16` sets it straight away; `omamac font-size default` goes back to Ghostty's own size, or the one in your own Ghostty config. Open Ghostty windows change at once.

## omamac update and omamac doctor

`omamac update` asks nothing. `omamac doctor` checks, and `omamac doctor --all` shows every check and where it lives. See [Keeping it up to date](updating.md).
