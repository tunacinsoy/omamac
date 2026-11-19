load helpers/common

setup() { setup_sandbox; }

@test "users never see apt, Windows or WSL" {
  # grep exits 2 on missing paths, so only search paths that exist.
  local files=() p
  for p in README.md CONTRIBUTING.md boot.sh install.sh update.sh bin lib config themes; do
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

@test "omamac never runs Ghostty's binary" {
  # On a fresh Mac it waits on macOS's "Open?" dialog. Only VM steps may run it.
  cd "$REPO_ROOT"
  run grep -rn 'MacOS/ghostty' bin lib install.sh update.sh
  [ "$status" -eq 1 ]
}

@test "omamac never deletes colima's VM" {
  # colima delete removes the user's images, containers and volumes.
  cd "$REPO_ROOT"
  run grep -rn 'colima delete' bin lib install.sh update.sh
  [ "$status" -eq 1 ]
}

@test "omamac never runs xattr" {
  # It would clear macOS's first-open check. Only VM steps may run it.
  cd "$REPO_ROOT"
  run grep -rn 'xattr' bin lib install.sh update.sh
  [ "$status" -eq 1 ]
}

@test "--zap only in the uninstall path" {
  # --zap deletes the user's data, so only uninstall passes it, after a yes;
  # lib/docker.sh passes on what lib/remove.sh gives it.
  cd "$REPO_ROOT"
  run grep -rn -e '--zap' bin lib install.sh update.sh
  [ "$status" -eq 0 ]
  [ -z "$(grep -vE '^lib/(remove|docker)\.sh:' <<< "$output")" ]
}

@test "omamac never answers Homebrew's password prompt itself" {
  # Homebrew asks for the password itself; skipping or feeding that prompt
  # would hide from the user what runs as root.
  cd "$REPO_ROOT"
  run grep -rnE 'HOMEBREW_SUDO_CHECKED|SUDO_ASKPASS' bin lib install.sh update.sh
  [ "$status" -eq 1 ]
}

@test "no cask command passes --force" {
  # --force would overwrite an app the user installed by hand.
  cd "$REPO_ROOT"
  run grep -rnE -e '--cask.*(--force|[[:space:]]-f([[:space:]]|$))' bin lib install.sh update.sh
  [ "$status" -eq 1 ]
}

@test "--greedy only in update_upgrade_casks" {
  # Apps update themselves; --greedy would call them outdated forever. Only
  # the cloud CLI casks need it. Comments may name it (no # before it).
  cd "$REPO_ROOT"
  local all inside
  all=$(grep -rhE -e '^[^#]*--greedy' bin lib install.sh update.sh | wc -l)
  inside=$(sed -n '/^update_upgrade_casks()/,/^}/p' update.sh | grep -cE -e '^[^#]*--greedy')
  [ "$all" -ge 1 ]
  [ "$all" -eq "$inside" ]
}

@test "the README holds every allow line from apps/" {
  local line
  while IFS= read -r line; do
    grep -qF -- "${line#allow=}" "$REPO_ROOT/README.md" || {
      echo "README lacks: ${line#allow=}"
      return 1
    }
  done < <(grep -h '^allow=' "$REPO_ROOT"/apps/*)
}
