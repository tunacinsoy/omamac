# Font size — design

Small change. Approach picked by Tuna on 2026-11-27.

## Why

On a different-sized monitor you want a different terminal text size. Omakub had a "Font size" menu item for this; omamac has none, and the vision said "no font setting taken over".

## Goals

- `omamac font-size` shows a plain picker, like Omakub's: 10 to 20, plus "Ghostty's default", with the current size marked.
- `omamac font-size 16` sets it directly; `omamac font-size default` removes omamac's size.
- The `omamac` menu gets "Change the font size", right after "Switch the theme".
- The change shows at once in open Ghostty windows (the same reload a theme switch uses), and stays on every later update and theme switch.

## Non-goals

- Not a first-run question, and update never asks it.
- No per-monitor switching (Ghostty has one `font-size` and doesn't follow the screen).
- Ghostty only: not VS Code, which has its own lasting zoom.
- No font family choice; Ghostty's built-in font stays.

## Anti-goals

- Someone who never runs it must see no change: their own `font-size` in their Ghostty config keeps working.

## Approaches

- **A. Its own command (picked).** Clear, one job, no extra step in the theme switch.
- B. Inside `omamac theme`: adds a question to every theme switch, mixes two things.
- C. First-run question: asks before you have seen the size on your screen.

## Decided

- Ghostty only, plain picker 10–20, command `omamac font-size`, menu entry, live reload, nothing written until a size is picked.

## Builder's calls (Claude)

- The size is saved in its own file, `~/.local/state/omamac/font-size`, not in `choices.env`: `choices.env` holds the first-run questions, and a key there would be asked at the first run and by update. It is read as data and checked to be 10–20; anything else is reported and ignored.
- `ghostty_render` appends `font-size = N` after the theme when the file holds a size. omamac's file loads after the user's own Ghostty config, so a picked size wins over theirs; the help text says so.
- `vision.md` changes the font line to "Ghostty's built-in font; omamac sets no size until you pick one with `omamac font-size`", with a dated decision.
- Docs: `docs/commands.md` gets a section and a row; the README menu text if it lists entries.
- Tests: bats for render with and without a size, the command's picker and arguments, a bad saved value, the menu entry; a VM check that the line lands in omamac's Ghostty file.
