# After install

A few clicks are left that macOS doesn't let a script make.

[← Back to the README](../README.md)

Do each once, top to bottom; skip a line that names something you didn't choose.

- [ ] Open Ghostty. It starts herdr. The first time, macOS asks you to confirm; click Open.
- [ ] Open each app once. macOS asks you to confirm; click Open.
- [ ] Some apps need a permission, in System Settings → Privacy & Security:
  - [ ] Cap: allow Screen Recording, and Camera and Microphone if you use them.
  - [ ] Wispr Flow: allow Microphone and Accessibility.
  - [ ] Zoom: allow Camera and Microphone, and Screen Recording to share.
- [ ] Allow App Management for Ghostty (System Settings → Privacy & Security → App Management), so `omamac update` can upgrade Ghostty, Docker Desktop and your apps, and `omamac uninstall` can remove them. Zoom and Google Drive don't need it: Homebrew changes them with your password.
- [ ] Docker Desktop: open it once to finish its setup.
- [ ] Sign in to each coding agent and AI app the first time you use it: run `claude`, `codex`, `copilot`, `agy` or `opencode` in Ghostty, or open the app. ChatGPT's app includes Codex; Antigravity CLI is Google's successor to Gemini CLI. omamac stores no keys or logins.
- [ ] Desktops as workspaces: make six desktops. Open Mission Control (Ctrl ↑) and click + at the top right until there are six. Ctrl 1 to Ctrl 6 then jump straight to each.
- [ ] Give each desktop one purpose, and each app its desktop: right-click the app's Dock icon, then Options, then Assign To. A layout to start from: 1 browser and chat, 2 code and terminal, 3 documents and PDFs, 4 notes, 5 music, 6 monitoring (btop, Activity Monitor). This is an opinion, the one omakub and Omarchy share: a desktop per purpose, always in the same place.
- [ ] Reduce motion: if omamac said macOS refused it, search for Reduce motion in System Settings and turn it on.
- [ ] Open `nvim` once; it downloads its plugins.
- [ ] Set up git, SSH and GitHub sign-in; omamac doesn't touch them:

  ```
  git config --global user.name "Your Name"
  git config --global user.email you@example.com
  ssh-keygen -t ed25519
  gh auth login   # if you chose the GitHub CLI
  ```
