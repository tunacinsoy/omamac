load helpers/common

bats_require_minimum_version 1.5.0

COMMENT='# Written by omamac from your answers; omamac rewrites it. Your own pins go in ~/.config/mise/config.toml.'

setup() {
  setup_sandbox
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install mise
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  DROPIN="$HOME/.config/mise/conf.d/omamac.toml"
  USER_FILE="$HOME/.config/mise/config.toml"
  # Only the mise calls the test makes.
  : > "$STUB_LOG"
}

# in_lib <languages> <code>: run bash 5 code with the languages steps loaded
# and CHOICES[languages] set to <languages>.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    for f in paths ui questions choices languages apply; do source '$REPO_ROOT/lib/'\$f.sh; done
    CHOICES[languages]='$1'
    $2"
}

# have <tool>…: mark tools as already installed by mise.
have() { local t; for t in "$@"; do mkdir -p "$OMAMAC_TEST_BREW_PREFIX/mise"; touch "$OMAMAC_TEST_BREW_PREFIX/mise/$t"; done; }

# mise_installs: the mise install lines in the log.
mise_installs() { grep '^mise install' "$STUB_LOG" || true; }

@test "the drop-in lists each chosen language's tools as latest" {
  in_lib 'ruby elixir' 'languages_write_dropin'
  [ "$status" -eq 0 ]
  [ "$(cat "$DROPIN")" = "$COMMENT
[tools]
ruby = \"latest\"
erlang = \"latest\"
elixir = \"latest\"" ]
}

@test "no language: the drop-in has an empty [tools]" {
  in_lib '' 'languages_write_dropin'
  [ "$status" -eq 0 ]
  [ "$(cat "$DROPIN")" = "$COMMENT
[tools]" ]
}

@test "a second write leaves the drop-in and its mtime alone" {
  in_lib node 'languages_write_dropin'
  [ "$status" -eq 0 ]
  before="$(shasum < "$DROPIN") $(stat -f %m "$DROPIN")"
  sleep 1.1
  in_lib node 'languages_write_dropin'
  [ "$status" -eq 0 ]
  [ "$(shasum < "$DROPIN") $(stat -f %m "$DROPIN")" = "$before" ]
  [ "$(find "$HOME/.config/mise" -type f | wc -l | tr -d ' ')" = 1 ]
}

@test "the user's mise config.toml is never written" {
  mkdir -p "$(dirname "$USER_FILE")"
  echo 'node = "20"' > "$USER_FILE"
  before="$(shasum < "$USER_FILE") $(stat -f %m "$USER_FILE")"
  sleep 1.1
  in_lib 'node ruby' 'languages_write_dropin; languages_install'
  [ "$status" -eq 0 ]
  [ "$(shasum < "$USER_FILE") $(stat -f %m "$USER_FILE")" = "$before" ]
}

@test "installs only tools mise lacks, in one call, from HOME" {
  have node
  # Started elsewhere: fake-mise fails unless omamac runs it from HOME.
  in_lib 'node python' 'cd /tmp; languages_install'
  [ "$status" -eq 0 ]
  [ "$(mise_installs)" = "mise install python" ]
  [[ "$output" == *"Installing Python"* ]]
  [[ "$output" != *"Node.js"* ]]
  [[ "$output" == *"✓ Languages are installed"* ]]
}

@test "all present: no mise install" {
  have node erlang elixir
  in_lib 'node elixir' 'languages_install'
  [ "$status" -eq 0 ]
  [ -z "$(mise_installs)" ]
  [[ "$output" == *"✓ Languages are installed"* ]]
}

@test "named languages are installed instead of the chosen ones" {
  in_lib node 'languages_install go'
  [ "$status" -eq 0 ]
  [ "$(mise_installs)" = "mise install go" ]
}

@test "no language: no mise call and nothing said" {
  in_lib '' 'languages_install'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run ! grep -q '^mise' "$STUB_LOG"
}

@test "ruby: rails installed once" {
  in_lib ruby 'languages_install'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing Rails"* ]]
  [ "$(grep -c 'gem install rails' "$STUB_LOG")" = 1 ]
  grep -qx 'mise exec ruby -- gem install rails --no-document' "$STUB_LOG"
  in_lib ruby 'languages_install'
  [ "$status" -eq 0 ]
  [ "$(grep -c 'gem install rails' "$STUB_LOG")" = 1 ]
  [ "$(mise_installs)" = "mise install ruby" ]
}

@test "a mise failure returns non-zero and shows the log" {
  T_MISE_FAIL=1 in_lib node 'languages_install'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Log:"* ]]
  [[ "$output" != *"Languages are installed"* ]]
}

@test "mise can't list: fails, installs nothing" {
  printf '#!/bin/bash\necho "mise $*" >> "$STUB_LOG"\nexit 1\n' > "$OMAMAC_TEST_BREW_PREFIX/bin/mise.broken"
  chmod +x "$OMAMAC_TEST_BREW_PREFIX/bin/mise.broken"
  mv -f "$OMAMAC_TEST_BREW_PREFIX/bin/mise.broken" "$OMAMAC_TEST_BREW_PREFIX/bin/mise"
  in_lib node 'languages_install'
  [ "$status" -ne 0 ]
  [ -z "$(mise_installs)" ]
  [[ "$output" != *"Languages are installed"* ]]
}
