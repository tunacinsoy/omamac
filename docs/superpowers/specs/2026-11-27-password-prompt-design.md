# Password prompt — design

Small change. Approach A picked by Tuna on 2026-11-27.

## Why

`omamac update` printed "Homebrew may ask for your password." and then nothing until a bare `Password:` showed up, sometimes much later. The user can't tell if omamac is stuck, downloading, or waiting for them, or why a password is needed at all. On Tuna's run, Spotify's upgrade asked because its old version's uninstall step removes a launchctl service.

## Goals

- While a Homebrew step that may need the password runs, its row stays on screen with a spinner and says what Homebrew is doing: the download's size and speed, then "removing the old version" or "installing the new version".
- The moment sudo needs the password, and only then, the row turns into "Spotify needs your Mac password", with a short reason under it ("to stop its background helper.") and the `Password:` prompt under that.
- The "Homebrew may ask for your password." and "Homebrew asks for your password for: …" lines just before a step go away; the prompt says it now. The notice before "Install?" stays (vision: say so before "Install?").

## Non-goals

- No change to how often the password is asked. Homebrew still resets sudo and asks; omamac never bypasses the reset (2026-11-19 decision).
- No password prompt for commands under gum's spinner (`ui_run`); none of them needs sudo.
- No per-app warning ahead of time from the casks' uninstall steps (option B), for now.

## Anti-goals

- The password is never stored, logged or written to a file. It goes from the terminal straight to sudo.

## Approaches

- **A. A live row that says when to type (picked).** See below for how.
- B. Warn ahead by app name, from the casks' uninstall steps. Guesswork; doesn't fix the wait.
- C. `sudo -v` at the start of update. Homebrew resets sudo, so it asks again anyway.

## Decided

- A, wording "Spotify needs your Mac password" with a reason under it, download and removing/installing phases kept, B not now.
- Draft: https://claude.ai/artifact/PXtSAYnsVndi9AonwiWRss

## Builder's calls (Claude)

- **omamac never touches the password.** Tuna asked to keep the earlier rule (Phase 6 anti-goal, hygiene test): no `SUDO_ASKPASS`, no `HOMEBREW_SUDO_CHECKED`. sudo keeps asking on the terminal itself; omamac only watches and labels the prompt.
- **How it knows sudo waits.** Every spinner frame (0.2 s) omamac lists processes and looks for a `sudo` under the Homebrew command. A sudo that has started its command has a child; a sudo with no child for two frames in a row is waiting for the password. A sudo that runs at once (cached, or Homebrew's own timestamp reset) never reaches two frames.
- **Where the words go.** The spinner row keeps two empty lines under it, and the cursor waits on the lower one. sudo prints `Password:` there. While any sudo runs, the row isn't redrawn, so nothing moves the cursor under sudo. When sudo waits, omamac saves the cursor, writes "Spotify needs your Mac password" on the row and the reason on the line under it, and puts the cursor back after `Password:`. A wrong password: sudo prints "Sorry, try again." and asks again under it, as it always has. Once sudo runs its command or ends, the spinner goes on, on a new line.
- **Who and why.** Who: the step's title minus its verb ("Upgrading Spotify" → "Spotify"; a comma or "and" makes it "need"). Why: the last `==>` line Homebrew wrote to the log during this command: an installer, a launchctl service, packages or files, links, else "to change system files". "its" becomes "their" for several apps.
- **Plain text** (no terminal look, e.g. a pipe): unchanged, the step's title then sudo's own prompt. `test/vm.exp` still sees exactly one `Password:` per prompt, sudo's.
- In the terminal look, `ui_run_open` (install, remove) uses the same live row, so every password prompt gets the label, not only update's.
- Docs: `docs/updating.md`, `docs/uninstalling.md`, `docs/install.md` reworded where they say "Homebrew may ask". `vision.md` gets the prompt wording in "What the user experiences" and a dated decision.
- Tests: bats with a stand-in sudo (named `sudo` through `exec -a`) that prints `Password:` and waits without a child: the label and reason land above it, once; a sudo with a child gets no label; phases on the row; the hygiene test stays. The `full` VM fixture (Zoom, Google Drive, Docker Desktop install and removal) proves it with real sudo, and that `vm.exp` still counts one password per prompt.
