# omamac

omamac sets up a fresh Mac for development in one command: Homebrew, a modern bash, your terminal, editor, apps and theme. After that, one command, `omamac`, keeps it all up to date. It is the sister project of [omawsl](https://github.com/tunacinsoy/omawsl).

omamac is still being built. Today the one-liner installs Homebrew, bash, gum, the `omamac` command and the core tools: starship, neovim with LazyVim, btop, mise, herdr, eza, bat, zoxide, fzf, ripgrep, fd, lazygit, tree-sitter-cli and jq. It asks the first-run questions, saves your answers, and installs the languages and cloud CLIs you picked. Apps, Docker and macOS settings come later. `omamac install`, `uninstall`, `doctor` and `update` work; `omamac theme` says "not available yet".

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

It updates omamac and what omamac installed, nothing else. It pulls omamac (and stops if you edited its files), rewrites the files omamac writes, puts back any core tool, language or cloud CLI that is missing, then upgrades only what omamac installed: the core tools, bash, gum, the cloud CLIs you chose (Google Cloud's cask with `--greedy`) and the languages you chose. After that, `mise prune` deletes versions of those languages that no mise config uses, such as one you installed with `mise install node@18`. The log goes to `~/.local/state/omamac/logs/`.

## What it changes

- Homebrew, in `/opt/homebrew`. It brings Apple's Command Line Tools.
- bash, gum and the core tools (`starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq`), installed with Homebrew.
- The languages you chose (Ruby on Rails, Node.js, Go, Python, Elixir, Rust, Java), installed with mise, and the cloud CLIs you chose (Azure, AWS, Google Cloud, GitHub, Terraform), installed with Homebrew. Terraform comes from `hashicorp/tap`.
- `~/.config/mise/conf.d/omamac.toml`: the languages, written by omamac again on every run. Your own pins in `~/.config/mise/config.toml` win and are never touched.
- `~/.config/nvim`: LazyVim's starter, only if you don't have one. Yours is kept. If omamac made it, it holds `lua/plugins/omamac.lua`.
- One line in `~/.zprofile` (skipped if it already sets up Homebrew) and one in `~/.zshrc`. Both end in `# added by omamac`.
- `~/.local/share/omamac`: omamac itself.
- `~/.config/omamac`: files omamac writes, including `zshrc` (aliases, history, completion, mise and the starship prompt), which the line in `~/.zshrc` loads. That file takes over EDITOR and VISUAL (nvim), history sizes (raised, never lowered), ↑/↓ history search, Ctrl-R (fzf), the prompt (starship), and the aliases `ls`, `lsa`, `ll`, `lt`, `lta`, `tree`, `cat`, `cd`, `ff`, `..`, `...`, `....`, `g`, `gcm`, `gcam`, `gcad`, `d`, `lzg`, `lzd`, `n` and `r`. It also sets `HERDR_CONFIG_PATH` when you have no herdr config.
- `~/.config/omamac/herdr.toml`: omawsl's herdr config and key bindings. A `~/.config/herdr/config.toml` of your own is used instead and never touched (one holding only `onboarding = false` is herdr's own and doesn't count).
- `~/.local/state/omamac`: logs and your saved answers (`choices.env`).

`omamac install` adds the languages and cloud CLIs you didn't pick before. `omamac uninstall <name>` removes one, after asking; a version another mise config uses stays, and Homebrew taps stay.

`omamac uninstall` removes your picks one at a time. For the rest, undo by hand: delete the two lines ending in `# added by omamac`, delete the three folders and `~/.config/mise/conf.d/omamac.toml`, delete `~/.config/nvim` if omamac made it (it holds `lua/plugins/omamac.lua`), and, if omamac installed them, run `brew uninstall gum bash starship neovim btop mise herdr eza bat zoxide fzf ripgrep fd lazygit tree-sitter-cli jq`. To remove Homebrew too, see [Uninstall Homebrew](https://github.com/Homebrew/install#uninstall-homebrew).

## herdr

Start it with `herdr` (Ghostty will do it in a later phase). Ctrl g is the prefix, then `p` pane, `t` tab, `r` resize, `m` move, `o` session, `s` scroll. Alt h/j/k/l move between panes, Alt n opens a new pane.

herdr's first-run screen is skipped.

> **omamac handles herdr's settings.** It writes `~/.config/omamac/herdr.toml` again on every update (and, later, every theme switch), so herdr always follows omamac's theme and key bindings. Changes made in herdr's own settings screen (Ctrl g `,`) or by hand to that file don't last. To use your own herdr config instead, write `~/.config/herdr/config.toml`: omamac never touches it, but then omamac's themes and key bindings don't reach herdr, and `omamac doctor` says so.

## Testing a branch

For contributors. Put the branch in the URL and in `OMAMAC_REF`:

```
curl -fsSL https://raw.githubusercontent.com/tunacinsoy/omamac/<branch>/boot.sh | OMAMAC_REF=<branch> bash
```
