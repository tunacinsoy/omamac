# Keeping it up to date

How `omamac update` keeps your Mac current, how to add what you skipped, and how to check that everything is healthy.

[← Back to the README](../README.md)

## omamac update

```
omamac update
```

It updates omamac and what omamac installed, nothing else:

- pulls omamac (and stops if you edited its files) and rewrites the files omamac writes;
- puts back any core tool, app, language, cloud CLI or coding agent that is missing, and the macOS settings you chose if you changed them;
- upgrades the core tools, bash, gum, colima and its tools if you chose it, the cloud CLIs and coding agents you chose (the casks among them with `--greedy`) and the languages you chose;
- upgrades Ghostty, Docker Desktop and your apps only when Homebrew lists them as outdated (they update themselves), and only if your terminal has App Management; otherwise it says what to click and exits 1. Homebrew may ask for your password for some of them;
- runs `mise prune`, which deletes versions of those languages that no mise config uses, such as one you installed with `mise install node@18`;
- names any question added since your first run, and the command that asks it, such as `omamac install desktop-widgets`: update itself asks nothing.

## omamac install

`omamac install` adds the apps, languages, cloud CLIs and coding agents you didn't pick before. It also asks again:

- any macOS setting you answered no;
- the Docker question, if you answered No Docker.

To skip the questions you don't need:

- `omamac install languages` asks only that section's question. The sections are `apps`, `languages`, `cloud-clis`, `coding-agents`, `docker` and `macos` (the five macOS settings).
- `omamac install go rust` asks nothing but "Install?". It takes the same names as `omamac uninstall`: `go`, `docker-desktop`, `vscode`, `dock-autohide` and the rest (see [Uninstalling](uninstalling.md)).
- A name you already picked is skipped.
- Docker takes one choice: to switch from Docker Desktop to colima, uninstall it first.
- Sections and names can be mixed: `omamac install cloud-clis go`.

## omamac doctor

`omamac doctor` checks that everything is healthy.

**Four lines, one per area:** omamac, Terminal, Theme (with your theme's name) and macOS, each `✓ working`.

- When a check in an area fails, its line is a ✗.
- Under it, each problem says what is wrong and how to fix it (`Fix: omamac update`).
- Notes show under their area too.

**Then what omamac installed for you**, a group per kind:

- Languages, Cloud CLIs, Coding agents and Docker: each tool with its version and whether a newer one is out (`3.14.2 is out`, or `latest`).
- Apps: one per line, with the version the app reports. Apps update themselves, so there is no newer column.
- Finding newer versions never updates Homebrew and waits 10 seconds at most. If it can't tell, the version shows alone.

**A count ends it:** `1 problem · 1 note · 14 fine`, and `· 2 updates waiting: omamac update` when some are.

It offers to reinstall a pick that is gone.

**`omamac doctor --all`** shows every check under its area, each with:

- a plain name;
- a line on what it is (`bash for omamac`: omamac's own scripts run in bash; your shell stays zsh);
- where it lives on your Mac (`See: ~/.zprofile`).

It ends with a link to [What it changes](what-it-changes.md).
