# AltTab — design

Small change. Approach picked by Tuna on 2026-11-27.

## Why

macOS's Cmd+Tab switches apps, not windows. With a normal and a private Brave window open, or two VS Code windows, Cmd+Tab can't pick between them. AltTab (https://alt-tab.app, the `alt-tab` cask) lists every window with a preview, and that fixes it.

## Goals

- AltTab joins the app catalog in the Productivity group, after Raycast and Obsidian: one file `apps/alt-tab` (`cask=alt-tab`, `app=AltTab.app`) and one entry in `apps_productivity`.
- Picking AltTab means **Cmd+Tab opens AltTab**. There is no extra question: it's omamac's opinion that comes with the app. Right after Homebrew installs or adopts it, and before its first launch, omamac runs `defaults write com.lwouis.alt-tab-macos holdShortcut "⌘"`.
- Its `allow=` line covers the two clicks it needs on first launch: Accessibility and Screen Recording. They show in the end-of-run summary and on the "After install" page, like Cap's.
- Proven in the VM like every catalog app.

## Non-goals

- No `omamac configure` switch for it, and no saved previous value. Going back to macOS's Cmd+Tab means `omamac uninstall alt-tab`: AltTab only grabs Cmd+Tab while it runs, so removing it gives the key back, with or without its settings.
- No other AltTab settings (theme, appearance, what it shows): they stay at AltTab's defaults.

## Anti-goals

- omamac never fights the user's own choice: the hold key is written only at install and adoption, never by `omamac update`, so a key changed later in AltTab's settings stays.

## Approaches

- **A. Write one AltTab setting at install (picked).** It's the smallest change, it leaves every other AltTab setting alone, and uninstall is the way back.
- B. Ship a whole AltTab settings file: it overwrites the user's own settings, including on an adopted app.
- C. An `omamac configure` on/off switch with the old value saved: more to build, and it makes this a choice, which Tuna doesn't want.

## Decided

- Productivity group, Cmd+Tab taken over with no question, written at install and adoption only, uninstall restores macOS's Cmd+Tab.
- The vision is updated to match: AltTab in the catalog table and app count, and the Desktops line about Cmd+Tab notes that with AltTab, Cmd+Tab picks a window and still goes to its desktop.

## Left to the builder

- Confirm in the VM that `holdShortcut` is the right key and that Cmd+Tab opens AltTab after the permission clicks. If the key name differs, use the one AltTab actually reads.
- Where the per-app install step lives (a small hook next to the app's file, or in `lib/apps.sh`), and its bats test.
- The Dock places AltTab with the other catalog apps, as usual.
