load helpers/common

setup() { setup_sandbox; }

@test "users never see apt, Windows or WSL" {
  # grep exits 2 on missing paths, so only search paths that exist.
  local files=() p
  for p in README.md CONTRIBUTING.md boot.sh install.sh update.sh bin lib config; do
    [ ! -e "$REPO_ROOT/$p" ] || files+=("$REPO_ROOT/$p")
  done
  [ "${#files[@]}" -eq 0 ] && return 0
  # Case-insensitive for apt and WSL; case-sensitive for Windows, the OS's
  # name, since omamac's own text speaks of macOS windows.
  run grep -rniwE 'apt|wsl' "${files[@]}"
  [ "$status" -eq 1 ]   # grep found nothing
  run grep -rnw 'Windows' "${files[@]}"
  [ "$status" -eq 1 ]
}

@test "boot.sh parses under macOS's bash 3.2" {
  [ ! -e "$REPO_ROOT/boot.sh" ] || /bin/bash -n "$REPO_ROOT/boot.sh"
}

@test "every bash 5 script parses" {
  for f in "$REPO_ROOT"/install.sh "$REPO_ROOT"/update.sh "$REPO_ROOT"/bin/omamac "$REPO_ROOT"/bin/omamac-herdr-mode "$REPO_ROOT"/lib/*.sh; do
    [ ! -e "$f" ] || "$BASH5" -n "$f"
  done
}

@test "the launcher parses under zsh" {
  # shellcheck can't read zsh, so CI doesn't list the launcher.
  /bin/zsh -n "$REPO_ROOT/bin/omamac-terminal"
}

@test "the helper passes shellcheck" {
  # CI's shellcheck line doesn't list the helper, so it's checked here.
  command -v shellcheck >/dev/null || skip "shellcheck is not installed"
  shellcheck "$REPO_ROOT/bin/omamac-herdr-mode"
}

@test "stub records its calls" {
  stub hello 'echo hi'
  run hello there
  [ "$output" = "hi" ]
  grep -qx 'hello there' "$STUB_LOG"
}
