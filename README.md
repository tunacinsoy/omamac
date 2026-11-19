# omamac

omamac sets up a fresh Mac for development in one command: Homebrew, a modern bash, your terminal, editor, apps, Docker and theme. After that, one command, `omamac`, keeps it all up to date. It is the sister project of [omawsl](https://github.com/tunacinsoy/omawsl).

omamac is still being built. Today the one-liner installs Homebrew, bash, gum, the `omamac` command and the core tools: Ghostty (which opens into herdr), starship, neovim with LazyVim, btop, mise, herdr, eza, bat, zoxide, fzf, ripgrep, fd, lazygit, tree-sitter-cli and jq. It asks the first-run questions, saves your answers, and installs the apps, languages, cloud CLIs and Docker (colima or Docker Desktop) you picked. It sets the desktop, window-margin and Dock settings you chose. `omamac install`, `uninstall`, `theme`, `doctor` and `update` work. `omamac theme [name]` switches the theme for Ghostty, herdr, btop, the prompt and neovim, and reloads what is running.

## Before you begin

- A Mac with Apple Silicon, on macOS 27 or later.
- Setup Assistant finished.
- An administrator account.
- macOS up to date.
- An internet connection.

## Install

Open Terminal and paste:

```
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/main/boot.sh | bash
```

omamac asks for your password once and never stores it. Then it asks a few questions: theme, apps, macOS settings, languages and Docker. Nothing is chosen for you: press x or Tab to pick, Enter to go on. It shows your answers and asks "Install?"; after that it runs on its own. The exception: if you chose Zoom, Google Drive or Docker Desktop, Homebrew asks for your password once more, right after "Install?", once for all of them. It asks once they are downloaded, so stay at the keyboard until it has asked. It may ask again when `omamac update` upgrades one of them and when you uninstall an app. Answer no the first time and nothing is saved, so the next run asks again. Once you've said yes, your answers are kept and later runs only ask "Install?".

Allow about 10 minutes, mostly for Apple's Command Line Tools. If it stops, fix what it says and run the same line again; it picks up where it stopped.

Each run writes a log to `~/.local/state/omamac/logs/`. The newest 10 are kept.

## After install

Open Ghostty. It starts herdr. The first time, macOS asks you to confirm; click Open. `nvim` downloads its plugins the first time it opens.

If you chose Desktops as workspaces, give an app its own desktop: right-click its Dock icon, then Options, then Assign To. Reduce motion may need one click: macOS can refuse the setting, and omamac then says so; search for Reduce motion in System Settings and turn it on.

The first time you open each app, macOS asks you to confirm; click Open. Some apps need a permission, in System Settings → Privacy & Security:

- Cap: allow Screen Recording, and Camera and Microphone if you use them.
- Wispr Flow: allow Microphone and Accessibility.
- Zoom: allow Camera and Microphone, and Screen Recording to share.

If you chose Docker Desktop, open it once to finish its setup.

To let `omamac update` upgrade Ghostty, Docker Desktop and your apps, and `omamac uninstall` remove them, allow App Management for your terminal (Ghostty): System Settings → Privacy & Security → App Management. Zoom and Google Drive don't need it: Homebrew changes them with your password.

## Keeping it up to date

```
omamac update
```

It updates omamac and what omamac installed, nothing else. It pulls omamac (and stops if you edited its files), rewrites the files omamac writes, puts back any core tool, app, language or cloud CLI that is missing, puts back the macOS settings you chose if you changed them, then upgrades only what omamac installed: the core tools, Ghostty, Docker Desktop and your apps (only if your terminal has App Management; otherwise update says what to click and exits 1. Apps update themselves, so omamac upgrades one only when Homebrew lists it as outdated), bash, gum, the cloud CLIs you chose (Google Cloud's cask with `--greedy`), colima and its tools if you chose it, and the languages you chose. After that, `mise prune` deletes versions of those languages that no mise config uses, such as one you installed with `mise install node@18`. The log goes to `~/.local/state/omamac/logs/`.

## What it changes

- Homebrew, in `/opt/homebrew`. It brings Apple's Command Line Tools.
- Ghostty, installed with Homebrew (a cask). A Ghostty you installed by hand is used as is and not updated; `omamac doctor` shows the command that lets Homebrew take it over.
- The apps you chose, installed with Homebrew (casks) in Applications. If you chose an app you installed by hand, omamac asks "Let Homebrew take over …?" (Enter alone is no). Yes keeps the app where it is, and Homebrew updates it from then on; no leaves it as it is and drops it from your picks. A Zoom or Google Drive you installed by hand is left alone and dropped, since Homebrew would install it again. For an app you install by hand later, `omamac doctor` and each run show the command. Zoom and Google Drive run an installer, so Homebrew asks for your password; omamac says so first. Google Drive also brings Google Docs, Sheets and Slides. VS Code, Obsidian, VLC and Firefox add a command to `/opt/homebrew/bin`, such as `code`.
- bash, gum and the core tools (`starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq`), installed with Homebrew.
- The languages you chose (Ruby on Rails, Node.js, Go, Python, Elixir, Rust, Java), installed with mise, and the cloud CLIs you chose (Azure, AWS, Google Cloud, GitHub, Terraform), installed with Homebrew. Terraform comes from `hashicorp/tap`.
- `~/.config/mise/conf.d/omamac.toml`: the languages, written by omamac again on every run. Your own pins in `~/.config/mise/config.toml` win and are never touched.
- `~/.config/nvim`: LazyVim's starter, only if you don't have one. Yours is kept. If omamac made it, it holds `lua/plugins/omamac.lua`.
- One line in `~/.zprofile` (skipped if it already sets up Homebrew) and one in `~/.zshrc`. Both end in `# added by omamac`.
- `~/.local/share/omamac`: omamac itself.
- `~/.config/omamac`: files omamac writes, including `zshrc` (aliases, history, completion, mise and the starship prompt), which the line in `~/.zshrc` loads. That file takes over EDITOR and VISUAL (nvim), history sizes (raised, never lowered), ↑/↓ history search, Ctrl-R (fzf), the prompt (starship), and the aliases `ls`, `lsa`, `ll`, `lt`, `lta`, `tree`, `cat`, `cd`, `ff`, `..`, `...`, `....`, `g`, `gcm`, `gcam`, `gcad`, `d`, `lzg`, `lzd`, `n` and `r`. It also sets `HERDR_CONFIG_PATH` when you have no herdr config.
- `~/.config/omamac/herdr.toml`: omawsl's herdr config and key bindings. A `~/.config/herdr/config.toml` of your own is used instead and never touched (one holding only `onboarding = false` is herdr's own and doesn't count).
- One line in a Ghostty config file: `config-file = ?~/.config/omamac/ghostty.conf`. It goes in the last of Ghostty's four config files that exists, or in a new `~/.config/ghostty/config.ghostty`. If one of them already has it, nothing is added. If you installed omamac before Ghostty joined, run the one-liner again to get the line.
- `~/.config/omamac/ghostty.conf`: written again on every run. It takes over three Ghostty settings: its colours (your theme), `command` (starts herdr) and `macos-option-as-alt` (left). Ghostty loads the included file after the rest of your config, wherever the line sits, so these win over the same settings in your own files.
- Theme files in `~/.config/omamac`, written again on every run and every `omamac theme`: `ghostty.conf`, `herdr.toml`, `starship.toml` (the prompt), `btop.conf` with `btop-themes/<theme>.theme`, and `neovim.lua` (loaded by `~/.config/nvim/lua/plugins/omamac.lua`).
- `zshrc` sets `STARSHIP_CONFIG` to omamac's `starship.toml` and aliases `btop` to use omamac's `btop.conf` and themes. It does each only if you have no `~/.config/starship.toml` or `~/.config/btop/btop.conf` (and no `STARSHIP_CONFIG` of your own). If you do, your file is kept and never written, and the theme doesn't reach that tool.
- `~/.local/state/omamac`: logs, your saved answers (`choices.env`), `macos-settings.tsv` (the earlier value of each macOS setting omamac changed) and `colima-service`, which tells omamac it already started colima's service.
- If you chose colima: `colima docker docker-compose docker-buildx lazydocker`, installed with Homebrew; two links in `~/.docker/cli-plugins`, `docker-compose` and `docker-buildx`, to Homebrew's plugins, so `docker compose` and `docker buildx` work (a file of yours there is kept; a link of yours that points at nothing, such as one Docker Desktop left, is kept too, and omamac says to remove it); and colima's login service, started once with `brew services start colima`. To stop colima starting at login: `brew services stop colima`. omamac won't start it again.
- If you chose Docker Desktop: the `docker-desktop` cask and `lazydocker`, installed with Homebrew. Homebrew asks for your password for the cask's links in `/usr/local`; omamac says so first.
- macOS settings, only for the answers you chose, written with `defaults` and the Dock restarted once. Desktops as workspaces: `com.apple.dock mru-spaces` (off, so Spaces keep their order), `NSGlobalDomain AppleSpacesSwitchOnActivate` (on, so switching to an app goes to its desktop), and Reduce motion (`com.apple.universalaccess reduceMotion` and `com.apple.Accessibility ReduceMotionEnabled`, both on). Window margins: `com.apple.WindowManager EnableTiledWindowMargins` (on). macOS may refuse Reduce motion; omamac then leaves it alone and tells you to turn it on in System Settings. Dock auto-hide: `com.apple.dock autohide` (on). `omamac update` sets them again if you changed them; the first earlier value stays in `macos-settings.tsv`.
- Dock cleanup, if you chose it: once, Apple's apps and Downloads leave the Dock; your own items stay. omamac's apps are added after them, and so is any app omamac installs later, but never one you took out. Suggested and recent apps turn off (`com.apple.dock show-recents`). The Dock from before is kept in `~/.local/state/omamac/dock-before.plist`.

`omamac install` adds the apps, languages and cloud CLIs you didn't pick before, and asks again the four settings you answered no (desktops, window margins, Dock cleanup, Dock auto-hide) and the Docker question if you answered No Docker. `omamac uninstall <name>` removes one, after asking; a version another mise config uses stays, and Homebrew taps stay. The apps' names are `brave`, `chrome`, `firefox`, `whatsapp`, `telegram`, `signal`, `discord`, `slack`, `zoom`, `spotify`, `vlc`, `cap`, `dropbox`, `google-drive`, `vscode`, `raycast`, `obsidian` and `wispr-flow`. For an app it first asks whether to remove its settings and data too; Enter alone is no, and yes lets Homebrew delete what the app keeps in `~/Library`. Homebrew may ask for your password. An app Homebrew took over is removed like the others; one still installed by hand stays, and omamac only forgets your pick. `omamac uninstall desktops`, `omamac uninstall window-margins` and `omamac uninstall dock-autohide` put the earlier values back and turn the answer to no. `omamac uninstall dock` puts the Dock back to how it was before the cleanup; changes you made to it since are undone, and suggested and recent apps come back. With Dock cleanup on, uninstalling an app takes its tile out of the Dock; an app you installed by hand keeps its tile. `omamac uninstall colima` removes colima, its tools, links and service; your Docker data stays in `~/.colima`. `omamac uninstall docker-desktop` removes the Docker Desktop app and lazydocker (a hand-installed app stays); your images, containers and volumes stay unless you say yes to removing its settings and data, which also deletes `~/.docker`.

`omamac uninstall` removes your picks one at a time. For the rest, undo by hand: delete the two lines ending in `# added by omamac`, delete the line naming `~/.config/omamac/ghostty.conf` from your Ghostty config, delete the three folders (`~/.config/omamac` holds `starship.toml`, `btop.conf`, `btop-themes` and `neovim.lua` too) and `~/.config/mise/conf.d/omamac.toml`, put the macOS settings back with `omamac uninstall desktops`, `omamac uninstall window-margins`, `omamac uninstall dock` and `omamac uninstall dock-autohide`, delete `~/.config/nvim` if omamac made it (it holds `lua/plugins/omamac.lua`), and, if omamac installed them, run `brew uninstall gum bash starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq`, and `brew uninstall --cask ghostty`. To remove Homebrew too, see [Uninstall Homebrew](https://github.com/Homebrew/install#uninstall-homebrew).

## Themes

`omamac theme [<theme>]` saves a theme, applies it and reloads Ghostty, herdr and btop if they are running. The themes are `catppuccin`, `dracula`, `everforest`, `gruvbox`, `kanagawa`, `matte-black`, `nord`, `one-dark`, `osaka-jade`, `ristretto`, `rose-pine`, `solarized` and `tokyo-night`. Without a name it asks.

btop: settings you save from btop's menu go into omamac's `btop.conf` and don't last, because omamac writes it again. Running `/opt/homebrew/bin/btop` without the alias makes btop write its own config in `~/.config/btop`, which then takes over from omamac's.

neovim: if you have your own `~/.config/nvim`, omamac leaves it alone, and `omamac doctor` offers to move it aside to `~/.config/nvim.bak-<date>` so LazyVim and the theme can be set up.

## herdr

Ghostty starts it for you; or run `herdr`. Ctrl g is the prefix, then `p` pane, `t` tab, `r` resize, `m` move, `o` session, `s` scroll. Alt h/j/k/l move between panes, Alt n opens a new pane.

herdr's first-run screen is skipped.

> **omamac handles herdr's settings.** It writes `~/.config/omamac/herdr.toml` again on every update (and every theme switch), so herdr always follows omamac's theme and key bindings. Changes made in herdr's own settings screen (Ctrl g `,`) or by hand to that file don't last. To use your own herdr config instead, write `~/.config/herdr/config.toml`: omamac never touches it, but then omamac's themes and key bindings don't reach herdr, and `omamac doctor` says so.

## Testing a branch

For contributors. Put the branch in the URL and in `OMAMAC_REF`:

```
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/<branch>/boot.sh | OMAMAC_REF=<branch> bash
```
