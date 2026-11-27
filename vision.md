# omamac — vision

Status: living document · Owner: Tuna Cinsoy · Started Nov 9, 2026 · Updated Nov 27, 2026

What omamac is, who it's for and why, in as much detail as we have today.

## The idea in one sentence

**One command turns a fresh Mac into a complete, ready-to-work machine, and the person who runs it feels at home immediately.**

## Why omamac exists

omawsl already does this for Windows users: one run brings a WSL2 Ubuntu up to an opinionated, complete developer setup (Omakub-style), with the same shell, prompt, editor, multiplexer and themes every time. It took months to get the questions, conventions and safety rules right.

Now there is a Mac. A brand-new 14-inch MacBook Pro (M4 Pro, 24 GB, 512 GB) arrives with nothing on it. Setting it up by hand would mean hours of installing, configuring and forgetting steps, and the result would be a machine that is "mine" only by accident and can't be reproduced. We want the opposite: a setup that is written down as code, can be run again on any Mac, and gives the same result every time.

Tuna is both the producer and the first real user. The final proof that omamac works is that Tuna wipes this Mac back to factory settings and sets it up again with nothing but the README and the one-liner, the same way omawsl was proven by deleting and reinstalling its WSL distribution.

## Who it's for

- **omawsl users moving to a Mac.** They should find the tools and key bindings they live in (herdr, neovim, starship, btop, the same aliases) and feel at home within a day. Inside the terminal, Ctrl stays Ctrl: every herdr, editor and shell binding works exactly as on omawsl. ⌘ takes over only the app-level shortcuts (copy, paste). The terminal app around the shell differs (Ghostty instead of Windows Terminal), and that's fine: people spend their time in the shell, not around it.
- **Any developer with a fresh Mac** who wants a sensible, complete setup without assembling it from blog posts.
- **Tuna himself**, every time a Mac is new, reset or replaced.

They should never need to know what apt, WSL or Windows Terminal are.

## The family: omawsl and omamac

omawsl and omamac are **sister products, not mirrors**. Think of the Volkswagen Group: Skoda and Porsche share an owner, a philosophy and even parts, but each runs as its own brand and makes its own decisions.

What they share is the mindset: **a single installation command, and you get everything you need on your computer.**

What that means in practice:

- Two independent repos, `tunacinsoy/omawsl` and `tunacinsoy/omamac`, each with its own roadmap, releases and merge gate.
- omamac is a new repo, not a GitHub fork, so it never carries a "forked from omawsl" banner.
- **No parity contract.** A feature in one never obliges the other. Google Chrome can be one command away on the Mac even though omawsl deliberately doesn't touch the Windows side. Likewise omamac offers only herdr as its multiplexer, whatever omawsl offers.
- **Fresh code, copied content.** omawsl (cloned read-only at `~/git-repos/omawsl`) is a reference to study, not a codebase to port.
  - *Code is written fresh:* `boot.sh`, `bin/omamac`, install scripts, the question flow and the tests are written from the spec, test-first, in omamac's own structure. omawsl's scripts are read for ideas and lessons, never copied and stripped of WSL parts, so no apt, WSL or Windows assumptions can hide in omamac.
  - *Content is copied as is:* theme palettes, aliases, the starship prompt, neovim and herdr configs, and key bindings come over unchanged, because being the same is the point: they are what makes an omawsl user feel at home.
  - *Conventions come over as rules:* nothing pre-selected, config safety, idempotency, migrations and the merge gate, reimplemented in omamac's own code.
  - Once something is in omamac, it belongs to omamac and may change freely. There is no ongoing sync.
- The two READMEs link to each other as sister projects. That is the only tie.

## Principles

1. **Simplicity, simplicity, simplicity.** We advance the technology without compromising simplicity, while still serving the user's needs and solving their problems. Wherever there is a simpler way that works, we take it. This applies to the code, the docs, the questions we ask users, and the way we build omamac itself.
2. **One command.** `curl … | bash` on a fresh Mac ends with a ready machine. Anything the user must do by hand is a bug to remove later, and until then it is one clear line in the README.
3. **The user sees only what concerns them.** Nothing users see (README, installer output, prompts, code) mentions apt, Windows or WSL. Planning documents like this one may use omawsl as a reference point, the way a new kernel's designers might study Linux.
4. **Nothing pre-selected.** For everything optional, the user chooses; omamac never assumes. (Carried over from omawsl.) A small core is installed for everyone without a question; see "What omamac sets up".
5. **Safe with the user's files.** omamac never silently overwrites a config the user wrote; see "Config safety on macOS".
6. **Idempotent.** Running anything twice changes nothing the second time.
7. **Tested as a stranger would use it.** Every install change is proven in a fresh VM that fetches omamac through the public one-liner, never on the development machine.
8. **Merging is shipping.** `main` is what users get. Nothing merges without passing the gate.

## What the user experiences

**Before starting,** the README's "Before you begin" lists the few things that must be true: an Apple Silicon Mac on macOS 27 or later, Setup Assistant finished, an administrator account, macOS updated, an internet connection.

**On a fresh Mac,** after the normal Apple Setup Assistant:

1. The user opens Terminal.app and pastes one line from the README.
2. omamac explains in a few lines what it is about to do and asks for the admin password once. It keeps sudo valid until the run ends (the password is never stored), so it is not asked again partway through. One exception: Homebrew resets sudo before a cask step that needs it, so if the user picked Docker Desktop, Zoom or Google Drive, Homebrew asks once more, once for all of them; omamac runs that step right after "Install?", in the open, and says so before "Install?". When Homebrew asks, omamac's row says who needs the password and why ("Zoom needs your Mac password / to run its installer."), right above sudo's own prompt. Nothing after it needs sudo.
3. It installs its own prerequisites without asking: Apple's Command Line Tools and git (via Homebrew's installer), Homebrew itself (put on the PATH for them), a modern bash, and `gum`, which draws omamac's questions, progress and summaries.
4. It asks all its first-run questions before installing anything, so the rest of the run needs nobody at the keyboard. Questions are short, grouped, nothing pre-selected, from the most visible to the most technical: theme, desktop apps (one multi-select per group, AI apps among them), Wispr Flow, desktops, window margins, Dock, Dock auto-hide, Tap to click, tap to drag, languages, cloud CLIs, coding agents, Docker. If a chosen app is already installed by hand, the "let Homebrew take it over?" question comes right then, too. It ends with one summary of every answer and "Install? (y/n)" before anything changes. There is no multiplexer question: Ghostty and herdr are the terminal pair every omamac user gets.
5. It installs and configures everything chosen, with clear progress output, and ends with a short summary: what was installed, anything that needs one manual click (for example a macOS permission prompt, such as allowing the microphone for Wispr Flow or screen recording for Cap, or App Management for Ghostty), and how to open Ghostty. Each click is one line, never a block of text, plus one line: "The first time you open each app, macOS asks you to confirm; click Open." The "After install" page (`docs/after-install.md`, linked from the README) lists the same clicks.
6. The user opens Ghostty and is already in herdr, with nothing to start or set up: their prompt, their editor, their aliases, and the theme they picked (for example Tokyo Night), visible at once.

**Desktops that stay put.** omawsl and Omakub users think of desktops as fixed slots: desktop 6 is Spotify, and it stays desktop 6. Out of the box, macOS reorders desktops by most recent use and slides the screen on every switch, which breaks that habit. omamac is opinionated about the experience, not only the tools, so it fixes this itself: one first-run question ("Make desktops behave like workspaces?") and, on yes, desktops keep their place, Cmd+Tab jumps to the app's desktop (with AltTab, Cmd+Tab picks a window and still goes to its desktop), and switching becomes a short crossfade instead of a slide. The one thing a script can't do reliably, giving each app its own desktop, is a short "After install" line in the README. macOS's own desktops, with these settings, are enough; omamac does not add a tiling window manager.

**A Dock that holds your apps.** A fresh Mac's Dock is full of Apple's own apps (Mail, Safari, Maps, Photos, Notes, Calendar, Contacts, Music, TV and more) that pull the user into Apple's ecosystem whether they use them or not. If the user opts in, omamac clears them and the Downloads stack out of the Dock and puts the apps omamac installed there instead. The Apple apps are **not uninstalled**: they stay in Applications and open as usual from Spotlight, they just stop taking up the Dock. The result, left to right: Finder, apps the user pinned themselves, omamac's apps (Ghostty, the catalog apps in catalog order, then Docker Desktop), Trash. Finder and Trash always stay, since macOS doesn't allow removing them.

**Afterwards,** the user manages everything through one command, `omamac`. The first run both installs and configures; afterwards, installing and configuring are separate commands. The user never has to remember a name: `omamac` alone asks what they want to do (install, remove, change a setting, switch the theme, update or check), and each command asks what it needs when nothing is named after it. Names are shortcuts for those who know them.

- `omamac install` — add software later: apps, languages, cloud CLIs, coding agents, Docker. It only adds, and only software. With nothing named, it asks which section, and for Apps which group, then only that question; it never walks the first run's questions again. `omamac install <section>` asks only that section (`languages`, `apps`…), and `omamac install <name>…` asks nothing but "Install?" (`omamac install go rust`), with the names `omamac uninstall` takes.
- `omamac configure` — turn one of the macOS settings on or off (desktops, window margins, desktop widgets, Dock cleanup, Dock auto-hide, Tap to click, tap to drag). With nothing named, it lists them with their state; `omamac configure dock-autohide` asks only about that one, and `omamac configure dock-autohide on|off` asks nothing. Off puts back the values from before omamac changed them, as uninstall does for software.
- `omamac update` — update omamac and everything it installed: pull omamac's code (`git pull --ff-only` on `main`), run any migrations not yet applied (`migrations/<unix-ts>.sh`, last applied saved in `~/.local/state/omamac/version`), regenerate `~/.config/omamac/`, then `brew upgrade` the user's chosen formulas and casks and `mise upgrade` the chosen languages. Apps update themselves, so omamac upgrades one only when Homebrew lists it as outdated, without `--greedy`. The same model as omawsl, written fresh.
- `omamac theme` — switch the theme everywhere at once.
- `omamac doctor` — check that everything is healthy and explain anything that isn't (see below).
- `omamac uninstall <thing>` — remove one thing omamac installed, safely, putting the Mac back the way it was before that thing. With nothing named, it asks which section, then what to remove. Core tools (Ghostty, herdr, starship…) can't be uninstalled one by one: omamac says they're part of the core and stops.

To change an earlier software answer (for example colima → Docker Desktop), the user uninstalls one and installs the other. A setting answer changes with `omamac configure`. There is no general "edit answers" command.

**Known v1 gap: omamac can't remove itself.** Uninstall works per thing, so in v1 nothing removes the core tools, omamac's include lines, its generated files or the checkout. This goes against the principle "uninstall restores the previous state"; it is accepted for v1 to keep the scope down, and removing omamac itself is in the Backlog.

**`omamac doctor` is a doctor, not an alarm.** One row per check, ✓, ✗ or ℹ, in one sheet by section (Setup, Terminal, Theme, Your picks, macOS) with a count line under it. Each finding says what it found and why it matters, and a "To fix" box names the one command or click that fixes it, each command once. After it, a "What you have" sheet lists what omamac installed, by section, so the user sees what they have without looking anything up (as omawsl's doctor does). Piped or logged, doctor prints its plain lines instead: one per check, with the fix on the line. It checks that Homebrew and mise still have everything the user chose, omamac's include lines and generated files are present, Ghostty has App Management, the macOS desktop and Dock settings are still as set, and `herdr` starts. Information that isn't a fault, such as "your own `~/.config/nvim` is kept, so themes don't reach neovim", is ℹ, not ✗. The exit code is non-zero only for ✗, so the VM test can use it. doctor only reports; any fix is offered as a question, never done silently.

**Output that's pleasant to read.** Everything omamac prints (install, doctor, uninstall, update) is polished and visual, not plain walls of text, and as short as it can be: people installing something want to read as little as possible.

Running the one-liner again on an already set-up Mac is safe: it updates omamac and changes nothing else.

## omamac and Homebrew

omamac works with Homebrew, never alongside or instead of it. Everything omamac installs is a Homebrew formula or cask, and every lifecycle step is a Homebrew command run on the user's behalf. omamac never rebuilds anything Homebrew already does. The goal is that every app omamac offers ends up managed in one place: Homebrew.

**The one exception is programming languages.** mise (itself a Homebrew formula) installs and records language runtimes. For languages, omamac asks mise exactly the way it asks Homebrew about everything else (`mise ls`, `mise outdated`, `mise uninstall`).

- **Homebrew (and mise, for languages) knows what's installed; omamac knows what the user chose.** omamac keeps no list of installed packages of its own. Its only record is the saved choices. Whenever it needs to know whether something is installed or outdated, it asks Homebrew (`brew list`, `brew outdated`).
- **Homebrew in the wrong place stops the run.** On Apple Silicon, Homebrew belongs in `/opt/homebrew`. A Mac moved over from an Intel Mac with Migration Assistant may carry an old Homebrew in `/usr/local`, running under Rosetta. omamac detects it before changing anything, stops, says why and points to Homebrew's own instructions. Once Homebrew is in the right place, running the one-liner again continues as normal.
- **What omamac offers and the user picks, omamac owns for its whole life:** install (`brew install`), update notices and updates (`brew outdated`, `brew upgrade`), and uninstall (`brew uninstall`), always scoped to the user's choices.
- **What the user installs with Homebrew on their own stays theirs.** omamac never touches a formula or cask the user didn't choose through omamac: no global `brew upgrade`, never `brew bundle cleanup`, no claiming packages it finds in `brew list`.
- **Already installed with Homebrew, then chosen.** If the user picks something in `omamac install` that Homebrew already has (for example an app they installed with `brew install --cask` before omamac offered it), omamac skips the install, saves the choice, applies its config under the config-safety rules (see "Config safety on macOS"), and owns it from then on, uninstall included.
- **Installed by hand, outside Homebrew** (an app dragged in from a .dmg). When the user picks an app that is already in Applications but unknown to Homebrew, omamac never overwrites it or fails on it. It tells the user and offers to hand it over: "Spotify is already installed, but not through Homebrew. Let Homebrew take it over so it's updated and managed like your other apps? (y/n)". On yes, omamac runs `brew install --cask --adopt`, saves the choice and owns the app from then on. On no, the app is left exactly as it is and stays out of the choices. An app whose cask runs an installer package (Zoom, Google Drive) can't be adopted without being installed again over the user's copy, so omamac says so and leaves it out of the choices.
- **Uninstalling asks, then confirms.** For each app the user removes, omamac asks whether to remove the app only (`brew uninstall`) or the app with its settings and data (`brew uninstall --zap`), with nothing pre-selected: "Also remove its settings and data?", where Enter alone is no, like omamac's other yes/no questions. It then shows what will be removed and asks for a final confirmation before anything is deleted.
- **Drift is reported, never fixed silently.** If something chosen was removed behind omamac's back (a manual `brew uninstall`), `omamac doctor` says so and offers to reinstall it or drop it from the choices.
- **App Management comes first.** On macOS, changing an installed app (`brew upgrade` of a cask, `uninstall`) needs the terminal to have App Management. Without it, Homebrew deletes and reinstalls the app, which loses its Dock place and its permissions. `--adopt` leaves the app where it is (Homebrew only records it), so it needs no App Management. A script can't grant this permission, so it is a manual click in the "After install" page (`docs/after-install.md`, linked from the README) (Privacy & Security → App Management → Ghostty, where `omamac` commands run). Before any of those steps, omamac checks it has App Management (except for installer-package apps such as Zoom: their app is root-owned, and Homebrew changes it with sudo); if not, it stops, changes nothing and shows the click, opening the right Settings pane if macOS allows it.

## Config safety on macOS

omamac configures tools whose config files the user may already have written, on a used Mac often long before omamac arrived. omamac follows one rule everywhere. The rule is written for the Mac; it shares omawsl's idea, not omawsl's file lists.

**omamac writes freely only to files it owns, inside its own folder. A config file the user also uses gets at most one line from omamac: a guarded include that points at omamac's file.**

- **omamac's own files.** omamac's checkout, `~/.local/share/omamac`, is read-only code: nothing ever writes to it except `git` during `omamac update`, so updates never meet local changes. Everything omamac generates (the Ghostty, zsh, starship, neovim, btop and herdr configs, and the active theme for each) lives in `~/.config/omamac/`; choices and migration state live in `~/.local/state/omamac/`. omamac creates, rewrites and deletes these freely. `omamac theme` and `omamac update` only ever change these files, which is what lets one theme switch reach every tool at once.
- **The user's file gets one line.** The tool's normal config file holds a single include line pointing at omamac's file, added only if it isn't already there. Nothing else in that file is changed, reordered or reformatted. If a tool has a drop-in folder for extra config files, omamac puts its file there and leaves the user's file alone entirely.
- **The same result on every Mac.** On a new Mac the user's file doesn't exist yet, so omamac creates it holding just the include line. On a used Mac the line is appended to the file the user already has. Either way omamac's file and the line are identical, and a second run finds the line and changes nothing.
- **The line goes where the tool actually looks.** Some tools read config from more than one place. omamac adds its line to the existing file the tool loads last, so nothing loaded after it can undo omamac's settings, and creates one fixed default path only when no file exists. Example: Ghostty on macOS reads `config.ghostty` or `config` (the name before 1.2.3) under `~/.config/ghostty/` and then under `~/Library/Application Support/com.mitchellh.ghostty/`. If none exists, omamac creates `~/.config/ghostty/config.ghostty`. The line is `config-file = ?<omamac's ghostty file>`; the `?` makes it optional, so Ghostty never errors if omamac's file is gone.
- **omamac wins on the settings it sets.** When the user's file and omamac's file set the same setting, omamac's value is used, so the chosen theme and omamac's key bindings apply the same way on every Mac. In return, omamac sets as few settings per tool as it can (for Ghostty: theme, `macos-option-as-alt`, Option ←/→ for herdr, Cmd D switched off, and starting herdr), and the installer tells the user which settings it takes over. Every setting omamac doesn't set stays the user's. Where a tool's load order would let the include lose, omamac places the line so it wins (in `~/.zshrc`, at the end). The exception is a tool that can't include omamac's file at all: there the user's own file wins whole (see the next bullets).
- **Tools that read one config file and can't include another** (herdr, starship, btop): omamac keeps its file in `~/.config/omamac/` and points the tool at it with the tool's own variable (`HERDR_CONFIG_PATH`, `STARSHIP_CONFIG`) or, for btop, which has none, an alias that passes the file (`btop -c`), set in omamac's zsh file only when the user has no config file of their own. If they do, it is used untouched, and `omamac doctor` explains (ℹ) that omamac's settings don't reach that tool, as for neovim below. omamac's own file is omamac's: changes made to it, by hand, from the tool's own settings screen (herdr's Ctrl g ,) or written back by the tool (btop saves its settings on exit), are replaced on the next update or theme switch, and the docs say so (`docs/herdr.md`, `docs/themes.md`). Likewise a language version the user pins in their own mise config wins over omamac's.
- **Apps that take extensions** (VS Code): omamac installs an extension of its own with the app's own command, and the extension sets omamac's defaults (VS Code's theme). The user's settings file is never written, and a setting the user made there wins.
- **Files with no include mechanism** (for example a JSON settings file) are edited only as a last resort: back up first (`<file>.bak`), add or change only omamac's own keys, and skip with a message, never a rewrite, if the file isn't valid.
- **Config folders with no include mechanism** (neovim's `~/.config/nvim` is a whole folder, not a file that takes one line): if the folder already exists, omamac leaves it alone, adds no files beside it, and says so. `omamac theme` then can't reach neovim, and `omamac doctor` explains why (ℹ, not ✗) and asks: "Move your neovim config aside so omamac can set up its own? (y/n)". On yes, it renames the folder to `~/.config/nvim.bak-<date>` (nothing is deleted) and sets up omamac's neovim config; renaming it back restores the user's own. On no, nothing changes. On a fresh Mac the folder doesn't exist, and omamac sets up its neovim config as planned.
- **Shell files.** `~/.zshrc` gets one guarded line that sources omamac's zsh config. `~/.zprofile` gets one guarded line that puts Homebrew on the PATH, only if it isn't already there.
- **Uninstall removes exactly what omamac added:** its line in each user file and its own files. A file omamac created that still holds only its line is deleted; anything the user added is left as is.
- **Drift is reported, never fixed silently.** If the user removed omamac's line by hand, `omamac doctor` says so and offers to put it back.
- **Files omamac never creates or modifies** are listed in the repo, and a bats test fails if a change ever writes to one of them. The starting list is under "Settled decisions".

## What omamac sets up (scope)

**Foundations**
- Command Line Tools and git (through Homebrew's installer), Homebrew, Homebrew bash 5, and `gum` (by Charm, as in omawsl) for polished questions, pickers, spinners and styled output.
- The bootstrap script runs on macOS's built-in bash 3.2, so it stays 3.2-safe until it has installed bash 5, then re-runs itself under bash 5.

**The core: installed for everyone, no question asked**
- Ghostty, herdr, the zsh config, starship, neovim, btop and mise.
- The small tools omawsl's aliases and LazyVim rely on: eza, bat, zoxide, fzf, ripgrep, fd, lazygit and tree-sitter-cli. jq comes along because herdr's key bindings need it.
- Everything else is optional and asked about, with nothing pre-selected.

**Developer environment** (largely borrowed from omawsl)
- Shell: the user's zsh (macOS default), configured with the same aliases and prompt as omawsl.
- Prompt: starship. Editor: neovim. Monitor: btop.
- Multiplexer: **herdr only** (`brew install herdr`), with omawsl's herdr config and key bindings. zellij is not offered: one multiplexer means one config, one set of bindings and no question to ask.
- Languages via mise, at the latest version when chosen: Ruby on Rails, Node.js, Go, Python, Elixir, Rust, Java. PHP is left out for now (see "Backlog").
- Cloud CLIs via Homebrew: Azure CLI, AWS CLI, Google Cloud CLI, GitHub CLI (`gh`), and Terraform from HashiCorp's official tap (`hashicorp/tap/terraform`), since it's no longer in Homebrew's main repository.
- Coding agents via Homebrew, their own question after the cloud CLIs: Claude Code, Codex CLI, GitHub Copilot CLI, Antigravity CLI (Google's successor to Gemini CLI) and opencode. Codex CLI and Copilot CLI are the one exception to "proven in the VM": their casks run the binary during `brew install`, which a fresh VM's first-launch check never lets finish, while a real Mac installs them in seconds; Gate B proves them instead. They run in the terminal, in herdr. omamac installs, updates and uninstalls them like the cloud CLIs; signing in stays with the user. The same tools as desktop apps are the "AI apps" group of the app catalog, so someone who prefers a window and someone who prefers the terminal each pick their own.
- Docker: one choice, nothing pre-selected: colima, Docker Desktop or none. colima runs as a background service that starts at login.

**Terminal and look**
- **Ghostty and herdr are the terminal pair.** Ghostty is the only terminal app and herdr runs inside it. Opening Ghostty runs `herdr`, which attaches to the running herdr session or starts one: the user never starts, configures or thinks about herdr. If herdr fails to start, Ghostty falls back to plain zsh with a one-line message, so the terminal is never empty. Ghostty's own tabs still work, with their Cmd keys, but omamac doesn't promote them; herdr does that job. Ghostty's split keys (Cmd D, Cmd Shift D) do nothing, because a Ghostty split showed the same herdr session twice. Ghostty gets `macos-option-as-alt = left` so the left Option key is Alt for herdr and the right one still types special characters (Polish letters and the like). Ghostty's own Option ←/→ (a word back or on) is unbound, so those keys reach herdr as Alt ←/→, as on omawsl.
- omawsl's 13 themes, applied to Ghostty, neovim, btop, herdr, the prompt and VS Code in one step. The first run asks which theme (nothing pre-selected) and applies it, so the user sees it the first time they open Ghostty; `omamac theme` switches later.
- Ghostty's built-in font (JetBrains Mono, with Nerd Font symbols built in): nothing to install. omamac sets no size until you pick one with `omamac font-size` (10 to 20, with hints such as "laptop" or "external monitor"), for a screen that wants bigger or smaller text.

**Desktop apps (Mac only, new compared to omawsl)**
Because omamac runs natively on the host, it can install real desktop apps as Homebrew casks, in the spirit of Omakub and Omarchy. Offered as optional, grouped choices:

| Group | Apps in v1 |
| --- | --- |
| Browsers | Brave, Chrome, Firefox |
| Communication | WhatsApp, Telegram, Signal, Discord, Slack, Zoom |
| Media | Spotify, VLC |
| Screen recording | Cap (`cap` cask) |
| Storage and sync | Dropbox, Google Drive |
| Developer | VS Code |
| AI apps | Claude, ChatGPT (includes Codex), GitHub Copilot, Antigravity |
| Productivity | Raycast, Obsidian, AltTab |
| Voice dictation | Wispr Flow |

An app joins the catalog only if it installs cleanly as a cask with no prompt other than Homebrew's one password step right after "Install?" (see "What the user experiences"), proven in the VM; one that fails the rule is dropped, not worked around. An app the user already installed by hand is detected and offered to Homebrew for adoption, never overwritten or failed on (see "omamac and Homebrew"). The catalog starts small and grows; adding an app should be one small file.

**Prompts a script can't answer stay with the user.** macOS asks to confirm the first launch of each downloaded app (Gatekeeper), and apps ask for permissions such as Microphone, Screen Recording or Accessibility. omamac never weakens a security setting to skip them. Each app's catalog file lists the permissions it needs, and the end-of-run summary and the "After install" page (`docs/after-install.md`, linked from the README) are built from those lists.

**Cap** is an open-source screen recorder (an alternative to Loom) and installs as the `cap` cask. It needs Screen Recording, and Camera and Microphone if used, granted on first launch; those clicks go in the end-of-run summary and the "After install" page (`docs/after-install.md`, linked from the README). Its account and any paid features stay with the app.

**macOS desktop, Dock and trackpad settings**
Seven yes/no questions, each applied with `defaults`:
- *Desktops:* desktops are not rearranged by recent use, switching to an app goes to its desktop, Ctrl 1 to Ctrl 6 jump to desktops 1 to 6, Reduce motion is on. The question's text names Reduce motion openly ("…and turns on Reduce motion, which shortens animations everywhere").
- *Window margins:* tiled windows get margins between them.
- *Desktop widgets:* widgets are hidden from the desktop (the Weather and other widgets a new Mac shows).
- *Dock:* Apple's preinstalled apps and the Downloads stack are removed from the Dock (not from the Mac), apps the user pinned stay, the apps omamac installed are added after them in catalog order, and suggested and recent apps are turned off so Apple's apps don't creep back. Scriptable with `dockutil` (a Homebrew formula) or `defaults`.
- *Dock auto-hide:* the Dock hides when not in use, leaving more of a 14-inch screen for work.
- *Tap to click:* a light tap on the trackpad clicks, without pressing it down.
- *Tap to drag:* tap twice, keep the finger down on the second tap, and move it to drag; lifting it drops. It is macOS's dragging "Without Drag Lock", chosen by Tuna over three-finger drag, which would also move the three-finger swipes to four fingers. With Drag Lock and three-finger drag stay out until someone asks; if they come, the question becomes a single choice of drag style.
- The user's previous values, including the full Dock layout, are saved first; `omamac configure <setting> off` restores them. `omamac doctor` reports any that drifted.
- If macOS refuses a setting from Terminal (Reduce motion can be protected), omamac doesn't fail; the end-of-run summary gives the one click instead.
- Creating desktops and assigning apps to them stay manual: macOS has no supported way to script either. The "After install" page (`docs/after-install.md`, linked from the README) says to make six desktops in Mission Control, each with a purpose (browser and chat, code and terminal, documents, monitoring, …), the opinion omakub and Omarchy share, then Assign To from each app's Dock menu.

**Voice dictation (its own question)**
With AI agents, more and more work is talking rather than typing: people dictate prompts to their coding agents, messages and notes all day. A Mac that is "ready to work" in that world has a good dictation app, so omamac asks about it as its own question instead of hiding it under Productivity.

- **v1 offers one app, Wispr Flow, as a yes/no question.** It's the one Tuna uses every day and can vouch for. Other apps (Superwhisper, VoiceInk and the like) can join later if users ask for them; if they do, the question becomes single choice, because dictation apps all compete for the same global hotkey.
- The question says in a few words that Wispr Flow processes speech in the cloud.
- Microphone and Accessibility permissions can't be granted by a script, so the end-of-run summary tells the user exactly what to allow on first launch.
- Sign-in, subscriptions and licences stay with the app; omamac never asks for them.

## How we know it works

**Every install change is tested as a stranger would use it.** No install is ever tested on Tuna's development Mac. Each test runs in a throwaway macOS VM (Tart) made from a clean image that has nothing on it, not even Homebrew, and behaves like an end user who is not Tuna:

1. Copy the clean image, boot it, connect over SSH.
2. Run the public one-liner exactly as the README shows it (pointing at the branch under test), answering the first-run questions from a fixture file.
3. Check: the install succeeds, `omamac doctor` passes, everything chosen is present, and running the one-liner a second time changes nothing.
4. Keep the logs, delete the VM, pass or fail. Never reuse a test VM.

This is why the repo is public from day one: the VM must fetch omamac with no credentials, like a stranger would.

**Where the tests run.** macOS VMs need real Apple Silicon, so the VM loop runs on Tuna's Mac through one script (`test/vm.sh <branch> <fixture>`); omamac itself only ever runs inside the VM. GitHub's macOS runners come with Homebrew and many tools preinstalled, so they can't stand in for a fresh Mac, and a self-hosted runner on a public repo would let pull requests from forks run code on Tuna's Mac. The bats suite needs no VM and runs in GitHub Actions on every push.

**Nobody sits at the keyboard.** Whoever starts `test/vm.sh` only reads ✓ or ✗ at the end. The script clones the image, boots it, pastes the one-liner over SSH, types the sudo password when asked (the throwaway VM's own password, never Tuna's, typed with `expect` like a person would), answers the questions from the fixture, runs the checks, saves the log and deletes the VM.

**The clean image.** Exactly one clean image stays on disk, made from Cirrus Labs' `macos-*-vanilla` (no Homebrew). Downloading it for every run would take longer than the time budget. Every test VM is a copy-on-write clone, deleted when its run ends, and `test/image.sh` clears Tart's download cache after building the image; the Mac has a 512 GB disk. When a macOS update ships, the image is replaced, never kept alongside the old one.

**The VM behaves like a real user's Mac.** The vanilla image comes with passwordless sudo and Gatekeeper switched off, which would hide the password prompt and first-launch warnings a real user sees. When the clean image is made, both are put back once: `/etc/sudoers.d/admin-nopasswd` is deleted and Gatekeeper is switched on.

**Time budget.** Each PR's VM run uses a fixture that installs only what the PR touches, and stays under about 30 minutes. A run with every option happens before release (Phase 7).

**Answer fixtures are for tests only.** Users always answer the first-run questions interactively; the fixture mechanism is not documented for them in v1. A test copies its fixture to `~/.local/state/omamac/choices.env` before running the one-liner, so omamac finds the questions answered and skips them, the same path a re-run takes; it still shows the summary and "Install? (y/n)", which `expect` answers. The question screens themselves are covered by bats tests.

**Who runs the tests.** Tuna or an agent (Claude) may run `test/vm.sh` on Tuna's Mac and post the result and a log summary on the PR. The agent may also install the test tools (Tart, bats, shellcheck) on that Mac, build the clean image and boot test VMs to debug; omamac itself still runs only inside VMs. Gate files (the ruleset, the CI workflow, `test/vm.sh`, `test/vm.exp`, `test/fingerprint.sh`, `test/image.sh`) are written and changed by the agent, but only in a PR whose purpose is the gate itself, never to turn a red check green. CI flags every PR that touches them, and the agent names them when it reports to Tuna. The agent merges a PR once `bats` and `vm` are green and review findings are fixed; anything that needs Tuna's judgment is raised to Tuna first.

**Gate A (end of Phase 1):** the one-liner works in a fresh VM, and a second run changes nothing.

**Gate B (v1):** Tuna backs up, erases the Mac (System Settings → General → Transfer or Reset → Erase All Content and Settings), sets it up again using only the README, runs the one-liner, and works on it for a day. Anything that feels off, or any step the README missed, becomes an issue before release. This is also where Tuna first lives with the Mac-only tools he hasn't used before (Ghostty, Raycast, Cap, colima or Docker Desktop). Tools are not trialled by hand beforehand, because that would mean configuring them manually, the very thing omamac exists to avoid. Since nothing is pre-selected, a tool that doesn't earn its place is simply answered "no", or dropped from the catalog.

Until Gate B, omamac never runs on Tuna's Mac. That Mac is the development machine, kept stable; whatever is installed on it by hand until then is wiped at Gate B.

## How we build it

- **Repo:** `tunacinsoy/omamac`, public, cloned at `~/git-repos/omamac`. omawsl is cloned read-only at `~/git-repos/omawsl` for inspiration.
- **Tests:** a bats suite for logic, plus the VM loop for real installs.
- **Branches and PRs:** each phase on its own branch, pushed so the VM can fetch it; a PR per phase, merged by the agent once the gate is green.
- **Merge gate:** bats suite (GitHub Actions) and the VM loop (run on Tuna's Mac by Tuna or an agent, result recorded on the PR) green on the exact head commit of an up-to-date PR branch, enforced by a GitHub ruleset with no bypass, for admins and agents too. `bats` is pinned to GitHub Actions; `vm` is posted only by `test/vm.sh` on a pass. Gate files (the ruleset, the CI workflow, `test/vm.sh`, `test/vm.exp`, `test/fingerprint.sh`, `test/image.sh`) are written and changed by the agent, but only in a PR whose purpose is the gate itself, never to turn a red check green. CI flags every PR that touches them, and the agent names them when it reports to Tuna. The agent merges a PR once `bats` and `vm` are green and review findings are fixed; anything that needs Tuna's judgment is raised to Tuna first.
- **Conventions carried over from omawsl:** nothing pre-selected, config safety, idempotent scripts, migrations for changes to existing installs, comments that explain *why*. Carried over as rules; the code that follows them is omamac's own.

## Suggested roadmap

A suggested order, not a contract. Phases may be split, merged or reordered if that is simpler.

| Phase | Scope | Done when |
| --- | --- | --- |
| 1 | Repo skeleton, README, bootstrap one-liner (Homebrew → PATH → bash 5 → re-run), `omamac` command skeleton, bats suite, Tart and the clean image, VM test loop, CONTRIBUTING.md and merge gate | **Gate A** |
| 2 | First-run questions, answer fixtures for tests, saved choices | Answers saved; re-runs skip them; nothing pre-selected |
| 3 | Shell, prompt, editor, monitor, languages, cloud CLIs, herdr | Each installs, updates and uninstalls idempotently in the VM |
| 4 | Ghostty (opening straight into herdr), themes, macOS desktop and window-margin settings | Opening Ghostty lands in herdr; theme switching works everywhere at once; desktop settings apply, re-run changes nothing, uninstall restores them |
| 5 | Docker options; colima as a background service that starts at login | A container runs in the VM |
| 6 | Desktop app catalog, including Wispr Flow and Cap; adoption of hand-installed apps; uninstall with app-only or zap; Dock cleanup and Dock auto-hide, since the Dock needs to know which apps were installed | Apps install, update and uninstall cleanly, including ones already present by hand or through Homebrew; the Dock holds the installed apps, uninstall restores the old Dock |
| 7 | Docs, full VM run of every option, release | **Gate B**, then v1 |

## Settled decisions

Decided by Tuna. Don't reopen these without a real contradiction.

- Two independent repos, omawsl and omamac. omamac is a new repo, not a fork.
- No parity contract between them. Sister products sharing a mindset; borrow, don't bind.
- Fresh code, copied content: omamac's code is written from scratch with omawsl as a reference; configs, themes, aliases and key bindings are copied as is.
- Simplicity is the first principle.
- Ghostty is the terminal on the Mac.
- herdr is the only multiplexer, alongside Ghostty. zellij is not offered, and there is no multiplexer question.
- Opening Ghostty lands the user straight in herdr; they never start or set up herdr themselves.
- omamac goes beyond omawsl's scope and installs desktop apps.
- Voice dictation is offered as its own question; v1 offers only Wispr Flow, as yes/no.
- Cap is in the app catalog as the screen recorder.
- No tiling window manager (AeroSpace or similar): macOS desktops with the desktop settings are enough.
- The user's manual steps are documented in the README.
- Only what users see must be free of apt, Windows and WSL; planning documents may refer to omawsl.
- Installs are tested only in throwaway VMs, acting as an end user; the development Mac never runs omamac before Gate B.
- Gate B is a factory reset of the Mac followed by a real user run-through from the README. No manual tool trials before it.
- On the development Mac, repos live under `~/git-repos`.
- omamac is opinionated about the experience: it applies the desktop settings itself (fixed desktop order, jump to the app's desktop, Reduce motion), asked as one question, previous values restored when the setting is turned off (`omamac configure desktops off`). App-to-desktop assignment stays a README step.
- On opt-in, omamac removes Apple's preinstalled apps from the Dock (never uninstalls them) and puts the apps it installed there; the previous Dock is restored when the cleanup is turned off (`omamac configure dock off`).
- In the terminal, Ctrl bindings carry over from omawsl unchanged; no Ctrl ↔ ⌘ remapping.
- omamac works in harmony with Homebrew: Homebrew is the only record of what's installed, omamac records only the user's choices. Whatever omamac offers and the user picks, omamac owns for its whole life (install, update notices, updates, uninstall) through Homebrew commands, including things Homebrew already had before they were picked. omamac never touches what the user installed with Homebrew outside omamac and never rebuilds what Homebrew does.
- Apps from the catalog that the user installed by hand are detected and offered to Homebrew for adoption (`brew install --cask --adopt`); on yes omamac owns them, on no they are left untouched.
- Uninstalling an app asks whether to remove the app only or the app with its settings and data (`--zap`), nothing pre-selected, then asks for a final confirmation.
- omamac has its own macOS config-safety rules (not omawsl's lists): its content lives only in its own files; a user's config file gets at most one guarded include line, placed in the file the tool loads last; the result is the same on a new or a used Mac.
- When the user's config and omamac's set the same setting, omamac wins, so the theme and key bindings apply the same everywhere; omamac keeps the settings it takes over to a minimum and says which they are.
- The core, installed for everyone without a question: Ghostty, herdr, the zsh config, starship, neovim, btop, mise, and the tools the aliases and LazyVim need (eza, bat, zoxide, fzf, ripgrep, fd, lazygit, tree-sitter-cli). "Nothing pre-selected" applies to everything else.
- The first run asks for a theme (all 13 of omawsl's themes, nothing pre-selected) and applies it, so the user sees it on first opening Ghostty.
- mise is the one exception to "Homebrew is the only record": it manages language runtimes; Homebrew manages apps and tools, herdr included.
- Docker is one choice with nothing pre-selected: colima, Docker Desktop or none. OrbStack is not offered: its install stops at macOS's "Open?" dialog, so it can't run unattended.
- omamac's checkout is read-only code; generated configs live in `~/.config/omamac/`, choices and migration state in `~/.local/state/omamac/`.
- Ghostty runs `herdr`, which attaches or starts a session; if herdr fails, Ghostty falls back to zsh with a one-line message. Ghostty tabs and splits are not promoted.
- One admin password prompt per run, kept valid until the run ends and never stored; all questions come before any install. Exception: the casks that need the password (Docker Desktop, Zoom, Google Drive). Homebrew resets sudo and asks again, so omamac installs them in one Homebrew step right after "Install?", in the open, says so before "Install?", and never bypasses the reset.
- The v1 scope stays as described in this document.
- Xcode is not offered in v1.
- No general "edit answers" command: change a software answer by uninstalling one thing and installing another, and a macOS setting with `omamac configure`.
- `install` and `uninstall` are for software only; the macOS settings are `omamac configure`'s. A setting name given to install or uninstall points to configure and changes nothing.
- Answer files are for tests only; users answer interactively.
- `omamac uninstall` works per thing and restores the Mac to how it was before that thing; with nothing named, it asks which section, then what to remove. Core tools can't be uninstalled one by one (omamac says so and stops). omamac can't remove itself in v1: a known gap, in the Backlog.
- omamac never touches git identity, SSH keys or GitHub login; the README covers them.
- App Management for Ghostty is a manual README step; omamac checks for it before changing any installed app and stops with the click if it's missing.
- Dock on opt-in: Finder, the user's own pinned apps, omamac's apps (Ghostty, the catalog apps in catalog order, then Docker Desktop), Trash. Apple's apps and the Downloads stack leave the Dock.
- Reduce motion stays inside the desktops question, named openly in its text.
- Supported: macOS 27 and later; tests run on the latest.
- The Wispr Flow question doesn't mention macOS's built-in Dictation.
- The VM loop runs on Tuna's Mac via a script; bats runs in GitHub Actions. Each PR's VM run covers only what it touches (about 30 minutes); the full run happens before release. Test VMs are deleted after every run.
- Window margins and Dock auto-hide are in v1, each as its own yes/no question; the macOS settings are seven questions: desktops, window margins, desktop widgets, Dock, Dock auto-hide, Tap to click, tap to drag (the last two since 2026-11-25).
- Releases: `main` is what everyone installs, so every merge that changes what users get is a release. The PR title's type decides it (Conventional Commits: `feat` minor, `fix`/`perf`/`revert` patch, `!` major, the minor before 1.0; `docs`/`test`/`chore`/`ci`/`refactor`/`build`/`style` none), PRs are squash-merged, and a workflow tags the merge and publishes a GitHub release whose notes are the PR description's first paragraph. No stable branch or channels for now.
- `omamac update` follows omawsl's model: `git pull --ff-only` on `main`, timestamped migrations, regenerate configs, `brew upgrade` and `mise upgrade` for the user's choices only. Cloud CLI and coding agent casks are upgraded with `--greedy`; apps (Ghostty, Docker Desktop, the catalog) update themselves and are upgraded only when Homebrew lists them as outdated.
- `omamac doctor` is a doctor, not an alarm: ✓, ✗ or ℹ per check, each with why and the one fix; it only reports.
- Everything omamac prints is polished and visual, and as short as possible.
- Ghostty's built-in font; no font installed; a size only when picked with `omamac font-size`.
- Languages and cloud CLIs as omawsl offers them, except PHP for now; Terraform from HashiCorp's official tap; `gh` with the cloud CLIs.
- Coding agents as their own question (Claude Code, Codex CLI, GitHub Copilot CLI, Antigravity CLI, opencode), and their desktop apps as the AI apps group (Claude, ChatGPT with Codex, GitHub Copilot, Antigravity).
- A tool with one config file and no include (herdr, starship, btop) uses omamac's file only when the user has none; a user's own is left alone and doctor explains. The user's own mise pins win.
- The v1 app catalog is the 22 apps in the table plus Wispr Flow; an app that isn't a clean cask is dropped.
- Gatekeeper and permission prompts stay with the user, one line each in the summary, built from each app's catalog file.
- First-run question order: theme, desktop apps, Wispr Flow, desktops, window margins, desktop widgets, Dock, Dock auto-hide, Tap to click, tap to drag, languages, cloud CLIs, coding agents, Docker; adoption questions come after the questions at the first run, right after each app question in `omamac install`, before the summary; one summary and "Install?" at the end.
- An existing `~/.config/nvim` is left alone with no extra files; doctor explains (ℹ) why themes don't reach neovim and what to do.
- Homebrew in `/usr/local` on Apple Silicon stops the run with a pointer to Homebrew's instructions.
- One clean Tart image (from `macos-*-vanilla`) stays on disk; test VMs are deleted after each run; the image is replaced, never doubled.
- The clean image is made to behave like a real Mac: sudo asks for a password and Gatekeeper is on; `test/vm.sh` types the VM's own password with `expect`, so nobody needs to be present.

- `gum` draws all of omamac's output; the bootstrap installs it right after Homebrew, without a question.
- doctor offers to move an existing `~/.config/nvim` aside (renamed to `~/.config/nvim.bak-<date>`, never deleted) so omamac can set up its own.
- Test fixtures pre-fill the saved choices; `expect` answers the sudo password and the final "Install?"; bats covers the question screens.
- Agents may run `test/vm.sh`, build the clean image and debug in VMs, and report on the PR. Tuna doesn't write code: the agent writes everything, gate files included, changing those only in PRs about the gate, which CI flags. The agent merges once the gate is green and raises to Tuna anything that needs Tuna's judgment.
- Repo is public from day one (needed for the VM to fetch it without credentials).
- Bootstrap is bash 3.2-safe; everything after the re-run requires Homebrew bash 5.
- The user's zsh stays the login shell.
- Desktop apps come only from Homebrew casks; no Mac App Store (`mas`) in v1.
- Subcommands: install, update, theme, doctor, uninstall, configure; `omamac` alone asks which.
- Saved choices live in `~/.local/state/omamac/choices.env`.
- Testing a branch uses the one-liner with `<branch>` in the `boot.sh` URL and `OMAMAC_REF=<branch>`; `test/vm.sh` uses the commit SHA in the URL. Reason: `main`'s `boot.sh` can't test a branch that changes `boot.sh`, and the Phase 1 PR has no `main` `boot.sh` at all.
- Logs live in `~/.local/state/omamac/logs/` (newest 10).
- Apple Silicon only.
- Adoption is offered only for apps in omamac's catalog, at the moment the user picks them; omamac doesn't scan Applications for other hand-installed apps.
- Files omamac never creates or modifies, to start with: `~/.ssh/**`, `~/.gitconfig`, `~/.npmrc`, `~/.m2/settings.xml`, `~/.curlrc`, `/etc/hosts`, `/etc/resolver/*`, and anything else under `/etc` or `/Library` beyond what Homebrew's own installer does.
- The default branch is `main`.
- Licence: MIT (Tuna accepted that it allows commercial use).
- The merge gate is enforced by a GitHub ruleset with no bypass: `bats` (pinned to GitHub Actions) and `vm` (posted only by `test/vm.sh` on a pass) on the exact head commit of an up-to-date branch. It stops accidental merges, not deliberate fakes.

## Proposed defaults

Reasonable starting points that Tuna hasn't explicitly confirmed. None right now.

## Open questions

Not decided yet. None right now; new ones go here as the work teaches us something.

## Backlog (maybe, after v1)

Ideas Tuna wants kept in view but not built yet. Nothing here is a commitment; each item gets its own brainstorm before it moves into the roadmap.

**Remote access to your agents with Tailscale.** The Mac keeps running herdr and the coding agents inside it; the user should be able to reach them from wherever they are, for example from a phone with Termius over Tailscale, and keep working with their agents as if at the desk. A likely shape is one optional first-run question ("Reach this Mac's terminal from your other devices?") that installs Tailscale. To work out before it moves up:
- What the question turns on beyond installing Tailscale (for example macOS Remote Login for SSH), and what stays a manual click in the README.
- How the user lands back in their running herdr session when they connect remotely.
- Whether Termius is named in the README as a suggested client, or left to the user.
- Tailscale sign-in and account stay with the app; omamac never asks for them.
- What this means for the "Safe with the user's files" and "Files omamac never creates or modifies" rules (`~/.ssh/**` is on that list).

**PHP.** mise builds PHP from source on macOS, which needs about ten Homebrew build libraries that nothing would own, upgrade or remove. PHP comes back when there's a clean way to install it.

**More dictation apps.** Superwhisper, VoiceInk and the like could join Wispr Flow (the question then becomes single choice). No criteria yet; decide when someone actually asks.

**One output design for every command.** Settled in [#46](https://github.com/tunacinsoy/omamac/issues/46), and built: `lib/ui.sh` is the kit, and every command draws from it when stdout is a terminal; anywhere else (a pipe, the log, bats) it prints the plain text it always did. Every command's output is built from six blocks: a row, a heading, a sheet, a titled box, a count line, and gum's questions. Doctor becomes a sheet of checks with a "To fix" box and a "What you have" sheet. The one-liner, install and update show your answers as a sheet, then counted progress rows, then a Done box. Uninstall shows what it removes, and a failed run stops in a box with the log's last lines. Tuna's picks are 1B 2B 3B 4B 5B 6A 7B 8A 9A, and the issue holds every detail, so building it needs no more design talk. It is built after Gate B, so Gate B proves today's output first, and before v1 is tagged (Tuna, 2026-11-23). Since #54, VS Code changes theme live, so `omamac theme`'s Now row names it with Ghostty, herdr, btop and the prompt, and Next open holds only neovim.

**Removing omamac itself.** v1 uninstalls one thing at a time and can't remove omamac. A later `omamac uninstall omamac` could remove the core tools, omamac's include lines, its generated files, its state and the checkout, leaving the user's optional picks as ordinary Homebrew and mise installs. This closes the v1 gap against "uninstall restores the previous state".

## Out of scope for v1

- macOS system tweaks through `defaults` other than the four desktop, window and Dock settings above (Dock size, key repeat, Finder).
- Uninstalling Apple's preinstalled apps.
- A tiling window manager.
- zellij or any multiplexer other than herdr.
- Remote access (Tailscale); see "Backlog".
- Intel Macs.
- Mac App Store apps.
- Xcode.
- An answers file for users (unattended runs); fixtures are for tests only.
- An "edit answers" command.
- Removing omamac itself (its core tools, include lines, files and checkout); see "Backlog".
- Uninstalling a core tool on its own.
- Importing saved choices from omawsl.
- A corporate-Mac checklist, until a corporate Mac is available.

## Decisions log

One line per decision: date, question, answer, who decided. Move the item out of Open questions or Proposed defaults when it's settled.

- 2026-11-09 — Repo strategy — two independent repos, no parity contract — Tuna
- 2026-11-14 — Voice dictation tools — offered as their own group in the app catalog — Tuna
- 2026-11-14 — User's manual steps — documented in the README (Before you begin / Install / After install) — Tuna
- 2026-11-14 — Repo location on the development Mac — `~/git-repos/<repo>` — Tuna
- 2026-11-14 — WSL in docs — only what users see must be free of it; planning docs may refer to omawsl — Tuna
- 2026-11-14 — Gate B — set up from the README alone after a factory reset — Tuna
- 2026-11-14 — Desktop behaviour — omamac applies the desktop settings itself (opinionated about the experience); app-to-desktop assignment stays a README step — Tuna
- 2026-11-14 — Tiling window manager — none; AeroSpace is out, macOS desktops with the desktop settings are enough — Tuna
- 2026-11-14 — Voice dictation in v1 — Wispr Flow only, yes/no; others later on demand — Tuna
- 2026-11-14 — Manual tool trials before building — dropped; Gate B is where the Mac-only tools are first lived with — Tuna
- 2026-11-14 — Screen recorder — Cap joins the app catalog — Tuna
- 2026-11-14 — Dock — on opt-in, Apple's preinstalled apps leave the Dock (not the Mac) and omamac's apps take their place — Tuna
- 2026-11-14 — Communication apps — WhatsApp, Telegram and Signal join Discord, Slack and Zoom in v1's catalog — Tuna
- 2026-11-14 — Reuse from omawsl — fresh code written from the spec, omawsl as reference only; configs, themes, aliases and key bindings copied as is — Tuna
- 2026-11-14 — Keyboard — Ctrl bindings in the terminal carry over unchanged; no Ctrl ↔ ⌘ remap — Tuna
- 2026-11-14 — omamac and Homebrew — Homebrew is the only record of what's installed; omamac records choices and owns the full lifecycle of what the user picks, through Homebrew; user's own Homebrew installs are never touched — Tuna
- 2026-11-14 — Hand-installed apps — detected and offered to Homebrew for adoption; on yes omamac owns them, on no they stay untouched — Tuna
- 2026-11-14 — Uninstalling an app — user picks app only or app with settings and data (`--zap`), then confirms — Tuna
- 2026-11-14 — Config safety — omamac gets its own macOS rules: own files only, one guarded include line per user config, same result on new and used Macs — Tuna
- 2026-11-14 — Conflicting settings — omamac wins on the settings it sets, kept to a minimum and named at install — Tuna
- 2026-11-15 — Multiplexer — herdr only, alongside Ghostty; zellij is not offered and there is no multiplexer question — Tuna
- 2026-11-15 — Remote access with Tailscale (e.g. Termius from a phone) — backlog, maybe after v1 — Tuna
- 2026-11-15 — Ghostty and herdr — opening Ghostty lands the user straight in herdr; nothing to start or set up — Tuna
- 2026-11-16 — Core tools — Ghostty, herdr, zsh config, starship, neovim, btop and mise for everyone; "nothing pre-selected" covers the optional parts — Tuna
- 2026-11-16 — Theme — asked at first run (all 13 themes, nothing pre-selected) and applied so it's visible at once — Tuna
- 2026-11-16 — Languages — mise manages them, the one exception to Homebrew being the only record — Tuna
- 2026-11-16 — Docker — single choice, nothing pre-selected (colima, OrbStack, Docker Desktop, none); OrbStack leaves Developer apps — Tuna
- 2026-11-16 — Checkout — read-only code; generated configs in `~/.config/omamac/`, state in `~/.local/state/omamac/` — Tuna
- 2026-11-16 — Ghostty and herdr — Ghostty runs `herdr` (attach or start), falls back to zsh if it fails; Ghostty tabs not promoted — Tuna
- 2026-11-16 — sudo — one prompt per run, kept valid until the end, never stored; all questions before any install — Tuna
- 2026-11-16 — v1 scope — unchanged — Tuna
- 2026-11-16 — Xcode — dropped from v1 — Tuna
- 2026-11-16 — Changing answers — uninstall one thing, install another; no edit command — Tuna
- 2026-11-16 — Unattended runs — answer files for tests only — Tuna
- 2026-11-16 — Uninstall — per thing, restoring the state before that thing; no args asks what to remove; no remove-all command in v1 — Tuna
- 2026-11-16 — git identity, SSH, GitHub login — never touched; README covers them — Tuna
- 2026-11-16 — App Management — manual README step for Ghostty; omamac checks before changing apps and stops if missing — Tuna
- 2026-11-16 — Dock — Finder, user's pinned apps, omamac's apps in catalog order, Trash; Downloads stack removed — Tuna
- 2026-11-16 — Reduce motion — stays in the desktops question, named in its text — Tuna
- 2026-11-16 — macOS versions — macOS 27 and later; tests on the latest — Tuna
- 2026-11-16 — Built-in Dictation — not mentioned — Tuna
- 2026-11-16 — Test VMs — run on Tuna's Mac via a script, bats on GitHub Actions; per-PR fixtures (~30 min), full run before release; VMs deleted after each run — Tuna
- 2026-11-16 — Window margins and Dock auto-hide — in v1, each its own yes/no question — Tuna
- 2026-11-16 — Removing omamac itself — not in v1 (known gap), moved to Backlog; core tools can't be uninstalled one by one — Tuna
- 2026-11-16 — `omamac update` — omawsl's model: pull, migrations, regenerate, upgrade the user's choices — Tuna
- 2026-11-16 — Output — polished and visual everywhere, as short as possible; doctor explains rather than alarms — Tuna
- 2026-11-16 — Font — Ghostty's built-in font; nothing installed — Tuna
- 2026-11-16 — Languages and cloud CLIs — omawsl's lists; Terraform from HashiCorp's tap; `gh` added — Tuna
- 2026-11-16 — App catalog v1 — the 17 apps in the table plus Wispr Flow — Tuna
- 2026-11-16 — Unscriptable prompts — left to the user, one line each in the summary — Tuna
- 2026-11-16 — First-run question order — most visible to most technical, summary and confirm at the end — Tuna
- 2026-11-16 — Existing neovim config — left alone, no extra files; doctor explains — Tuna
- 2026-11-16 — Homebrew in `/usr/local` — detect, stop, point to Homebrew's instructions — Tuna
- 2026-11-16 — Clean VM image — one kept on disk, test VMs deleted after each run — Tuna
- 2026-11-16 — Test VM realism — sudo password and Gatekeeper put back in the clean image; the script types the VM's password — Tuna
- 2026-11-16 — Output tool — `gum`, installed by the bootstrap right after Homebrew — Tuna
- 2026-11-16 — Existing neovim config — doctor offers to rename it to `~/.config/nvim.bak-<date>` and set up omamac's — Tuna
- 2026-11-16 — Test fixtures — pre-fill the saved choices; bats covers the question screens — Tuna
- 2026-11-16 — VM tests — agents may run `test/vm.sh` and report on the PR; merging stays Tuna's — Tuna
- 2026-11-16 — More dictation apps — Backlog, no criteria until someone asks — Tuna
- 2026-11-16 — Remaining proposed defaults (public repo, bash 3.2 bootstrap, zsh login shell, casks only, five subcommands, choices.env, OMAMAC_REF, Apple Silicon only, catalog-only adoption, never-touch file list) — confirmed — Tuna
- 2026-11-16 — Default branch — `main`, GitHub's default; the one-liner, `OMAMAC_REF` and `omamac update` use it — Tuna
- 2026-11-16 — Merge gate — enforced by a GitHub ruleset: `bats` and `vm` required on the exact head commit of an up-to-date branch, no bypass — Tuna
- 2026-11-16 — Licence — MIT; chosen knowing it allows commercial use — Tuna
- 2026-11-16 — Gate files — written by the agent, changed only in gate-purpose PRs that CI flags; Tuna merges, doesn't write code; agents may build the image and run VMs — Tuna
- 2026-11-17 — Merging — the agent merges PRs itself once `bats` and `vm` are green and review is done; it raises to Tuna only what needs Tuna's judgment — Tuna
- 2026-11-17 — Core tools for the aliases and LazyVim — eza, bat, zoxide, fzf, ripgrep, fd, lazygit and tree-sitter-cli join the core, as on omawsl — Tuna
- 2026-11-17 — A user's own herdr or starship config (no include possible) — left untouched, doctor explains; omamac's file is used only when there is none; the user's mise pins win — Tuna
- 2026-11-17 — PHP — dropped from the languages for now (mise compiles it on macOS); in the Backlog — Tuna
- 2026-11-17 — herdr's settings screen writes into omamac's herdr file — omamac rewrites its file anyway, so herdr always follows omamac's theme; the README warns; own settings go in `~/.config/herdr/config.toml` — Tuna
- 2026-11-19 — Docker — OrbStack dropped; the choice is colima, Docker Desktop or none (OrbStack's install waits on macOS's "Open?" dialog, so it can't run unattended or be tested in the VM) — Tuna
- 2026-11-19 — Password — Docker Desktop's cask: Homebrew resets sudo and asks once more; omamac runs that step right after "Install?", in the open, and never bypasses the reset — Tuna
- 2026-11-19 — Zoom and Google Drive — kept in the catalog; with Docker Desktop they share one Homebrew step right after "Install?", so Homebrew asks for the password once more, once for all of them — Tuna
- 2026-11-19 — Upgrading apps — no `--greedy`; an app is upgraded only when Homebrew lists it as outdated, since apps update themselves; `--greedy` stays for the cloud CLI casks — Tuna
- 2026-11-21 — AI tools in v1, before Gate B — coding agents as their own terminal question (Claude Code, Codex CLI, GitHub Copilot CLI, Antigravity CLI, opencode), and an AI apps group of desktop apps (Claude, ChatGPT, GitHub Copilot, Antigravity), for parity with omawsl. Gemini CLI is deprecated in Homebrew (disabled 2026-12-18), so Antigravity CLI, its successor, takes its place; the Codex app is now part of ChatGPT's. Codex CLI and Copilot CLI are proven on a real Mac, not in the VM, whose first-launch check never lets their casks finish. Languages stay with mise and everything else with Homebrew. Google's one AI app is Antigravity, its coding tool; the Gemini chat app is left out — Tuna
- 2026-11-21 — VS Code follows the theme, before Gate B, as in omawsl — Tuna. How (Claude's call): omamac's own extension holds the theme and makes it VS Code's default, so omamac never writes `settings.json` and a theme the user set wins; omawsl's merge into `settings.json` was dropped as too much careful code for a file that breaks the editor when broken.
- 2026-11-21 — Ghostty's keys — Cmd D and Cmd Shift D do nothing (a Ghostty split showed the same herdr session twice; herdr splits with Alt n); Ghostty's tab keys stay Ghostty's, since herdr has its own (Ctrl g t, Option ←/→) — Tuna
- 2026-11-21 — `omamac install` targets — a section (`omamac install languages`) or names (`omamac install go rust`), as omawsl's `install <category> <item>`, so adding one thing doesn't walk every question; the names are `omamac uninstall`'s; "Install?" still comes last — Tuna (how: Claude)
- 2026-11-22 — Output design — one kit of six blocks for every command, settled in #46 (1B 2B 3B 4B 5B 6A 7B 8A 9A); built after Gate B — Tuna
- 2026-11-23 — From Gate B (#36), before v1 — Tuna: Ctrl 1–6 switch desktops, inside the desktops answer; desktop widgets hidden, as their own question (Claude's call); the README's "After install" becomes a tick list; six desktops with a purpose each, as a README step, since macOS can't create desktops from a script; VS Code changes theme live, not only the next time it opens, still without omamac writing `settings.json` (how: Claude's call; back to Tuna if no way exists).
- 2026-11-23 — Output design (#46) — in v1: built after Gate B's fixes, before the tag; one PR with the last fixes (new questions named after an update, #48, fingerprint lines), so one VM round — Tuna
- 2026-11-23 — Doctor, after Tuna saw #46's build (picks 1B 2A 3B 4B on the draft page) — every check keeps its own line (1B), each with a short plain explanation of what it is (Claude's call, since "bash 5" alone means nothing to a user); tools show their version and whether a newer one is out (2A); apps one per line with the version the app itself reports, no "newer" column since apps update themselves (3B); tools in a group per kind, as in omawsl: Languages, Cloud CLIs, Coding agents, Docker, then Apps (4B) — Tuna
- 2026-11-23 — Doctor, second round (draft page picks 1B 2B 3A) — by default four area lines (omamac, Terminal, Theme, macOS), a problem shown under its area with its fix, then tools with "latest" or "<new> is out" and apps with their version; `omamac doctor --all` lists every check with a plain name, one sentence on what it is, and a See line pointing to where it lives on the Mac, ending with one link to the README's "What it changes". Replaces the earlier 1B (every check by default) — Tuna
- 2026-11-23 — README redesign (approved draft) — the README follows omawsl's: short and visual (logo, hero, What you get, See it, daily commands, Good to know); all long detail moves to `docs/` pages (install, after-install, updating, themes, herdr, uninstalling, what-it-changes, testing-changes); `omamac doctor --all` now links `docs/what-it-changes.md` — Tuna
- 2026-11-23 — First release — 0.1.0, not v1: v1 waits for more polish and product marketing; 0.1.0 is tagged after the README redesign so people who find it see the new page — Tuna
- 2026-11-24 — `omamac configure` and menus (#60) — the macOS settings leave `install` and `uninstall` (software only) for a new `omamac configure [<setting> [on|off]]`; `omamac` alone asks what to do, and install and uninstall ask the section first, so no name has to be remembered; old setting names point to configure, no alias; ships as 0.2.0, since commands that worked in 0.1.0 change — Tuna (how: Claude)
- 2026-11-25 — Trackpad settings — Tap to click and a drag setting join the macOS settings, each its own yes/no question after Dock auto-hide, turned on and off with `omamac configure tap-to-click` and `tap-to-drag` — Tuna (how: Claude)
- 2026-11-25 — Drag style — tap to drag without Drag Lock, not three-finger drag (#62 shipped three-finger drag first; replaced before any release) — Tuna
- 2026-11-27 — Font size — `omamac font-size` picks Ghostty's size, 10 to 20 with hints or Default, from its own menu entry; not a first-run question; prints one line; the user's own Ghostty config is never written — Tuna (how: Claude)
- 2026-11-27 — Releases — every user-facing merge to main is a release, versioned from the PR title's Conventional Commits type by a workflow; squash merges only; a `pr-title` check joins the gate; GitHub Releases is the changelog; no stable branch or channels until outside users depend on omamac — Tuna (how: Claude)
- 2026-11-27 — Password prompt — a Homebrew step that may ask keeps a live row (download, then "removing the old version" or "installing the new version"); when sudo waits, the row says "Spotify needs your Mac password" with the reason under it, right above sudo's own prompt; the "Homebrew may ask" lines go. omamac still never feeds or skips the prompt (no `SUDO_ASKPASS`) — Tuna (how: Claude)
- 2026-11-27 — Window switcher — AltTab joins Productivity; picking it makes Cmd+Tab open AltTab, so two windows of one app (a private and a normal Brave window, two VS Code windows) can be told apart; written once at install and adoption, uninstall gives Cmd+Tab back — Tuna
