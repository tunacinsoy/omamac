# What it changes

Every file, tool and setting omamac touches on your Mac, and how.

[← Back to the README](../README.md)

## Installed with Homebrew

- Homebrew, in `/opt/homebrew`. It brings Apple's Command Line Tools.
- Ghostty, installed with Homebrew (a cask). A Ghostty you installed by hand is used as is and not updated; `omamac doctor` shows the command that lets Homebrew take it over.
- bash, gum and the core tools (`starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq`), installed with Homebrew.
- The cloud CLIs you chose (Azure, AWS, Google Cloud, GitHub, Terraform), installed with Homebrew. Terraform comes from `hashicorp/tap`.
- The coding agents you chose (Claude Code, Codex CLI, Copilot CLI, Antigravity CLI, opencode), installed with Homebrew.

## Your apps

The apps you chose, installed with Homebrew (casks) in Applications.

- **An app you installed by hand:** if you chose it, omamac asks "Let Homebrew take over …?" (Enter alone is no).
  - Yes keeps the app where it is, and Homebrew updates it from then on.
  - No leaves it as it is and drops it from your picks.
- A Zoom or Google Drive you installed by hand is left alone and dropped, since Homebrew would install it again.
- For an app you install by hand later, `omamac doctor` and each run show the command.
- Zoom and Google Drive run an installer, so Homebrew asks for your password; omamac says so first.
- Google Drive also brings Google Docs, Sheets and Slides.
- VS Code, Obsidian, VLC and Firefox add a command to `/opt/homebrew/bin`, such as `code`.

## Languages

- The languages you chose (Ruby on Rails, Node.js, Go, Python, Elixir, Rust, Java), installed with mise.
- `~/.config/mise/conf.d/omamac.toml`: the languages, written by omamac again on every run. Your own pins in `~/.config/mise/config.toml` win and are never touched.

## Lines in your own files

- One line in `~/.zprofile` (skipped if it already sets up Homebrew) and one in `~/.zshrc`. Both end in `# added by omamac`.
- One line in a Ghostty config file: `config-file = ?~/.config/omamac/ghostty.conf`.
  - It goes in the last of Ghostty's four config files that exists, or in a new `~/.config/ghostty/config.ghostty`.
  - If one of them already has it, nothing is added.
- `~/.config/nvim`: LazyVim's starter, only if you don't have one. Yours is kept. If omamac made it, it holds `lua/plugins/omamac.lua`.

## omamac's own folders

- `~/.local/share/omamac`: omamac itself.
- `~/.config/omamac`: files omamac writes (below).
- `~/.local/state/omamac`:
  - logs;
  - your saved answers (`choices.env`);
  - `macos-settings.tsv`: the earlier value of each macOS setting omamac changed;
  - `colima-service`: tells omamac it already started colima's service;
  - `dock-before.plist`: the Dock from before the cleanup;
  - `dock-added`: the apps omamac has put in, or found in, the Dock. It never adds them again, so a tile you remove stays gone.

## The shell: zshrc

`~/.config/omamac/zshrc` holds aliases, history, completion, mise and the starship prompt. The line in `~/.zshrc` loads it.

It takes over:

- EDITOR and VISUAL (nvim);
- history sizes (raised, never lowered);
- ↑/↓ history search, and Ctrl-R (fzf);
- the prompt (starship);
- the aliases `ls`, `lsa`, `ll`, `lt`, `lta`, `tree`, `cat`, `cd`, `ff`, `..`, `...`, `....`, `g`, `gcm`, `gcam`, `gcad`, `d`, `lzg`, `lzd`, `n` and `r`.

It also:

- sets `HERDR_CONFIG_PATH` when you have no herdr config;
- sets `STARSHIP_CONFIG` to omamac's `starship.toml`, only if you have no `~/.config/starship.toml` (and no `STARSHIP_CONFIG` of your own);
- aliases `btop` to use omamac's `btop.conf` and themes, only if you have no `~/.config/btop/btop.conf`.

If you do have your own file, it is kept and never written, and the theme doesn't reach that tool.

## herdr

`~/.config/omamac/herdr.toml`: omamac's herdr config and key bindings. A `~/.config/herdr/config.toml` of your own is used instead and never touched (one holding only `onboarding = false` is herdr's own and doesn't count). See [herdr](herdr.md).

## Ghostty

`~/.config/omamac/ghostty.conf` is written again on every run. It takes over five Ghostty settings:

1. its colours (your theme);
2. `command` (starts herdr);
3. `macos-option-as-alt` (left);
4. the keys Option ←/→, which Ghostty would turn into a word back or on. They go to herdr instead, to move to the pane or tab on that side;
5. Cmd D / Cmd Shift D, which do nothing: a Ghostty split would show the same herdr session twice. herdr splits with Alt n or Ctrl g p.

Ghostty loads the included file after the rest of your config, wherever the line sits, so these win over the same settings in your own files.

## Theme files

In `~/.config/omamac`, written again on every run and every `omamac theme`:

- `ghostty.conf`;
- `herdr.toml`;
- `starship.toml` (the prompt);
- `btop.conf` with `btop-themes/<theme>.theme`;
- `neovim.lua` (loaded by `~/.config/nvim/lua/plugins/omamac.lua`).

## VS Code

If VS Code is installed: omamac's theme extension, `omamac.omamac-theme`, in `~/.vscode/extensions/omamac.omamac-theme-1.0.0`, written again whenever the theme changes.

- If VS Code has already run on this Mac and doesn't list it yet, omamac installs it once with VS Code's `code --install-extension`.
- `omamac uninstall vscode` removes it with the rest of `~/.vscode` when you say yes to removing the app's data too.
- Disabling it in VS Code's Extensions view lasts. Removing it there doesn't, since the next run installs it again.

See [Themes](themes.md#vs-code).

## Docker

**If you chose colima:**

- `colima docker docker-compose docker-buildx lazydocker`, installed with Homebrew.
- Two links in `~/.docker/cli-plugins`, `docker-compose` and `docker-buildx`, to Homebrew's plugins, so `docker compose` and `docker buildx` work.
  - A file of yours there is kept.
  - A link of yours that points at nothing, such as one Docker Desktop left, is kept too, and omamac says to remove it.
- colima's login service, started once with `brew services start colima`. To stop colima starting at login: `brew services stop colima`. omamac won't start it again.

**If you chose Docker Desktop:** the `docker-desktop` cask and `lazydocker`, installed with Homebrew. Homebrew asks for your password for the cask's links in `/usr/local`; omamac says so first.

## macOS settings

Only for the answers you chose, written with `defaults`, and the Dock restarted once when a Dock or desktop setting changed.

**Desktops as workspaces:**

- `com.apple.dock mru-spaces` (off, so Spaces keep their order);
- `NSGlobalDomain AppleSpacesSwitchOnActivate` (on, so switching to an app goes to its desktop);
- Mission Control's "Switch to Desktop 1" to "6" shortcuts set to Ctrl 1 to Ctrl 6 (`com.apple.symbolichotkeys AppleSymbolicHotKeys` 118 to 123, made to take effect without a logout; they work for the desktops you have);
- Reduce motion (`com.apple.universalaccess reduceMotion` and `com.apple.Accessibility ReduceMotionEnabled`, both on). macOS may refuse Reduce motion; omamac then leaves it alone and tells you to turn it on in System Settings.

**Window margins:** `com.apple.WindowManager EnableTiledWindowMargins` (on).

**Desktop widgets:** `com.apple.WindowManager StandardHideWidgets` and `StageManagerHideWidgets` (both on, so widgets are hidden on the desktop and in Stage Manager).

**Dock auto-hide:** `com.apple.dock autohide` (on).

**Tap to click:** `Clicking` (on) in `com.apple.AppleMultitouchTrackpad` (the built-in trackpad) and `com.apple.driver.AppleBluetoothMultitouch.trackpad` (a Magic Trackpad), and `com.apple.mouse.tapBehavior` (1) in this Mac's own `NSGlobalDomain` (`defaults -currentHost`), the three keys System Settings writes.

**Three-finger drag:** in both trackpad domains, what System Settings → Accessibility → Pointer Control → Trackpad Options writes for it: `TrackpadThreeFingerDrag` (on); `Dragging` (off, since tap-to-drag and three-finger drag are one choice); `TrackpadThreeFingerHorizSwipeGesture` and `TrackpadThreeFingerVertSwipeGesture` (0) and `TrackpadFourFingerHorizSwipeGesture` and `TrackpadFourFingerVertSwipeGesture` (2), so swiping between desktops and to Mission Control moves to four fingers.

omamac asks macOS to read the trackpad settings again straight away. If a tap doesn't click, or three fingers don't drag, log out and back in.

`omamac update` sets them again if you changed them; the first earlier value stays in `macos-settings.tsv`.

## Dock cleanup

If you chose it:

- Once, Apple's apps and Downloads leave the Dock; your own items stay.
- omamac's apps are added after them, and so is any app omamac installs later, but never one you took out.
- Suggested and recent apps turn off (`com.apple.dock show-recents`).
- The Dock from before is kept in `~/.local/state/omamac/dock-before.plist`.
