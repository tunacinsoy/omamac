# Themes

One theme for Ghostty, herdr, btop, the prompt, neovim and VS Code, switched with one command.

[← Back to the README](../README.md)

## omamac theme

`omamac theme [<theme>]`:

- saves a theme;
- applies it to Ghostty, herdr, btop, the prompt, neovim and VS Code;
- reloads Ghostty, herdr and btop if they are running. An open VS Code switches too; neovim shows it the next time it opens.

Without a name, it asks.

It says what it did on three rows, each naming only what the theme reaches:

1. the theme;
2. what shows it now;
3. what shows it the next time it opens.

The themes: `catppuccin`, `dracula`, `everforest`, `gruvbox`, `kanagawa`, `matte-black`, `nord`, `one-dark`, `osaka-jade`, `ristretto`, `rose-pine`, `solarized` and `tokyo-night`.

## btop

- Settings you save from btop's menu go into omamac's `btop.conf` and don't last, because omamac writes it again.
- Running `/opt/homebrew/bin/btop` without the alias makes btop write its own config in `~/.config/btop`, which then takes over from omamac's.

## VS Code

- omamac installs a small extension of its own, `omamac.omamac-theme`. It holds the theme as one colour theme named "omamac" and makes it VS Code's default.
- The extension asks VS Code to watch its theme file, so an open window switches when `omamac theme` rewrites it.
- Between rose-pine, the light theme, and a dark one, the few colours the theme leaves to VS Code follow the next time VS Code opens.
- omamac never writes your `settings.json`.
- If you set `workbench.colorTheme` there (or pick a theme in VS Code, which writes it), yours wins, and omamac says so. To follow omamac's theme again, pick "omamac" in VS Code's theme list, or remove that line.
- omamac only reads your default profile's settings.
- VS Code's "auto detect color scheme" setting picks its own themes, so omamac's doesn't show while it is on.

## neovim

If you have your own `~/.config/nvim`, omamac leaves it alone. `omamac doctor` offers to move it aside to `~/.config/nvim.bak-<date>`, so LazyVim and the theme can be set up.
