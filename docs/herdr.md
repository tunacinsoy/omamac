# herdr

herdr is the multiplexer: panes, tabs and sessions inside Ghostty.

[← Back to the README](../README.md)

## Starting it

Ghostty starts it for you; or run `herdr`. herdr's first-run screen is skipped.

## Keys

| Keys | Does |
| --- | --- |
| Ctrl g | the prefix, then one of the keys below |
| Ctrl g, `p` | pane |
| Ctrl g, `t` | tab |
| Ctrl g, `r` | resize |
| Ctrl g, `m` | move |
| Ctrl g, `o` | session |
| Ctrl g, `s` | scroll |
| Alt h/j/k/l | move between panes |
| Alt n | open a new pane |

## omamac handles herdr's settings

- omamac writes `~/.config/omamac/herdr.toml` again on every update and every theme switch, so herdr always follows omamac's theme and key bindings.
- Changes made in herdr's own settings screen (Ctrl g `,`), or by hand to that file, don't last.
- To use your own herdr config instead, write `~/.config/herdr/config.toml`. omamac never touches it, but then omamac's themes and key bindings don't reach herdr, and `omamac doctor` says so.
