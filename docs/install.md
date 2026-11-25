# Installing omamac

What happens when you paste the one-liner, step by step.

[← Back to the README](../README.md)

## Before you begin

- A Mac with Apple Silicon, on macOS 27 or later.
- Setup Assistant finished.
- An administrator account.
- macOS up to date.
- An internet connection.
- If this Mac has anything on it you care about, back it up first.

## Run it

Open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/main/boot.sh | bash
```

## What every Mac gets

No question asked:

- Ghostty, the terminal, which opens straight into herdr, the multiplexer.
- zsh with the starship prompt, aliases, history search and fzf.
- neovim with LazyVim, btop, mise, eza, bat, zoxide, ripgrep, fd, lazygit, tree-sitter-cli and jq.
- One theme for Ghostty, herdr, btop, the prompt, neovim and VS Code, switched with `omamac theme`.

Everything else is asked first, and only what you pick is installed. Nothing is picked for you:

- desktop apps (AI apps among them) and Wispr Flow;
- languages, cloud CLIs and coding agents for the terminal;
- Docker (colima or Docker Desktop);
- seven macOS settings: desktops as workspaces, window margins, desktop widgets, Dock cleanup, Dock auto-hide, Tap to click, tap to drag.

Tools and apps come from Homebrew; languages come from mise.

## Your password

- omamac asks for your password once and never stores it.
- The exception: if you chose Zoom, Google Drive or Docker Desktop, Homebrew asks for your password once more, right after "Install?", once for all of them.
- It asks once they are downloaded, so stay at the keyboard until it has asked.

## The questions

It asks about: theme, apps, macOS settings, languages and Docker.

| Key | At a list | At a yes/no question |
| --- | --- | --- |
| Arrows | move | |
| x or Tab | pick | |
| y or n | | answer |
| Enter | go on | go on |
| Esc | stops omamac, like Ctrl-C | no |

Then it shows your answers and asks "Install?". After that it runs on its own.

- Answer no to "Install?" and nothing is saved, so the next run asks again.
- Once you've said yes, your answers are kept, and later runs only ask "Install?".

## What you see

- Your answers, as a sheet.
- One row per stage, with its count: `3/9 ✓ Core tools  15 installed`.
- A green Done box: what it installed, what to do next, and the log.
- A sheet of the permissions to allow (see [After install](after-install.md)).

If a run stops:

- its row turns into a red ✗;
- a red Stopped box says what it was doing, how to fix it, where the log is, and the log's last lines.

Every command looks this way, in the terminal's own 16 colours, so it follows your theme. Piped or saved to a file, omamac prints plain text instead.

## How long it takes

- Allow 10 to 20 minutes, depending on how much you pick.
- Most of it is Apple's Command Line Tools and your apps' downloads.

## If it stops, or you run it again

- Fix what it says and run the same line again. It picks up where it stopped.
- Running it again on a Mac that is set up updates omamac's code and changes nothing else.

## Logs

Each run writes a log to `~/.local/state/omamac/logs/`. The newest 10 are kept.
