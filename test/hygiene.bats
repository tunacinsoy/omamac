load helpers/common

setup() { setup_sandbox; }

@test "users never see apt, Windows or WSL" {
  # grep exits 2 on missing paths, so only search paths that exist.
  local files=() p
  for p in README.md CONTRIBUTING.md boot.sh install.sh bin lib; do
    [ ! -e "$REPO_ROOT/$p" ] || files+=("$REPO_ROOT/$p")
  done
  [ "${#files[@]}" -eq 0 ] && return 0
  run grep -rniwE 'apt|windows|wsl' "${files[@]}"
  [ "$status" -eq 1 ]   # grep found nothing
}

@test "boot.sh parses under macOS's bash 3.2" {
  [ ! -e "$REPO_ROOT/boot.sh" ] || /bin/bash -n "$REPO_ROOT/boot.sh"
}

@test "every bash 5 script parses" {
  for f in "$REPO_ROOT"/install.sh "$REPO_ROOT"/bin/omamac "$REPO_ROOT"/lib/*.sh; do
    [ ! -e "$f" ] || "$BASH5" -n "$f"
  done
}

@test "stub records its calls" {
  stub hello 'echo hi'
  run hello there
  [ "$output" = "hi" ]
  grep -qx 'hello there' "$STUB_LOG"
}
