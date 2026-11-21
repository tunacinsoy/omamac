# Phase 7c: AI tools — design

Status: draft · 2026-11-21 · Source of truth for the why: [`vision.md`](../../../vision.md) (Decisions log, 2026-11-21)

## Intent

A Mac that is ready to work has an AI coding agent on it. omawsl offers them; omamac didn't. 7c adds two menus before Gate B, so Gate B tests them:

- **Coding agents**, for the terminal: a new multi-select question after the cloud CLIs.
- **AI apps**, the same vendors' desktop apps: a new group in the app catalog.

Someone who prefers a window picks the app, someone who prefers the terminal picks the agent, and someone can pick both.

## The options

Checked on 2026-11-21 with `brew info`, including each cask's and formula's `deprecated` flag: none is deprecated, none needs a password to install, none has a `pkg` or installer step.

| Menu | Label | Id | Homebrew |
| --- | --- | --- | --- |
| Coding agents | Claude Code | `claude-code` | cask `claude-code` (a binary) |
| Coding agents | Antigravity CLI | `antigravity-cli` | cask `antigravity-cli` (command `agy`) |
| Coding agents | opencode | `opencode` | formula `opencode` |
| AI apps | Claude | `claude` | cask `claude`, `Claude.app` |
| AI apps | ChatGPT | `chatgpt` | cask `chatgpt`, `ChatGPT.app` |
| AI apps | GitHub Copilot | `copilot` | cask `github-copilot-app`, `GitHub Copilot.app` |
| AI apps | Antigravity | `antigravity` | cask `antigravity`, `Antigravity.app` |

Ids are unique across both menus, because `omamac uninstall <id>` takes either. Left out:

- Gemini CLI: Homebrew deprecated it ("unsupported", disabled 2026-12-18) and names `antigravity-cli` as its replacement. A disabled formula would fail the one `brew install` all CLI formulas share.
- The Codex app: `codex-app` is discontinued; the `chatgpt` cask is the same product now (same bundle id, same data folders). The question's help line says ChatGPT includes Codex.
- Codex CLI and Copilot CLI: their casks run the binary during `brew install` (`codex completion`, `copilot completion`). On a fresh Mac the quarantined binary waits on macOS's first-launch check, so the unattended run stops there (seen in the `cloud` and `full` runs, then reproduced in a debug VM: the process waits in `_dyld_start`). The catalog rule drops them, and they stay out until Homebrew offers them without that step (vision's Backlog): languages come from mise, everything else from Homebrew. Copilot comes as GitHub's desktop app instead.
- The Gemini app: a chat assistant; Antigravity is Google's coding app and the base of its coding tools. Its zap also removes Google's shared updater and asks for the password.
- Cursor: an editor, and no one asked for it.

The `full` run measures the steps' password count.

## Approach

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| How coding agents are installed | As cloud CLIs are: `lib/clis.sh`'s formula and cask tables gain the three ids; every place that reads `cloud_clis` reads both keys through one helper | The cloud CLIs already install, update (`--greedy` for casks), uninstall and doctor a mix of formulas and casks. Dropped: a copy of that code for agents. |
| How AI apps are installed | Four files in `apps/`, one question line `apps_ai` | Adding an app is one small file (vision). They follow every app rule: adoption, Dock order, no `--greedy`. |
| Where they are asked | AI apps after Developer; coding agents after cloud CLIs, before Docker | Most visible first: apps are visible, agents are technical. |
| Sign-in | Left to the user | Each tool asks on first use. omamac stores no keys (Secure by default). |
| Messages | "Your CLIs are installed" replaces "Cloud CLIs are installed"; the end summary lists "cloud CLIs, coding agents" | One install step covers both keys. |

## Done when

- bats passes, with tests for the new keys, ids, labels, install, update, uninstall and doctor.
- The VM runs CONTRIBUTING names for apps and CLIs pass on the head (`bare`, `languages`, `cloud`, `apps`, `adopt`, `docker-desktop`), and `full` and `colima` run side by side on it, since this lands before the release.
- `cloud` installs every coding agent and uninstalls one of each kind (formula, cask); `apps` installs every AI app; `full` installs and uninstalls all seven.
- README, vision and CONTRIBUTING name them.
