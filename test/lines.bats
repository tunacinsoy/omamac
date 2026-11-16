load helpers/common

setup() { setup_sandbox; }

# Run the lib under bash 5, the same as real use.
b5() { "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/lines.sh"; "$@"' _ "$@"; }

@test "creates a missing file holding only the line" {
  b5 lines_add "$HOME/.zshrc" "L"
  [ "$(cat "$HOME/.zshrc")" = "L" ]
  b5 lines_add "$HOME/.config/x/y" "L"
  [ "$(cat "$HOME/.config/x/y")" = "L" ]
}

@test "appends to an existing file and changes nothing else" {
  printf 'a\nb\n' > "$HOME/f"
  b5 lines_add "$HOME/f" "L"
  [ "$(cat "$HOME/f")" = "$(printf 'a\nb\nL')" ]
}

@test "adds a newline first when the file lacks one" {
  printf 'a' > "$HOME/f"
  b5 lines_add "$HOME/f" "L"
  [ "$(cat "$HOME/f")" = "$(printf 'a\nL')" ]
}

@test "second call changes nothing" {
  b5 lines_add "$HOME/f" "L"
  before=$(shasum "$HOME/f")
  b5 lines_add "$HOME/f" "L"
  [ "$(shasum "$HOME/f")" = "$before" ]
  [ "$(wc -l < "$HOME/f" | tr -d ' ')" = 1 ]
}

@test "a present pattern skips the add" {
  # shellcheck disable=SC2016
  printf 'eval "$(brew shellenv)"\n' > "$HOME/f"
  before=$(shasum "$HOME/f")
  "$BASH5" -c 'source "$REPO_ROOT/lib/paths.sh"; source "$REPO_ROOT/lib/lines.sh"; lines_add "$1" "$OMAMAC_ZPROFILE_LINE" "brew shellenv"' _ "$HOME/f"
  [ "$(shasum "$HOME/f")" = "$before" ]
}

@test "follows a symlinked file" {
  mkdir "$HOME/dotfiles"
  printf 'a\n' > "$HOME/dotfiles/zshrc"
  ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
  b5 lines_add "$HOME/.zshrc" "L"
  [ -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/dotfiles/zshrc")" = "$(printf 'a\nL')" ]
}

@test "unwritable file stops with its name" {
  [ "$(id -u)" -ne 0 ]
  printf 'a\n' > "$HOME/.zshrc"
  chmod 444 "$HOME/.zshrc"
  run b5 lines_add "$HOME/.zshrc" "L"
  [ "$status" -ne 0 ]
  [[ "$output" == *".zshrc"* ]]
  [[ "$output" == *"Fix:"* ]]
  [ "$(cat "$HOME/.zshrc")" = "a" ]
}

@test "unwritable symlinked file: names the target, no chown" {
  [ "$(id -u)" -ne 0 ]
  mkdir "$HOME/store"
  printf 'a\n' > "$HOME/store/zshrc"
  chmod 444 "$HOME/store/zshrc"
  ln -s "$HOME/store/zshrc" "$HOME/.zshrc"
  run b5 lines_add "$HOME/.zshrc" "the line"
  [ "$status" -ne 0 ]
  [[ "$output" == *"store/zshrc"* ]]
  [[ "$output" == *"the line"* ]]
  [[ "$output" != *"chown"* ]]
  [ "$(cat "$HOME/store/zshrc")" = "a" ]
}

@test "lines_has finds and misses" {
  printf 'hello world\n' > "$HOME/f"
  b5 lines_has "$HOME/f" "lo wor"
  run b5 lines_has "$HOME/f" "nope"
  [ "$status" -eq 1 ]
  run b5 lines_has "$HOME/missing" "x"
  [ "$status" -eq 1 ]
}
