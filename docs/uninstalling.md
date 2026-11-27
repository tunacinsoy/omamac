# Uninstalling

Remove one thing you picked, or undo omamac by hand.

[← Back to the README](../README.md)

## omamac uninstall

`omamac uninstall <name>` removes one thing you picked, after asking. With no name, it asks which section (Apps, Languages, Cloud CLIs, Coding agents or Docker), then what in it.

A yellow Removes box shows what goes (the app, Homebrew's cask, its data only if you say yes) before the questions.

### Apps

`brave`, `chrome`, `firefox`, `whatsapp`, `telegram`, `signal`, `discord`, `slack`, `zoom`, `spotify`, `vlc`, `cap`, `dropbox`, `google-drive`, `vscode`, `claude`, `chatgpt`, `copilot`, `antigravity`, `raycast`, `obsidian`, `alt-tab` and `wispr-flow`.

- omamac first asks whether to remove the app's settings and data too. Enter alone is no; yes lets Homebrew delete what the app keeps in `~/Library`.
- Homebrew may ask for your password.
- An app Homebrew took over is removed like the others. One still installed by hand stays, and omamac only forgets your pick.
- With Dock cleanup on, the app's tile leaves the Dock. An app you installed by hand keeps its tile.

### Languages, cloud CLIs and coding agents

- **Languages:** `ruby` (with Rails), `node`, `go`, `python`, `elixir`, `rust` and `java`.
- **Cloud CLIs:** `azure`, `aws`, `gcloud`, `gh` and `terraform`.
- **Coding agents:** `claude-code`, `codex`, `copilot-cli`, `antigravity-cli` and `opencode`.
- A version another mise config uses stays, and Homebrew taps stay.

### macOS settings

Settings aren't uninstalled: turn them off with `omamac configure` (see [Keeping it up to date](updating.md#omamac-configure)).

- `omamac configure desktops off`, and the same for `window-margins`, `desktop-widgets`, `dock-autohide`, `tap-to-click` and `tap-to-drag`, puts the earlier values back.
- `omamac configure dock off` puts the Dock back to how it was before the cleanup. Changes you made to it since are undone, and suggested and recent apps come back.

### Docker

- `omamac uninstall colima` removes colima, its tools, links and service. Your Docker data stays in `~/.colima`.
- `omamac uninstall docker-desktop` removes the Docker Desktop app and lazydocker (a hand-installed app stays). Your images, containers and volumes stay, unless you say yes to removing its settings and data, which also deletes `~/.docker`.

## Changing an answer

To change an earlier answer, for example colima to Docker Desktop, uninstall one and install the other with `omamac install`.

## Removing omamac itself

**omamac can't remove itself or its core tools yet.** To undo the rest by hand, in Terminal (not Ghostty, which is removed):

1. Remove your picks with `omamac uninstall`, and turn the macOS settings off with `omamac configure`, while omamac is still there.
2. If omamac installed them: `brew uninstall gum bash starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq` and `brew uninstall --cask ghostty`.
3. Delete the two lines ending in `# added by omamac`, and the line naming `~/.config/omamac/ghostty.conf` from your Ghostty config.
4. Delete the three folders (`~/.config/omamac`, `~/.local/share/omamac`, `~/.local/state/omamac`) and `~/.config/mise/conf.d/omamac.toml`, and `~/.config/nvim` if omamac made it (it holds `lua/plugins/omamac.lua`).
5. If VS Code stays: `code --uninstall-extension omamac.omamac-theme`.

To remove Homebrew too, see [Uninstall Homebrew](https://github.com/Homebrew/install#uninstall-homebrew).
