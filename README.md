# omamac

omamac sets up a fresh Mac for development in one command: Homebrew, a modern bash, your terminal, editor, apps and theme. After that, one command, `omamac`, keeps it all up to date. It is the sister project of [omawsl](https://github.com/tunacinsoy/omawsl).

omamac is still being built. Today the one-liner installs Homebrew, bash, gum and the `omamac` command (with `omamac doctor`).

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

omamac asks for your password once and never stores it. Allow about 10 minutes, mostly for Apple's Command Line Tools. If it stops, fix what it says and run the same line again; it picks up where it stopped.

Each run writes a log to `~/.local/state/omamac/logs/`. The newest 10 are kept.

## After install

Open a new terminal window.

## What it changes

- Homebrew, in `/opt/homebrew`. It brings Apple's Command Line Tools.
- bash and gum, installed with Homebrew.
- One line in `~/.zprofile` (skipped if it already sets up Homebrew) and one in `~/.zshrc`. Both end in `# added by omamac`.
- `~/.local/share/omamac`: omamac itself.
- `~/.config/omamac`: files omamac writes.
- `~/.local/state/omamac`: logs.

There is no uninstall command yet. To undo by hand: delete the two lines ending in `# added by omamac`, delete the three folders, and, if omamac installed them, run `brew uninstall gum bash`. To remove Homebrew too, see [Uninstall Homebrew](https://github.com/Homebrew/install#uninstall-homebrew).

## Testing a branch

For contributors. Put the branch in the URL and in `OMAMAC_REF`:

```
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/<branch>/boot.sh | OMAMAC_REF=<branch> bash
```
