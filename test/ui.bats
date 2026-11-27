load helpers/common

bats_require_minimum_version 1.5.0

# The output kit (lib/ui.sh): its plain text, and each block of the terminal
# look (#46) with the real gum drawing it.

setup() {
  setup_sandbox
  install_fake_brew
  "$OMAMAC_TEST_BREW_PREFIX/bin/brew" install gum
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/run.log"
  : > "$OMAMAC_LOG"
}

# kit <code>: run code with lib/ui.sh loaded.
kit() {
  "$BASH5" -c "set -Eeuo pipefail
    source '$REPO_ROOT/lib/paths.sh'
    source '$REPO_ROOT/lib/ui.sh'
    $1"
}

# shown: $output without its colour codes.
shown() { printf '%s\n' "$output" | uncoloured; }

@test "plain text: the helpers print what they always have" {
  run kit 'ui_step Theme files; ui_ok done; ui_info note; ui_fail bad; ui_box a b'
  [ "$status" -eq 0 ]
  [ "$output" = "Theme files
✓ done
ℹ note
✗ bad
a
b" ]
}

@test "plain text: stages and the terminal blocks' callers stay silent" {
  run kit 'ui_stages 3; ui_stage Apps; ui_ok inside; ui_stage_done VLC'
  [ "$status" -eq 0 ]
  [ "$output" = "✓ inside" ]
}

@test "the look is plain when stdout isn't a terminal, and forced for tests" {
  run kit 'echo "$UI_TERM"'
  [ "$output" = 0 ]
  OMAMAC_TEST_UI_TERMINAL=1 run kit 'echo "$UI_TERM"'
  [ "$output" = 1 ]
}

@test "without gum the terminal look falls back to plain text" {
  rm "$OMAMAC_TEST_BREW_PREFIX/bin/gum"
  OMAMAC_TEST_UI_TERMINAL=1 run kit 'ui_ok done; ui_fail bad'
  [ "$output" = "✓ done
✗ bad" ]
}

@test "row: mark, name and a dim detail in a column; a ✗'s detail is red" {
  terminal_look
  run kit 'ui_row ok "Core tools" "15 installed"; ui_row fail Rust "mise no longer has it"'
  [ "$status" -eq 0 ]
  [ "$(shown)" = "  ✓ Core tools      15 installed
  ✗ Rust            mise no longer has it" ]
  [[ "$output" == *$'\e[32m✓\e[0m Core tools      \e[2m15 installed\e[0m'* ]]
  [[ "$output" == *$'\e[31m✗\e[0m Rust            \e[31mmise no longer has it\e[0m'* ]]
}

@test "row: the helpers are rows: blue ℹ, green ✓, a ✗ in red on stderr" {
  terminal_look
  run --separate-stderr kit 'ui_info "a note"; ui_ok done; ui_fail "it broke"'
  [ "$(shown)" = "  ℹ a note
  ✓ done" ]
  [[ "$output" == *$'\e[34mℹ\e[0m a note'* ]]
  # bats trims the stderr it keeps, so only the row's end is compared.
  [[ "$(printf '%s\n' "$stderr" | uncoloured)" == *"✗ it broke" ]]
  [[ "$stderr" == *$'\e[31mit broke\e[0m'* ]]
}

@test "row: a long sentence wraps under itself, inside 80 columns" {
  terminal_look
  local long
  long=$(printf 'word%.0s ' {1..40})
  run kit "ui_info '$long'; ui_row fail Rust '$long'"
  [ "$(shown | widest)" -le 80 ]
  [ "$(shown | sed -n 2p | cut -c1-4)" = "    " ]
  [ "$(shown | grep -c word)" -ge 4 ]
}

@test "heading: bold, and its more dim" {
  terminal_look
  run kit 'ui_heading "What you have"; ui_heading Theme "Tokyo Night"'
  [ "$output" = $'\e[1mWhat you have\e[0m\n\e[1mTheme\e[0m \e[2m· Tokyo Night\e[0m' ]
}

@test "sheet of labels: rounded, no header, labels dim, a dash for none" {
  terminal_look
  run kit 'ui_sheet_labels "Languages"$'"'"'\t'"'"'"Go, Rust" "Browsers"$'"'"'\t'"'"'""'
  [ "$status" -eq 0 ]
  [ "$(shown)" = "╭───────────┬──────────╮
│ Languages │ Go, Rust │
│ Browsers  │ —        │
╰───────────┴──────────╯" ]
  [[ "$output" == *$'\e[2mLanguages\e[0m'* ]]
}

@test "sheet with a header: the header bold, the first row not" {
  terminal_look
  run kit 'ui_sheet "App"$'"'"'\t'"'"'"Allow, the first time it asks" "Zoom"$'"'"'\t'"'"'"Camera" "Cap"$'"'"'\t'"'"'"Screen Recording"'
  [ "$(shown)" = "╭──────┬───────────────────────────────╮
│ App  │ Allow, the first time it asks │
├──────┼───────────────────────────────┤
│ Zoom │ Camera                        │
│ Cap  │ Screen Recording              │
╰──────┴───────────────────────────────╯" ]
  [[ "$output" == *$'\e[1mApp\e[0m'* ]]
  [[ "$output" != *$'\e[1mZoom'* ]]
}

@test "sheet: a long last cell wraps, so the sheet fits 80 columns" {
  terminal_look
  local long
  long=$(printf 'detail%.0s ' {1..30})
  run kit "ui_sheet '' '{ok}✓'$'\t''Homebrew'$'\t''{dim}$long'"
  [ "$status" -eq 0 ]
  [ "$(shown | widest)" -le 80 ]
  [ "$(shown | grep -c detail)" -ge 3 ]
  [ "$(shown | sed -n 3p)" = "│   │          │ detail detail detail detail detail detail detail detail │" ]
}

@test "titled box: the title in the top border, in its colour; labels lined up" {
  terminal_look
  run kit 'ui_titled ok Done "Installed"$'"'"'\t'"'"'"Go, Rust" "Log"$'"'"'\t'"'"'"~/x.log"'
  [ "$(shown)" = "╭ Done ───────────────╮
│ Installed  Go, Rust │
│ Log        ~/x.log  │
╰─────────────────────╯" ]
  [[ "$output" == *$'╭ \e[32mDone\e[0m ─'* ]]
  run kit 'ui_titled warn Removes "App"$'"'"'\t'"'"'"VLC.app"'
  [[ "$output" == *$'╭ \e[33mRemoves\e[0m ─'* ]]
}

@test "titled box: a long value wraps under its column, inside 80 columns" {
  terminal_look
  local long
  long=$(printf 'value%.0s ' {1..40})
  run kit "ui_titled ok Done 'Installed'$'\t''$long'"
  [ "$(shown | widest)" -le 80 ]
  [ "$(shown | sed -n 3p | cut -c1-13)" = "│            " ]
}

@test "titled box with commands: each once, what it fixes dim under it" {
  terminal_look
  run kit 'ui_titled -c warn "To fix" "omamac update"$'"'"'\t'"'"'"puts back Rust" "omamac uninstall rust"$'"'"'\t'"'"'"drops Rust"'
  [ "$(shown)" = "╭ To fix ───────────────╮
│ omamac update         │
│   puts back Rust      │
│                       │
│ omamac uninstall rust │
│   drops Rust          │
╰───────────────────────╯" ]
}

@test "count line: problems red, notes blue, fine green; none of a kind is left out" {
  terminal_look
  run kit 'ui_count 1 1 14; ui_count 2 0 3; ui_count 0 0 21'
  [ "$(shown)" = "1 problem · 1 note · 14 fine
2 problems · 3 fine
21 fine" ]
  [[ "$output" == *$'\e[31m1 problem\e[0m · \e[34m1 note\e[0m · \e[32m14 fine\e[0m'* ]]
}

@test "count line: updates waiting end it, yellow" {
  terminal_look
  run kit 'ui_count 0 0 21 2; ui_count 1 0 3 1; ui_count 0 0 4 0'
  [ "$(shown)" = "21 fine · 2 updates waiting: omamac update
1 problem · 3 fine · 1 update waiting: omamac update
4 fine" ]
  [[ "$output" == *$'\e[32m21 fine\e[0m · \e[33m2 updates waiting: omamac update\e[0m'* ]]
}

@test "sheet: a {yellow} cell is yellow" {
  terminal_look
  run kit 'ui_sheet "" "Python"$'"'"'\t'"'"'"{yellow}3.14.2 is out"'
  [ "$(shown)" = "╭────────┬───────────────╮
│ Python │ 3.14.2 is out │
╰────────┴───────────────╯" ]
  [[ "$output" == *$'\e[33m3.14.2 is out\e[0m'* ]]
}

@test "stages: each row has its count; inside, ✓ and step lines wait for the row" {
  terminal_look
  run kit 'ui_stages 2
    ui_stage "Core tools"; ui_step Installing; ui_ok "Core tools are installed"; ui_info "Ghostty is yours"; ui_stage_done "15 installed"
    ui_stage Apps; ui_stage_done VLC'
  [ "$(shown)" = "    ℹ Ghostty is yours
1/2 ✓ Core tools      15 installed
2/2 ✓ Apps            VLC" ]
  [[ "$output" == *$'\e[2m1/2 \e[0m'* ]]
}

@test "stages: from ten on, the counts line up" {
  terminal_look
  run kit 'ui_stages 10; for i in 1 2 3 4 5 6 7 8 9 10; do ui_stage "S$i"; ui_stage_done; done'
  [ "$(shown | sed -n 1p)" = " 1/10 ✓ S1" ]
  [ "$(shown | sed -n 10p)" = "10/10 ✓ S10" ]
}

@test "a spinner in the terminal look is blue and sits in the mark column" {
  terminal_look
  run kit 'ui_stages 3; ui_stage Apps; ui_run "Installing VLC" true; ui_stage_done VLC'
  [ "$status" -eq 0 ]
  grep -q '^gum spin --spinner.foreground=4 --padding=0 0 0 4 --title Apps             Installing VLC -- ' "$STUB_LOG"
}

@test "stopped: the stage turns into a red ✗ with the reason, then the Stopped box with the log's last lines" {
  terminal_look
  export OMAMAC_LOG="$HOME/run.log"
  printf '==> Downloading vlc\n  9%%\r 50%%\r\e[31mcurl: (6) Could not resolve host\e[0m\r\n' > "$OMAMAC_LOG"
  run --separate-stderr kit 'ui_stages 2; ui_stage Apps; OMAMAC_STEP="installing VLC"; ui_run "Installing VLC" false || ui_stopped "run the one-liner again"'
  [ -z "$output" ]
  [[ "$stderr" == *$'✗\e[0m Apps            \e[31mInstalling VLC didn\'t finish'* ]]
  [[ "$stderr" == *$'╭ \e[31mStopped\e[0m'* ]]
  [ "$(printf '%s\n' "$stderr" | uncoloured | sed 1d)" = "╭ Stopped ─────────────────────────╮
│ While  installing VLC            │
│ Fix    run the one-liner again   │
│ Log    ~/run.log                 │
├──────────────────────────────────┤
│ ==> Downloading vlc              │
│ curl: (6) Could not resolve host │
╰──────────────────────────────────╯" ]
}

@test "stopped with no log: no Log row and no lines" {
  terminal_look
  run --separate-stderr kit 'OMAMAC_LOG=/dev/null OMAMAC_STEP=starting ui_stopped "run it again"'
  [ "$(printf '%s\n' "$stderr" | uncoloured)" = "╭ Stopped ────────────╮
│ While  starting     │
│ Fix    run it again │
╰─────────────────────╯" ]
}

@test "NO_COLOR keeps the layout and drops the colour" {
  terminal_look
  NO_COLOR=1 run kit 'ui_row ok Apps VLC; ui_sheet_labels "Languages"$'"'"'\t'"'"'"Go"; ui_titled ok Done "Log"$'"'"'\t'"'"'"x"; ui_count 1 0 2'
  [[ "$output" != *$'\e'* ]]
  [[ "$output" == *"✓ Apps"*"│ Languages │ Go │"*"╭ Done"*"1 problem · 2 fine"* ]]
}

# --- ui_run_download: a Homebrew command's download progress on its row.

# fake_download <MiB> [<MiB>…]: as Homebrew does, a growing .incomplete file in
# the download cache, one chunk every 0.6 s, then the finished file. For bash -c.
FAKE_DOWNLOAD='d="$HOME/Library/Caches/Homebrew/downloads"; mkdir -p "$d"
  f="$d/abc--vlc.dmg.incomplete"
  for mib in "$@"; do head -c $((mib * 1048576)) /dev/zero >> "$f"; sleep 0.6; done
  mv "$f" "${f%.incomplete}"'

@test "download progress, plain text: closed runs as ui_run, open as ui_run_open" {
  run kit 'ui_run_download closed "Upgrading the CLIs" true; ui_run_download open "Upgrading VLC" true'
  [ "$status" -eq 0 ]
  grep -q '^gum spin .*--title Upgrading the CLIs -- ' "$STUB_LOG"
  [ "$output" = "Upgrading VLC" ]
}

@test "download progress: the spinner row says how much has come and how fast" {
  export OMAMAC_TEST_UI_TERMINAL=1
  run kit "ui_stages 2; ui_stage 'App upgrades'; ui_run_download closed 'Upgrading VLC' bash -c '$FAKE_DOWNLOAD' _ 2 2 2"
  [ "$status" -eq 0 ]
  [[ "$(drawn)" == *"App upgrades     Upgrading VLC · 6.0 MB · "*" MB/s"* ]]
  [[ "$(drawn)" == *"App upgrades     Upgrading VLC"* ]]
  # The row is gone when the command is: the stage's ✓ row takes its place.
  [[ "$output" == *$'\r\e[K' ]]
  run ! grep -q '^gum spin' "$STUB_LOG"
}

@test "download progress: a partial download from before the command isn't counted" {
  export OMAMAC_TEST_UI_TERMINAL=1
  mkdir -p "$HOME/Library/Caches/Homebrew/downloads"
  head -c 3145728 /dev/zero > "$HOME/Library/Caches/Homebrew/downloads/old--zoom.pkg.incomplete"
  touch -t 202001010000 "$HOME/Library/Caches/Homebrew/downloads/old--zoom.pkg.incomplete"
  run kit "ui_run_download closed 'Upgrading VLC' sleep 0.5"
  [ "$status" -eq 0 ]
  [[ "$(drawn)" == *"Upgrading VLC"* ]]
  [[ "$(drawn)" != *"MB"* ]]
}

@test "download progress, open: the row stays for the whole command and says what Homebrew does" {
  export OMAMAC_TEST_UI_TERMINAL=1
  run kit "ui_stages 2; ui_stage 'App upgrades'
    ui_run_download open 'Upgrading Zoom' bash -c 'echo \"==> Fetching downloads for: zoom\"; sleep 0.5; $FAKE_DOWNLOAD; echo \"==> Removing App\"; sleep 0.6' _ 2 2"
  [ "$status" -eq 0 ]
  [[ "$(drawn)" == *"App upgrades     Upgrading Zoom · checking the download"* ]]
  [[ "$(drawn)" == *"App upgrades     Upgrading Zoom · 4.0 MB"* ]]
  [[ "$(drawn)" == *"App upgrades     Upgrading Zoom · removing the old version"* ]]
  # The cursor waits two lines under the row and redraws leave it there; at
  # the end the row is cleared and the cursor is back on its line.
  [[ "$output" == *$'\n\n\e7\e[2A\r\e[K'*$'\e8'* ]]
  [[ "$output" == *$'\e[2A\r\e[K' ]]
}

# SUDO_WAITS: a stand-in for sudo asking for the password, as a command's
# child: named sudo, prints Password: on the terminal (fd 9) and waits without
# a child of its own, then ends the line as sudo does after Enter. fd 8 is a
# pipe nobody writes to, for read's timeout.
SUDO_WAITS='(exec -a sudo "$BASH" -c "printf Password: >&9; read -r -t 1.2 _ <&8; echo >&9")'

@test "password: when sudo waits, the row says who needs it and why, once, above sudo's prompt" {
  export OMAMAC_TEST_UI_TERMINAL=1
  run kit "exec 9>&1 8< <(sleep 3); ui_stages 13; ui_stage Apps
    ui_run_download open 'Upgrading Spotify' bash -c 'echo \"==> Upgrading spotify\"; echo \"==> Removing launchctl service com.spotify.client.startuphelper\"; sleep 0.3; $SUDO_WAITS; sleep 0.4'"
  [ "$status" -eq 0 ]
  after=${output#*Password:}
  [ "$after" != "$output" ]
  # Saved cursor, up to the row, the label; down a line, the reason; back.
  [[ "$after" == *$'\e7\e[2A\r\e[K'*"Apps             "*"Spotify needs your Mac password"*$'\e[1B\r\e[K'*"to stop its background helper."*$'\e8'* ]]
  [ "$(grep -o 'needs your Mac password' <<< "$output" | wc -l)" -eq 1 ]
  # Nothing moved the cursor off sudo's line before the label.
  [[ "${after%%needs your Mac password*}" != *$'\n'* ]]
  # The reason sits under the row's text column.
  [[ "$(drawn)" == *$'\r\e[K                         to stop its background helper.'* ]]
  # The spinner goes on below sudo's prompt, not over it.
  [[ "$after" == *$'\e8\n\r\e[K'*"Upgrading Spotify"*$'\n\n'* ]]
}

@test "password: several apps need it, for their installers" {
  export OMAMAC_TEST_UI_TERMINAL=1
  run kit "exec 9>&1 8< <(sleep 3)
    ui_run_open 'Installing Zoom, Google Drive' bash -c 'echo \"==> Running installer for zoom with sudo (which may request your password)...\"; $SUDO_WAITS'"
  [ "$status" -eq 0 ]
  [[ "$(drawn)" == *"Zoom, Google Drive need your Mac password"*"to run their installer."* ]]
}

@test "password: a sudo that already runs its command gets no label" {
  export OMAMAC_TEST_UI_TERMINAL=1
  run kit "exec 9>&1
    ui_run_download open 'Upgrading Spotify' bash -c '(exec -a sudo \"\$BASH\" -c \"sleep 1; true\")'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"needs your Mac password"* ]]
  [[ "$(drawn)" == *"Upgrading Spotify"* ]]
}

@test "password: the reason follows Homebrew's last step" {
  run kit 'for l in "Running installer for zoom" "Removing launchctl service x" "Uninstalling packages with sudo" "Removing files:" "Linking Binary '"'"'docker'"'"' to '"'"'/usr/local/bin/docker'"'"'" "Something new"; do _ui_reason "$l" its; echo "$REPLY"; done'
  [ "$output" = "to run its installer.
to stop its background helper.
to remove its system files.
to remove its system files.
to link its tools into /usr/local.
to change system files." ]
}

@test "download progress, open: the command reads the terminal's input" {
  export OMAMAC_TEST_UI_TERMINAL=1
  run kit "ui_run_download open 'Upgrading Zoom' bash -c 'read -r x; [ \"\$x\" = hi ]' <<< hi"
  [ "$status" -eq 0 ]
}

@test "download progress: a failed command fails the stage with its title" {
  export OMAMAC_TEST_UI_TERMINAL=1
  run --separate-stderr kit 'ui_stages 2; ui_stage Apps; OMAMAC_STEP="upgrading VLC"; ui_run_download closed "Upgrading VLC" false || ui_stopped "run omamac update again"'
  [[ "$(printf '%s' "$stderr" | uncoloured)" == *"Apps            Upgrading VLC didn't finish"* ]]
}
