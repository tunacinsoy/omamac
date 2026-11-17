load helpers/common

setup() { setup_sandbox; }

# Run a check in an interactive zsh that reads only config/zshrc, with the
# stub dir (and so any stubs made) on the PATH.
zrc() { run zsh -f -i -c "source $REPO_ROOT/config/zshrc; $1" < /dev/null; }

@test "zsh parses it" {
  zsh -n "$REPO_ROOT/config/zshrc"
}

@test "with no tools it prints nothing" {
  PATH=/usr/bin:/bin run zsh -f -i -c "source $REPO_ROOT/config/zshrc" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "PATH gets omamac's bin once" {
  run zsh -f -i -c "source $REPO_ROOT/config/zshrc; source $REPO_ROOT/config/zshrc; echo \$PATH" < /dev/null
  [ "$status" -eq 0 ]
  [ "$(grep -o '\.local/share/omamac/bin' <<< "$output" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "EDITOR is nvim when nvim exists" {
  PATH=/usr/bin:/bin run zsh -f -i -c "source $REPO_ROOT/config/zshrc; echo \"[\${EDITOR-unset}]\"" < /dev/null
  [[ "$output" == *"[unset]"* ]]
  stub nvim
  zrc 'echo "$EDITOR $VISUAL"'
  [[ "$output" == *"nvim nvim"* ]]
}

@test "aliases appear with their tools" {
  stub eza; stub bat; stub lazygit
  stub zoxide 'echo "z() { :; }"'
  zrc 'echo "$aliases[ls]|$aliases[cat]|$aliases[lzg]|$aliases[cd]"'
  [[ "$output" == *"eza -lh --group-directories-first --icons=auto|bat --paging=never|lazygit|z"* ]]
}

@test "history settings" {
  zrc '[[ -o hist_ignore_space ]] && echo "$HISTSIZE $SAVEHIST"'
  [[ "$output" == *"10000 20000"* ]]
}

@test "history sizes are only raised, never lowered" {
  run zsh -f -i -c "HISTSIZE=50000 SAVEHIST=100000; source $REPO_ROOT/config/zshrc; echo \"\$HISTSIZE \$SAVEHIST\"" < /dev/null
  [[ "$output" == *"50000 100000"* ]]
  run zsh -f -i -c "HISTSIZE=100 SAVEHIST=200; source $REPO_ROOT/config/zshrc; echo \"\$HISTSIZE \$SAVEHIST\"" < /dev/null
  [[ "$output" == *"10000 20000"* ]]
}

@test "starship and mise init only when present" {
  zrc 'true'
  [ ! -s "$STUB_LOG" ]
  stub starship; stub mise
  zrc 'true'
  [ "$(grep -n -E 'init zsh|activate zsh' "$STUB_LOG" | tail -1 | cut -d: -f2-)" = "starship init zsh" ]
  grep -qx 'mise activate zsh' "$STUB_LOG"
}

@test "no zellij, apt names or multiplexer start" {
  # Comments are skipped, so one may name herdr; a command or its start may not.
  run bash -c "grep -v '^[[:space:]]*#' '$REPO_ROOT/config/zshrc' | grep -E 'zellij|batcat|fdfind|herdr( |\$)'"
  [ "$status" -eq 1 ]
}

@test "HERDR_CONFIG_PATH points at omamac's file" {
  zrc 'print -r -- $HERDR_CONFIG_PATH'
  [ "$output" = "$HOME/.config/omamac/herdr.toml" ]
}

@test "the user's own herdr config wins" {
  mkdir -p "$HOME/.config/herdr"
  touch "$HOME/.config/herdr/config.toml"
  zrc 'print -r -- $HERDR_CONFIG_PATH'
  [ -z "$output" ]
}

@test "a HERDR_CONFIG_PATH the user set is kept" {
  HERDR_CONFIG_PATH=/x zrc 'print -r -- $HERDR_CONFIG_PATH'
  [ "$output" = "/x" ]
}

@test "a user alias n does not break the file" {
  stub nvim
  run zsh -f -i -c "alias n='echo hi'; source $REPO_ROOT/config/zshrc; whence -w n" < /dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "n: function" ]
}

@test "Homebrew's completions are on fpath once" {
  zrc "source $REPO_ROOT/config/zshrc; print -l \$fpath | grep -cx /opt/homebrew/share/zsh/site-functions"
  [ "$output" = "1" ]
}

@test "it is quiet when ~/.zshrc already ran compinit" {
  run zsh -f -i -c "autoload -Uz compinit && compinit; source $REPO_ROOT/config/zshrc" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
