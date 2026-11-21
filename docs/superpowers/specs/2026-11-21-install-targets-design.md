# omamac install: sections and names — design

Status: draft · 2026-11-21 · Source of truth for the why: [`vision.md`](../../../vision.md) (Decisions log, 2026-11-21)

## Intent

Adding one thing after the first run meant walking every question again. Tuna asked for omawsl's way: name the part to jump to (`omamac install languages`), or name what to install (`omamac install go`).

## Forms

| Command | Asks | Notes |
| --- | --- | --- |
| `omamac install` | Every question, only its unpicked options | Unchanged. |
| `omamac install <section>…` | Only those sections' questions | Sections: `apps` (every app group and Wispr Flow), `languages`, `cloud-clis`, `coding-agents`, `docker`, `macos` (desktops, window margins, Dock cleanup, Dock auto-hide). |
| `omamac install <name>…` | Nothing but "Install?", and "Let Homebrew take over …?" for an app installed by hand | The names `omamac uninstall` takes: a value of any question (`go`, `vscode`, `colima`), or a yes/no question's key with dashes (`dock-autohide`, `wispr-flow`). |

Sections and names mix. Every form ends the same way: one summary box, Homebrew's password note, "Install?", save, apply.

- A name already picked is said ("Go is already installed.") and skipped; if nothing is left, nothing changes.
- An unknown name stops the run before anything is asked, exit 2, naming the sections and examples.
- Docker is one choice: naming colima with Docker Desktop picked stops with "uninstall it first: omamac uninstall docker-desktop", exit 2.

## Approach

| Question | Choice | Why, and what was dropped |
| --- | --- | --- |
| Names | `omamac uninstall`'s, no category word | Ids are already unique across every question (a test checks it), so `install go` needs no `language`. Dropped: omawsl's `install <category> <item>`, one more word with no meaning here. |
| "Install?" for names | Kept | One key. It shows what will happen, and Homebrew's password note, before anything changes, as every other form does. |
| Code | `add_run` gets its picks from the named sections' questions or straight from the names; the save-and-apply half is shared | One path to test and keep right. |

## Done when

- bats covers: one section, names, an already-picked name, an unknown name, Docker's one choice both ways, a macOS setting by name, a section with a name, and a hand-installed app offered to Homebrew.
- `bare` passes in the VM. (The VM's expect script answers only Remove, take-over and Also remove prompts, so "Install?" can't run there; bats covers these paths.)
- README and vision say it.
