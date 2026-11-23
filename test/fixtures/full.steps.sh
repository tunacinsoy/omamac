# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM after the two runs (test/vm.sh, step 9), in zsh with -eux.
# Every option at once: everything chosen is there, then every pick is
# uninstalled and the Mac's Dock and settings are back to how they were.
fp() { curl -fsSL "https://raw.githubusercontent.com/tunacinsoy/omamac/$(git -C ~/.local/share/omamac rev-parse HEAD)/test/fingerprint.sh" | /bin/bash; }
dock_urls() {
  { defaults read com.apple.dock "$1" 2>/dev/null || true; } |
    sed -n 's/^ *"_CFURLString" = "\{0,1\}\([^"]*\)"\{0,1\};$/\1/p'
}
settings_now() {
  while read -r domain key _; do
    now=$(defaults read "$domain" "$key" 2>/dev/null) || now=absent
    print -r -- "$domain $key $now"
  done < ~/settings-before
}
hotkeys_now() {
  defaults export com.apple.symbolichotkeys - > ~/hotkeys.plist
  for id in 118 119 120 121 122 123; do
    plutil -extract "AppleSymbolicHotKeys.$id" xml1 -o - ~/hotkeys.plist 2>/dev/null || print absent
  done
}
checkout=~/.local/share/omamac
mise=/opt/homebrew/bin/mise
# The catalog in catalog order (lib/questions.sh), then Wispr Flow.
ids=(brave chrome firefox whatsapp telegram signal discord slack zoom spotify vlc cap dropbox google-drive vscode
  claude chatgpt copilot antigravity raycast obsidian wispr-flow)
# Each coding agent as <id>:<its command>.
agents=(claude-code:claude antigravity-cli:agy opencode:opencode)

# 1. Every app is in Applications and Homebrew lists its cask. No app's
# binary runs: it would wait on macOS's first-open check.
casks=$(brew list --cask -1)
dock_want=file:///Applications/Ghostty.app/
for id in "${ids[@]}"; do
  cask=$(sed -n 's/^cask=//p' "$checkout/apps/$id")
  app=$(sed -n 's/^app=//p' "$checkout/apps/$id")
  [[ -d /Applications/$app ]]
  [[ $'\n'$casks$'\n' == *$'\n'$cask$'\n'* ]]
  dock_want+=$'\n'"file:///Applications/${app// /%20}/"
done
dock_want+=$'\n'file:///Applications/Docker.app/
# Docker Desktop: its docker link points into the app; never run (first-open check).
[[ -d /Applications/Docker.app ]]
[[ $(readlink /usr/local/bin/docker) == /Applications/Docker.app/* ]]
lazydocker --version
# Every language is installed by mise.
for tool in ruby node go python erlang elixir rust java; do
  [[ -n $(cd ~ && $mise ls --installed --no-header "$tool") ]]
done
# Every cloud CLI. Not az version: its first run waits on macOS's first-open check.
[[ -x /opt/homebrew/bin/az ]]
aws --version
gcloud version
gh --version
terraform version
# Every coding agent's command is Homebrew's. None runs: a cask's binary may
# wait on macOS's first-open check, and each wants a sign-in.
for a in "${agents[@]}"; do [[ -x /opt/homebrew/bin/${a#*:} ]]; done

# 2. The Dock: no Apple app, no Downloads, omamac's apps in order.
[[ $(dock_urls persistent-apps) == "$dock_want" ]]
[[ -z $(dock_urls persistent-others) ]]
[[ $(defaults read com.apple.dock autohide) == 1 ]]
[[ $(defaults read com.apple.dock mru-spaces) == 0 ]]
[[ $(defaults read com.apple.WindowManager EnableTiledWindowMargins) == 1 ]]
[[ $(defaults read com.apple.WindowManager StandardHideWidgets) == 1 ]]

# 3. The theme: catppuccin from the first run, then dracula everywhere.
cmp ~/.config/omamac/starship.toml $checkout/themes/catppuccin/starship.toml
omamac theme dracula
cmp ~/.config/omamac/starship.toml $checkout/themes/dracula/starship.toml
cmp ~/.config/omamac/btop.conf <(print -r -- 'color_theme = "dracula"')
[[ $(< ~/.config/omamac/ghostty.conf) == *"background = #282A36"* ]]
cmp ~/.config/omamac/neovim.lua $checkout/themes/dracula/neovim.lua

# 4. Updating again changes nothing.
omamac update
before=$(fp)
omamac update
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi

# 5. Uninstall every pick. vm.exp says yes to each data question.
for id in "${ids[@]}"; do
  cask=$(sed -n 's/^cask=//p' "$checkout/apps/$id")
  app=$(sed -n 's/^app=//p' "$checkout/apps/$id")
  omamac uninstall "$id"
  [[ ! -e /Applications/$app ]]
  if brew list --cask "$cask" >/dev/null 2>&1; then exit 1; fi
done
# VS Code's data went with it, omamac's theme extension too.
[[ ! -e ~/.vscode ]]
omamac uninstall docker-desktop
[[ ! -e /Applications/Docker.app ]]
if brew list --cask docker-desktop >/dev/null 2>&1; then exit 1; fi
for id in ruby node go python elixir rust java; do omamac uninstall "$id"; done
for tool in ruby node go python elixir rust java; do
  [[ -z $(cd ~ && $mise ls --installed --no-header "$tool") ]]
done
for id in azure aws gcloud gh terraform; do omamac uninstall "$id"; done
for cmd in az aws gcloud gh terraform; do [[ ! -e /opt/homebrew/bin/$cmd ]]; done
for a in "${agents[@]}"; do
  omamac uninstall "${a%%:*}"
  [[ ! -e /opt/homebrew/bin/${a#*:} ]]
done
omamac uninstall dock
omamac uninstall dock-autohide
omamac uninstall desktops
omamac uninstall window-margins
omamac uninstall desktop-widgets
choices=$(< ~/.local/state/omamac/choices.env)
for line in apps_browsers= apps_communication= apps_media= apps_screen_recording= apps_storage= \
  apps_developer= apps_ai= apps_productivity= wispr_flow=no desktops=no window_margins=no \
  desktop_widgets=no dock=no dock_autohide=no languages= cloud_clis= coding_agents= docker=none; do
  [[ $'\n'$choices$'\n' == *$'\n'$line$'\n'* ]]
done

# 6. The Dock and the macOS settings are as before the first run.
[[ $(dock_urls persistent-apps) == "$(< ~/dock-before-apps)" ]]
[[ $(dock_urls persistent-others) == "$(< ~/dock-before-others)" ]]
diff ~/settings-before <(settings_now)
diff ~/hotkeys-before <(hotkeys_now)

# 7. Uninstalling again changes nothing and asks nothing.
before=$(fp)
omamac uninstall vlc
after=$(fp)
if [[ $before != "$after" ]]; then
  diff <(print -r -- "$before") <(print -r -- "$after")
  exit 1
fi
omamac doctor
