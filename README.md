# omamac

omamac sets up a fresh Mac for development in one command: Homebrew, a modern bash, your terminal, editor, apps and theme. After that, one command, `omamac`, keeps it all up to date. It is the sister project of [omawsl](https://github.com/tunacinsoy/omawsl).

omamac is still being built. Today the one-liner installs Homebrew, bash, gum, the `omamac` command and the core tools: starship, neovim with LazyVim, btop, mise, herdr, eza, bat, zoxide, fzf, ripgrep, fd, lazygit and tree-sitter-cli. It also asks the first-run questions and saves your answers, but your other picks (languages, cloud CLIs, apps and so on) aren't installed yet. `omamac doctor` and `omamac update` work; the other commands say "not available yet".

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

omamac asks for your password once and never stores it. Then it asks a few questions: theme, apps, macOS settings, languages and Docker. Nothing is chosen for you: press x or Tab to pick, Enter to go on. It shows your answers and asks "Install?"; after that it runs on its own. Answer no the first time and nothing is saved, so the next run asks again. Once you've said yes, your answers are kept and later runs only ask "Install?".

Allow about 10 minutes, mostly for Apple's Command Line Tools. If it stops, fix what it says and run the same line again; it picks up where it stopped.

Each run writes a log to `~/.local/state/omamac/logs/`. The newest 10 are kept.

## After install

Open a new terminal window. `nvim` downloads its plugins the first time it opens.

## Keeping it up to date

```
omamac update
```

It updates omamac and what omamac installed, nothing else. It pulls omamac (and stops if you edited its files), rewrites the files omamac writes, installs any core tool that is missing, then upgrades only omamac's formulas: the core tools, bash and gum. The log goes to `~/.local/state/omamac/logs/`.

## What it changes

- Homebrew, in `/opt/homebrew`. It brings Apple's Command Line Tools.
- bash, gum and the core tools (`starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli`), installed with Homebrew.
- `~/.config/nvim`: LazyVim's starter, only if you don't have one. Yours is kept. If omamac made it, it holds `lua/plugins/omamac.lua`.
- One line in `~/.zprofile` (skipped if it already sets up Homebrew) and one in `~/.zshrc`. Both end in `# added by omamac`.
- `~/.local/share/omamac`: omamac itself.
- `~/.config/omamac`: files omamac writes, including `zshrc` (aliases, history, completion, mise and the starship prompt), which the line in `~/.zshrc` loads.
- `~/.local/state/omamac`: logs and your saved answers (`choices.env`).

There is no uninstall command yet. To undo by hand: delete the two lines ending in `# added by omamac`, delete the three folders, delete `~/.config/nvim` if omamac made it (it holds `lua/plugins/omamac.lua`), and, if omamac installed them, run `brew uninstall gum bash starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli`. To remove Homebrew too, see [Uninstall Homebrew](https://github.com/Homebrew/install#uninstall-homebrew).

## Testing a branch

For contributors. Put the branch in the URL and in `OMAMAC_REF`:

```
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/<branch>/boot.sh | OMAMAC_REF=<branch> bash
```
