# Phase 4: Ghostty, themes, desktop and window-margin settings — design

Status: draft · 2026-11-18 · Source of truth for the why: [`vision.md`](../../../vision.md)

## Intent

Phase 4 gives omamac its terminal and its look. Ghostty joins the core, and opening it lands the user in herdr. The theme picked at the first run reaches Ghostty, herdr, starship, btop and neovim, and `omamac theme` switches all of them at once. The "Desktops as workspaces" and "Window margins" answers are applied with `defaults`, and `omamac uninstall` puts the earlier values back.

It is done when: opening Ghostty lands in herdr; theme switching works everywhere at once; the desktop settings apply, a re-run changes nothing, and uninstall restores them.

## Goals

- Ghostty is installed for everyone (cask `ghostty`). Opening it runs herdr, which attaches to the running session or starts one. If herdr fails, the window falls back to zsh with a one-line message.
- Ghostty's config gets one optional include line pointing at omamac's file, in the file Ghostty loads last.
- omamac sets only these Ghostty settings: the theme's colors, `macos-option-as-alt = left` and `command`. The installer says which ones it takes over.
- The chosen theme shows in Ghostty, herdr, the starship prompt, btop and neovim the first time the user opens Ghostty.
- `omamac theme [<theme>]` switches all five, and a running Ghostty, herdr and btop change at once. A second switch to the same theme changes nothing.
- With "Desktops as workspaces" set to yes, desktops keep their order, switching to an app goes to its desktop, and Reduce motion is on. With "Window margins" set to yes, tiled windows have margins.
- omamac records each setting's earlier value (or that it was unset) before the first change. `omamac uninstall desktops` and `omamac uninstall window-margins` put them back.
- `omamac install` offers the two settings again when they were answered no.
- `omamac doctor` reports Ghostty, its include line, App Management, user configs omamac leaves alone (starship, btop), and settings that drifted.

## Non-goals (later phases)

- The Dock and Dock auto-hide questions (Phase 6: the Dock needs the app catalog).
- Adopting a Ghostty the user installed by hand (Phase 6 brings adoption). In Phase 4, a `/Applications/Ghostty.app` that Homebrew doesn't know is used as it is and never upgraded (below).
- Migrations. Before Gate B, omamac runs only in throwaway VMs, so no install holds Phase 3 state. A pre-release install gets Ghostty's include line by running the one-liner again (re-runs are safe).
- Fonts. Ghostty's built-in font stays (vision).
- Ghostty's `confirm-close-surface`. Closing a window running herdr asks first; whether omamac should turn that off is for Gate B (see "Left for later phases").

## Anti-goals

- omamac runs Ghostty's binary (`ghostty +validate-config`, `+show-config` and the like) during install, update, theme or doctor. On a fresh Mac, the first run of a downloaded app waits on macOS's "Open?" dialog (seen in the VM, 2026-11-18). That would stop an unattended install.
- A user file gets more than its one include line. A user's own `~/.config/starship.toml` or `~/.config/btop/btop.conf` is written.
- omamac weakens Gatekeeper, removes quarantine, or grants itself a permission. The VM test removes quarantine only as a stand-in for the user's "Open" click, in the steps file, never in omamac.
- A setting omamac didn't change is "restored" by uninstall, or the record of an earlier value is overwritten by a later run.
- A second run, update, theme switch or uninstall changes anything.

## Constraints

- bash 5 after `boot.sh`; `set -Eeuo pipefail` with the `ERR` trap. Prompts read `$OMAMAC_TTY`; nothing is pre-selected.
- Gate files change only in a PR about the gate.
- Facts checked on 2026-11-18 (sources: Ghostty 1.4.0 source and docs, btop 1.4.8 source, herdr 0.9.5 source, starship docs, LazyVim 16, nix-darwin, Homebrew's source, and a probe VM running macOS 27.2):
  - **Ghostty 1.4.0** (cask `ghostty`, `auto_updates`, notarized, quarantined by Homebrew). The cask puts no `ghostty` on the PATH; the CLI is `/Applications/Ghostty.app/Contents/MacOS/ghostty`.
  - Ghostty reads `~/.config/ghostty/` (XDG) and then `~/Library/Application Support/com.mitchellh.ghostty/`. In each it reads `config` and then `config.ghostty` (the new name since 1.3.0). A later file wins.
  - `config-file = ?<path>` is optional, expands `~`, and is loaded after the whole including file. So a value in omamac's file wins wherever the line sits.
  - `command` applies to every new window, tab and split. With no prefix it runs through `/usr/bin/login` and `bash --noprofile --norc -c`, so zsh's files don't load. `direct:<path>` runs the file directly but splits on spaces without honouring quotes. VM-checked: `command = direct:<script>` with the shebang `#!/bin/zsh -il` starts the script in a login and interactive zsh, with `/opt/homebrew/bin` on the PATH. When the command exits, the window closes.
  - `SIGUSR2` makes a running Ghostty reload its config and recolour open windows (VM: Ghostty keeps running). Explicit colours win over `theme`.
  - A quarantined Ghostty run from SSH, GUI or CLI, waits at `_dyld_start` until the "Open?" dialog is answered. With quarantine removed and the pending check cleared, it starts (VM).
  - **herdr** 0.9.5 themes: catppuccin, tokyo-night, dracula, nord, gruvbox, one-dark, solarized, kanagawa, rose-pine, rose-pine-dawn, `terminal` (follows the outer terminal's colours) and others; no everforest. `herdr server reload-config` reloads a running server. Panes are login shells and inherit the server's environment.
  - **starship** reads `STARSHIP_CONFIG` again at every prompt.
  - **btop** 1.4.8: `-c <file>` (since 1.4.1) and `--themes-dir <dir>` (since 1.4.6), no environment variable. `color_theme` is a theme name found in the theme folders. btop writes its config file back on exit, and `SIGUSR2` reloads it.
  - **LazyVim** bundles tokyonight and catppuccin; lazy.nvim installs other colour plugins at the next start. `nvim --headless "+Lazy! sync" +qa` installs them unattended. `maxmx03/solarized.nvim` is archived but installs.
  - **macOS 27.2, clean VM:** `com.apple.dock mru-spaces`, `NSGlobalDomain AppleSpacesSwitchOnActivate` and `com.apple.WindowManager EnableTiledWindowMargins` are absent, which means macOS's defaults: rearrange by recent use, switch on activate, margins on. `defaults read` exits 1 with "Could not find key" for an absent key. Over SSH, writing `com.apple.universalaccess reduceMotion` and `com.apple.Accessibility ReduceMotionEnabled` succeeded. Elsewhere it is reported to fail with "Could not write domain com.apple.universalaccess" without Full Disk Access (macOS 13 to 26). `mru-spaces` needs `killall Dock`.
  - **App Management:** no read-only check exists. Homebrew's own check creates and removes `<App>.app/.homebrew-write-test` and reads "Operation not permitted" as missing. Without the permission, `brew upgrade --cask` deletes and reinstalls the app. The pane opens with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles"`.

## Approaches

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| How Ghostty starts herdr | `command = direct:<absolute path>/bin/omamac-terminal`, a zsh script with `#!/bin/zsh -il` that runs `herdr`, falling back to `exec zsh -l` | The login and interactive shell loads the user's `~/.zprofile` and `~/.zshrc`, so `HERDR_CONFIG_PATH`, the PATH and mise reach herdr exactly as in a shell, from one rule in omamac's zshrc. Dropped: Ghostty's `env` (a second copy of the rule that zshrc already applies); `command` without `direct:` (zsh's files don't load); `/bin/zsh -lic '…'` as the command (quotes break under `direct:`, and Ghostty would inject its zsh integration into a shell that only execs herdr). |
| Ghostty's colours | `themes/<theme>/ghostty.conf` in the repo, converted once from omawsl's terminal palette (`background`, `foreground`, `cursor-color`, `selection-background`, `palette = 0..15`) | Content is copied as is: the same 20 colours omawsl users see. Dropped: Ghostty's built-in theme names (different colours from omawsl's, and names change between releases). |
| Where the theme's files live | Everything theme-dependent is rendered into `~/.config/omamac/` by one function, which the one-liner, `update` and `theme` all call | One place writes each file, so a switch can't miss a tool, and update can't undo a switch. |
| btop | `~/.config/omamac/btop.conf` and `~/.config/omamac/btop-themes/`, used through an alias in omamac's zshrc (`btop -c … --themes-dir …`) only when the user has no `~/.config/btop/btop.conf` | btop has no include and no variable; this is the vision's one-file rule (herdr, starship). btop writes its settings back into omamac's file on exit, and omamac rewrites the file on the next update or theme switch, as with herdr. The README says so. |
| neovim | `lua/plugins/omamac.lua` (in a `~/.config/nvim` omamac made) loads `~/.config/omamac/neovim.lua`, which holds the theme's plugin spec | The theme lives in omamac's folder like every other generated file. omamac rewrites its own `omamac.lua` on every run when it's there, which also upgrades Phase 3's `return {}`. |
| A Ghostty the user dragged in | Used as it is; not installed, not upgraded; doctor says so (ℹ) | The vision: never overwrite or fail on a hand-installed app. Adoption is Phase 6. |
| App Management | The same write test Homebrew uses, run only before omamac changes an installed app in `/Applications` (today: upgrading Ghostty) and in doctor | No read-only check exists. Running it only when an upgrade is due keeps update from asking for nothing. |
| Saving earlier settings | `~/.local/state/omamac/macos-settings.tsv`: one line per key omamac changed, `domain`, `key`, and `type` and `value` or `absent`, written only the first time | Exact restore, including "was unset" (restored with `defaults delete`). A key already recorded is never recorded again, so later runs can't lose the first value. |
| Splitting the work | A gate PR, then 4a, 4b, 4c | Small steps, each proven in the VM on its own. |

Everything here is Claude's call within the vision. The one vision text change is listed under "Vision updates".

## Pull requests

1. **Gate PR (`gate-phase-4`).** `test/fingerprint.sh` learns what Phase 4 writes, so the VM's "second run changes nothing" covers it.
2. **4a (`phase-4a-ghostty`).** Ghostty in the core, its include line, `bin/omamac-terminal`, the App Management check, doctor's Ghostty checks. This spec and the plan ride along. VM fixture: `bare`.
3. **4b (`phase-4b-themes`).** `themes/`, the theme files for the five tools, `omamac theme`, live reload, doctor's starship and btop ℹ. VM fixture: `bare`.
4. **4c (`phase-4c-desktop-settings`).** The desktops and window-margin settings, their record, `install`, `uninstall` and doctor. VM fixture: `desktop` (new).

Each branches from `main` after the one before it merges.

## Design

### Gate PR

`test/fingerprint.sh` adds, each only when it exists:

- `brew list --cask --versions` (if `brew list --versions` already lists casks, this line isn't needed; the builder checks).
- Hashes of Ghostty's four config files (`config` and `config.ghostty`, in both folders) and every file under `~/.config/btop`.
- Hashes of every file under `~/.local/state/omamac` except `logs/`, replacing today's `choices.env` line.
- For each of the five keys omamac may set, `defaults: <domain> <key> <value>`, or `absent`.

On today's `main` the new lines are the same before and after a run, so `bare` still passes. The gate PR's own VM run proves it.

### Ghostty (4a)

- `CORE_CASKS=(ghostty)` in `lib/core.sh`. `core_install` also runs `brew install --cask` for core casks `brew list --cask` doesn't have, unless `/Applications/<App>.app` is already there. In that case it prints one ℹ line: "Ghostty is already installed, not through Homebrew, so omamac uses it as it is and doesn't update it."
- `config/ghostty.conf`, rendered to `~/.config/omamac/ghostty.conf`:

  ```
  # Generated by omamac. Changes here are overwritten; put your own in Ghostty's config.
  command = direct:@OMAMAC_TERMINAL@
  macos-option-as-alt = left
  ```

  4b appends the theme's colours; until then Ghostty keeps its own.
- **The include line** `config-file = ?~/.config/omamac/ghostty.conf # added by omamac` goes into the last existing file in Ghostty's load order (`~/.config/ghostty/config`, `~/.config/ghostty/config.ghostty`, then the same two in Application Support). With none, it goes into `~/.config/ghostty/config.ghostty`. If any of the four already holds the line, nothing is added. The builder checks in the VM that Ghostty accepts a trailing `#` comment on a `config-file` line; if not, the comment goes on the line above. Like the zsh lines, only the one-liner adds it (`install_lines`).
- **`bin/omamac-terminal`** (zsh, `#!/bin/zsh -il`):
  1. Runs `herdr`. If herdr exits 0 (the user quit or detached), the script exits and Ghostty closes the window.
  2. If herdr is missing or exits non-zero, it prints one line, "herdr didn't start, so this is a plain zsh window. Run omamac doctor to see why.", then `exec zsh -l`.
- **The installer's summary** gains the Ghostty lines (vision step 5): "Open Ghostty: it starts herdr." "Allow App Management for Ghostty: System Settings → Privacy & Security → App Management." "The first time you open each app, macOS asks you to confirm; click Open." It also says once which Ghostty settings omamac takes over (colours, `macos-option-as-alt`, `command`).
- **App Management** (`lib/appmanagement.sh`): `app_management_ok <App>.app` runs `touch <App>.app/.omamac-write-test`, then removes it. It returns 1 on "Operation not permitted", and for any other failure says why. In `update`, after the formula upgrades, and only when Homebrew has the `ghostty` cask:
  - Is it outdated? Decided from the text of `brew outdated --cask --greedy --quiet ghostty`, never its exit status: `brew outdated <name>` exits 1 when the named item *is* outdated. fake-brew copies that exit status.
  - Outdated, permission missing: Ghostty's upgrade is skipped and the app is left exactly as it is. update prints a ✗ line with the click, opens the pane with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles"`, finishes everything else, and exits 1. This is the vision's "stops, changes nothing", applied to the app it protects. Formulas, languages and CLIs need no App Management, so they still update.
  - Outdated, permission there: `brew upgrade --cask --greedy ghostty`.
- **doctor:** ✗ when Homebrew's Ghostty or the include line is missing (fix: the one-liner); ℹ for a Ghostty installed by hand. App Management: ✓, or ℹ with the click when the write test is refused. It is ℹ because nothing is broken until an upgrade is due, and update then says so with a ✗. No App Management check for a Ghostty omamac doesn't manage.
- **Core names** for `omamac uninstall`: `ghostty` joins the list that can't be removed on its own.

### Themes (4b)

- **`themes/<id>/`** for the 13 ids in the theme question, holding `ghostty.conf` (converted from omawsl's palette), and `btop.theme`, `neovim.lua` and `starship.toml` copied from omawsl unchanged except for comments that mention files omamac doesn't have. omawsl's icon starship file is the one used: Ghostty's built-in font has the symbols. `themes/LICENSE.omarchy` comes along: the themes are MIT, from Omarchy.
- **herdr's theme** comes from a table in `lib/theme.sh`, as on omawsl: the same name for catppuccin, dracula, gruvbox, kanagawa, nord, one-dark, solarized and tokyo-night; `rose-pine-dawn` for rose-pine; `terminal` for everforest, matte-black, osaka-jade and ristretto (herdr follows Ghostty's colours). `config/herdr.toml`'s `name = "tokyo-night"` becomes `@OMAMAC_HERDR_THEME@`.
- **`theme_apply`** writes, compare-then-move, from `CHOICES[theme]`:

  | File in `~/.config/omamac/` | From |
  | --- | --- |
  | `ghostty.conf` | `config/ghostty.conf` + `themes/<id>/ghostty.conf` |
  | `herdr.toml` | `config/herdr.toml` with the herdr theme filled in |
  | `starship.toml` | `themes/<id>/starship.toml` |
  | `btop.conf` | `color_theme = "<id>"` |
  | `btop-themes/<id>.theme` | `themes/<id>/btop.theme`; other `.theme` files there are removed |
  | `neovim.lua` | `themes/<id>/neovim.lua` |

  `apply_all` calls it in place of today's separate herdr step. `~/.config/nvim/lua/plugins/omamac.lua` has one writer, `neovim_marker_write`. `neovim_setup` calls it when it creates the folder, so the first run already loads the theme. `apply_all` calls it whenever the file exists (the folder is omamac's), which also upgrades Phase 3's `return {}`. The new `omamac.lua` doesn't depend on the theme, so a theme switch never touches it:

  ```lua
  -- Set up by omamac. The theme comes from omamac's own file, which omamac theme rewrites.
  local theme = vim.fn.expand("~/.config/omamac/neovim.lua")
  if vim.uv.fs_stat(theme) then return dofile(theme) end
  return {}
  ```

- **omamac's zshrc** gains, beside the herdr rule and by the same rule (a user's own file wins, and a variable they set wins):
  - `STARSHIP_CONFIG=~/.config/omamac/starship.toml`, set when it's unset and `~/.config/starship.toml` doesn't exist. It is set before `starship init`.
  - `alias btop='btop -c ~/.config/omamac/btop.conf --themes-dir ~/.config/omamac/btop-themes'`, set when `~/.config/btop/btop.conf` doesn't exist.

  If btop is ever started without the alias, it writes `~/.config/btop/btop.conf` itself. From then on that file is the user's, and doctor says omamac's theme doesn't reach btop (ℹ). The README says so.
- **`omamac theme [<id>]`**:
  - With no id it asks (single choice of the 13, labels as in the first-run question). An unknown id lists the valid ones and exits 2.
  - It saves `theme` in `choices.env`, then always runs `theme_apply`, even for the current theme. A switch that failed halfway is then fixed by running it again, and compare-then-move keeps a repeat from changing anything. `bin/omamac` gives `theme` the ERR trap and `OMAMAC_CMD`, like install and uninstall.
  - Then it reloads what's running, each only if running, and ignores a failure: `pkill -USR2 -x ghostty`, `herdr server reload-config`, `pkill -USR2 -x btop`.
  - It ends with: "Theme: <label>. Ghostty, herdr, btop and your prompt show it now; neovim the next time it opens."

  It asks no "Install?": it changes only omamac's own files. The user's choice is the confirmation.
- **doctor:** ℹ "your own starship config is kept, so themes don't reach the prompt", and the same for btop. ✗ when one of the theme files above is missing, fix `omamac update`.

### Desktop and window-margin settings (4c)

| Answer | Keys set (domain key type value) |
| --- | --- |
| `desktops=yes` | `com.apple.dock mru-spaces bool false`; `NSGlobalDomain AppleSpacesSwitchOnActivate bool true`; `com.apple.universalaccess reduceMotion bool true`; `com.apple.Accessibility ReduceMotionEnabled int 1` |
| `window_margins=yes` | `com.apple.WindowManager EnableTiledWindowMargins bool true` |

- **`settings_apply`** (in `apply_all`, after the installs), for each key of each "yes" answer:
  1. Read the current type and value, or `absent` ("Could not find key").
  2. If the value isn't the wanted one, write it. Only after the write succeeds, and only if `macos-settings.tsv` has no line for the key yet, append the value read in step 1. So the record holds only keys omamac changed, each with its value from before omamac's first change. When the key was already recorded, the write puts back a value the user changed since: print "Put back: <what>".
  3. After all keys, `killall Dock` if a `com.apple.dock` or `NSGlobalDomain` key changed.
- **Reduce motion** is one unit of two keys: `com.apple.universalaccess reduceMotion` first, and `com.apple.Accessibility ReduceMotionEnabled` only once that succeeded. If macOS refuses to read or write the protected domain ("Could not write domain"), omamac changes neither key and records neither. That is not a failure: the summary gets one line, "Turn on Reduce motion: System Settings → Accessibility → <the pane the builder finds on macOS 27> → Reduce motion." Any other `defaults` failure stops the run as usual.
- **`omamac uninstall desktops` / `omamac uninstall window-margins`**:
  - Not set by omamac (answer `no`): "<title> isn't set by omamac." and exit 0.
  - Otherwise it shows what goes back ("Desktops as workspaces: your earlier Spaces, app-switching and Reduce motion settings"), then asks `Remove <title>?` (default No; vm.exp already answers this shape).
  - On yes: for each of its keys with a record, write the recorded value back, or `defaults delete` for `absent` (a missing key counts as done). If macOS refuses the protected domain, uninstall doesn't fail; it prints the click to turn Reduce motion off by hand. Then `killall Dock` as above, drop those lines from the record (deleting the file when it's empty), and save the answer as `no`, last.
  - The names are `desktops` and `window-margins`, mapped to the keys `desktops` and `window_margins`. `omamac uninstall` with no name offers the settings answered yes, beside the languages and cloud CLIs.
- **`omamac install`** asks `desktops` and `window_margins` again when answered `no`, alongside languages and cloud CLIs, and applies a yes. `ADD_KEYS` gains them; a yes/no question with answer `yes` is skipped like a multi question with nothing left. A yes replaces the saved `no` (`choices_add` is for multi answers only), and the summary names the setting by its title.
- **doctor:** for each "yes" answer, ✗ per key that isn't the wanted value (Reduce motion: ℹ with the click when macOS refuses to read it), "<what> was changed since omamac set it", fix `omamac update` (Reduce motion: or the click above). ✓ otherwise. Nothing is offered as a question: update puts it back.

### Fixtures and VM runs

- **4a, `bare.steps.sh`** adds, after today's checks:
  1. `xattr -dr com.apple.quarantine /Applications/Ghostty.app`, the stand-in for the user's "Open" click. It must come before anything starts Ghostty. omamac never starts it, so no check is pending yet. (In the probe, a check already pending kept Ghostty at `_dyld_start` even after quarantine was removed, until `syspolicyd` restarted.)
  2. `open -a Ghostty`. Within 30 s a `herdr` process runs whose parent chain leads to Ghostty, and the herdr server's environment has `HERDR_CONFIG_PATH` set to omamac's file.
  3. `ghostty +show-config --no-pager` shows omamac's `command` and `macos-option-as-alt = left`.
- **4b, `bare.steps.sh`** adds:
  1. For each of the 13 themes, `omamac theme <id>`, then `nvim --headless "+Lazy! sync" +qa` and the active `colors_name` matches the theme's neovim file.
  2. Ghostty's `background` matches the theme's.
  3. `herdr config check` passes.
  4. The Ghostty and herdr that 4a's step started are still running after the switches, and `herdr server reload-config` exited 0. Whether the colours change on screen is checked by eye at Gate B; a headless VM can't show it.
  5. Last: `omamac theme tokyo-night` twice, with the fingerprint unchanged by the second.
- **4c, `desktop.env`:** `bare` with `desktops=yes` and `window_margins=yes`. `desktop.steps.sh`:
  1. The five keys hold the wanted values, and `macos-settings.tsv` records them.
  2. `omamac update` twice, with fingerprints compared.
  3. `omamac uninstall desktops` and `omamac uninstall window-margins`: each key is back to its recorded value (on the clean image, absent), the record is gone, and the answers are `no`.
  4. Both uninstalls again change nothing.

### bats

- fake-brew learns `list --cask`, `install --cask` and `outdated --cask --greedy`. A fake `defaults` keeps a plist-like file per domain and can be told to refuse a domain.
- Ghostty: cask installed only when missing, not when the app is in `/Applications` by hand; include line placement for each of the four files and for none; a second run adds nothing; the rendered file names the launcher by absolute path.
- `omamac-terminal`: herdr exit 0 exits; herdr missing or exit 1 prints the line and execs zsh (stubbed).
- App Management: update with Ghostty current, or not from Homebrew, never runs the write test; outdated and denied skips only Ghostty's upgrade, still upgrades the formulas, and exits 1; outdated and allowed upgrades with `--greedy`; `brew outdated`'s exit 1 doesn't trip the ERR trap.
- No script in `bin`, `lib`, `install.sh` or `update.sh` calls the Ghostty binary (a hygiene grep).
- Themes: every theme folder has the four files; each `ghostty.conf` has the 20 colour lines; a first run with a theme other than Tokyo Night writes `omamac.lua` and `neovim.lua` so that a second run changes nothing; `omamac theme` with the current theme puts back a missing file; `theme_apply` is idempotent; a switch rewrites only the theme files; an unknown id exits 2; reloads run only for running processes; zshrc sets `STARSHIP_CONFIG` and the btop alias only under the rule, and `zsh -n` still passes.
- Settings: first apply records and writes; a second apply changes nothing; a changed value is put back with the "Put back" line and the record untouched; a refused Reduce motion writes and records neither key, gives the summary line, and exits 0; uninstall restores values and absences, drops the record lines, saves `no`, and a second uninstall changes nothing; `killall Dock` only when a Dock or global key changed.
- hygiene: the never-touch list gains `~/.config/starship.toml` and `~/.config/btop/btop.conf`. Ghostty's user files may change only by the one line.

### Docs

- **README:**
  - The top says Ghostty opens in herdr and themes work.
  - "After install" gains the App Management click, the first-open click, "Open Ghostty", and "Give an app its own desktop: right-click its Dock icon → Options → Assign To" (vision).
  - "What it changes" lists Ghostty, its include line and the settings omamac takes over, the theme files, the STARSHIP_CONFIG and btop rules, the macOS keys and their record.
  - `omamac theme` and the two new uninstall names get one line each, and the hand-undo text grows with them.
  - The herdr section loses "Ghostty will do it in a later phase".
- **CONTRIBUTING:** steps files remove quarantine before opening an app, and why.

## Vision updates in this change

- "Tools that read one config file and can't include another" names btop beside herdr and starship. Same rule, a third tool: btop takes omamac's file through `-c` only when the user has none.

## Left for later phases

- Phase 6: the Dock and Dock auto-hide; adopting a hand-installed Ghostty (and other catalog apps).
- Gate B, to judge by living with it: whether Ghostty's "Close terminal?" prompt on a herdr window should be turned off (`confirm-close-surface`); whether Reduce motion needs a logout to apply everywhere; the window-margins question on a Mac where margins are already on by default (see the report to Tuna).

## Left to the builder

- Exact wording of messages and summary lines.
- The macOS 27 Settings path for Reduce motion.
- How the 4a steps file finds herdr's parent chain and the server's environment.
