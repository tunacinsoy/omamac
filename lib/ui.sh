# shellcheck shell=bash
# Output helpers. Sourced after lib/paths.sh. Plain text stays readable when gum adds no styling.

OMAMAC_LOG=${OMAMAC_LOG:-/dev/null}
# gum by its full path: doctor must still report when Homebrew isn't on PATH.
UI_GUM=${OMAMAC_BREW_PREFIX:?lib/ui.sh needs lib/paths.sh first}/bin/gum
# gum reads GUM_* settings from the environment; the user's own could
# pre-select an answer or hide a prompt, so none reach omamac's gum.
for _ui_var in "${!GUM_@}"; do unset "$_ui_var"; done
unset _ui_var

# The terminal look (#46): when stdout is a terminal as omamac starts, every
# command is drawn from one kit of six blocks (row, heading, sheet, titled box,
# count line, gum's questions). Anywhere else (a pipe, the log, bats) omamac
# prints the plain text it always has, so what reads that text keeps working.
# Decided once, here: a helper called inside $( … ) or >&2 must not switch
# looks halfway. OMAMAC_TEST_UI_TERMINAL=1 forces the look, for tests only.
if [ -n "${OMAMAC_TEST_UI_TERMINAL:-}" ] || [ -t 1 ]; then UI_TERM=1; else UI_TERM=0; fi
# Everything fits an 80-column terminal, whatever the window's width.
UI_WIDTH=80
# A row's name column, wide enough for "Shell and theme".
UI_NAME=16
# Only the terminal's 16 ANSI colours, so the look follows `omamac theme`.
# NO_COLOR (no-color.org) keeps the layout and drops the colour.
if [ -n "${NO_COLOR:-}" ]; then
  UI_OFF='' UI_BOLD='' UI_DIM='' UI_RED='' UI_GREEN='' UI_YELLOW='' UI_BLUE=''
else
  UI_OFF=$'\e[0m' UI_BOLD=$'\e[1m' UI_DIM=$'\e[2m' UI_RED=$'\e[31m' UI_GREEN=$'\e[32m' UI_YELLOW=$'\e[33m' UI_BLUE=$'\e[34m'
fi
# A run's stages (ui_stages): how many, which one is running, and its name.
UI_STAGES=0 UI_STAGE=0 UI_STAGE_NAME=''
# What made the running stage fail, for its ✗ row; set by ui_run.
UI_LAST_FAIL=''
# UI_QUIET=1: ui_step, ui_ok and ui_info say nothing, for a command whose
# rows say it all (omamac theme). ✗ rows still show.
UI_QUIET=0

# Each helper falls back to plain text with the same markers when gum is missing,
# so doctor can still say what's wrong.
ui_has_gum() { [ -x "$UI_GUM" ]; }
# ui_term: the terminal look is on. Without gum there are no sheets or boxes,
# so it is plain text.
ui_term() { [ "$UI_TERM" -eq 1 ] && ui_has_gum; }

ui_step() {
  if ui_term; then
    # In a stage its row says it; elsewhere a blue › says what runs, so a
    # password prompt that follows has a name.
    [ -n "$UI_STAGE_NAME" ] || [ "$UI_QUIET" -eq 1 ] || ui_row step "$*"
  elif ui_has_gum; then "$UI_GUM" style --bold "$*"; else printf '%s\n' "$*"; fi
}
ui_ok() {
  if ui_term; then
    [ -n "$UI_STAGE_NAME" ] || [ "$UI_QUIET" -eq 1 ] || ui_row ok "$*"
  elif ui_has_gum; then "$UI_GUM" style "✓ $*"; else printf '✓ %s\n' "$*"; fi
}
ui_fail() {
  if ui_term; then ui_row fail "$*" >&2
  elif ui_has_gum; then "$UI_GUM" style "✗ $*" >&2; else printf '✗ %s\n' "$*" >&2; fi
}
ui_info() {
  if ui_term; then
    [ "$UI_QUIET" -eq 1 ] || ui_row info "$*"
  elif ui_has_gum; then "$UI_GUM" style "ℹ $*"; else printf 'ℹ %s\n' "$*"; fi
}
# ui_box <line>…: today's plain box. The terminal look uses ui_titled instead;
# a box no command has moved to the kit yet keeps the same rounded border.
ui_box() { if ui_has_gum; then "$UI_GUM" style --border=rounded --padding="0 2" "$@"; else printf '%s\n' "$@"; fi; }

# ui_show_failure: the log's tail and where the log is. In the terminal look
# the Stopped box (ui_stopped) shows both, so nothing is said twice.
ui_show_failure() {
  ui_term && return 0
  tail -n 20 "$OMAMAC_LOG" >&2 || true
  ui_fail "Log: $OMAMAC_LOG"
}

# ui_run_open <title> <cmd…>: output in the log, no gum spinner. For a command
# that may ask for the password: sudo prompts on the terminal itself, so it
# shows. In the terminal look it is ui_run_download open's live row.
ui_run_open() {
  local title=$1 status=0
  ui_term && { ui_run_download open "$@"; return; }
  shift
  ui_step "$title"
  "$@" >>"$OMAMAC_LOG" 2>&1 || status=$?
  [ "$status" -eq 0 ] || { UI_LAST_FAIL="$title didn't finish"; ui_show_failure; }
  return "$status"
}

# ui_run <title> <cmd…>: run under a spinner, keep all output in the log.
ui_run() {
  local title=$1 name=$1 status=0 spin=()
  ui_has_gum || { ui_run_open "$@"; return; }
  shift
  if ui_term; then
    # A blue spinner in the mark column, so it turns into the stage's ✓ in place.
    _ui_lead
    spin=(--spinner.foreground=4 "--padding=0 0 0 ${#REPLY}")
    if [ -n "$UI_STAGE_NAME" ]; then
      printf -v title '%-*s %s' "$UI_NAME" "$UI_STAGE_NAME" "$title"
    fi
  fi
  # The inner bash writes the log itself: gum spin captures output on its own.
  # shellcheck disable=SC2016 # the inner bash expands these
  "$UI_GUM" spin "${spin[@]}" --title "$title" -- bash -c '"$@" >>"$0" 2>&1' "$OMAMAC_LOG" "$@" || status=$?
  [ "$status" -eq 0 ] || { UI_LAST_FAIL="$name didn't finish"; ui_show_failure; }
  return "$status"
}

# Homebrew downloads into this folder, to <hash>--<file>.incomplete until done.
UI_BREW_DOWNLOADS=${HOMEBREW_CACHE:-$HOME/Library/Caches/Homebrew}/downloads

# ui_run_download <closed|open> <title> <cmd…>: a Homebrew command that may
# download, its output in the log. In the terminal look its row says how much
# has come and how fast ("Upgrading Zoom · 142 MB · 3.1 MB/s"): a big app from
# a slow server then reads as slow, not stuck. Homebrew gives no total, so
# there is no percentage. closed is ui_run's spinner row, for the whole command.
# open is for a command that may ask for the password, which sudo asks on the
# terminal itself (omamac never feeds or skips it). Its row also says what
# Homebrew is doing ("removing the old version"), and keeps two empty lines
# under it with the cursor on the lower one, where sudo's Password: lands.
# While a sudo waits, the row stands still, so nothing moves the cursor under
# it; once it has waited two frames, the row says who needs the password and
# the line under it why. Plain text: ui_run or ui_run_open.
ui_run_download() {
  local mode=$1 title=$2 name=$2 pid status=0 tick=0 drawn=0 asked=0 waiting=0
  local start now bytes old_t old_b detail line offset=0 state LC_ALL=en_US.UTF-8
  local frames=(⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷) samples=()
  shift 2
  if ! ui_term; then
    if [ "$mode" = open ]; then ui_run_open "$title" "$@"; else ui_run "$title" "$@"; fi
    return
  fi
  _ui_lead
  local lead=$REPLY
  [ -z "$UI_STAGE_NAME" ] || printf -v title '%-*s %s' "$UI_NAME" "$UI_STAGE_NAME" "$title"
  start=$EPOCHSECONDS
  # Homebrew's ==> lines from this command only: the log before it is older steps'.
  [ "$OMAMAC_LOG" = /dev/null ] || offset=$(stat -f %z "$OMAMAC_LOG" 2>/dev/null) || offset=0
  # A background command's input would be /dev/null; <&0 keeps the terminal's.
  "$@" <&0 >>"$OMAMAC_LOG" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$mode" = open ]; then
      _ui_sudo_state "$pid"
      state=$REPLY
      case $state in
        waiting)
          # Two frames with no command under it: sudo is asking. Say so once,
          # on the row above its prompt (none before the row is drawn).
          waiting=$((waiting + 1))
          if [ "$waiting" -ge 2 ] && [ "$asked" -eq 0 ] && [ "$drawn" -eq 1 ]; then
            asked=1
            _ui_password_label "$name" "$offset" "$lead"
          fi
          sleep 0.2; continue ;;
      esac
      # sudo has its password (or never needed one): the spinner goes on
      # below whatever sudo printed.
      [ "$asked" -eq 0 ] || { drawn=0 asked=0; }
      waiting=0
    fi
    _ui_download_bytes "$start"
    bytes=$REPLY
    now=${EPOCHREALTIME/[.,]/}
    detail=''
    if [ -n "$bytes" ]; then
      samples+=("$now $bytes")
      # The speed over the last two seconds.
      while [ "${#samples[@]}" -gt 1 ] && [ $((now - ${samples[1]%% *})) -ge 2000000 ]; do
        samples=("${samples[@]:1}")
      done
      _ui_size "$bytes"
      detail=" · $REPLY"
      read -r old_t old_b <<< "${samples[0]}"
      if [ $((now - old_t)) -ge 500000 ] && [ "$bytes" -ge "$old_b" ]; then
        # Tenths of a MB/s: bytes per µs × 10⁶, in units of 2²⁰ bytes, × 10.
        REPLY=$(((bytes - old_b) * 10000000 / ((now - old_t) * 1048576)))
        detail+=" · $((REPLY / 10)).$((REPLY % 10)) MB/s"
      fi
    else
      samples=()
      if [ "$mode" = open ]; then
        _ui_brew_line "$offset"
        _ui_phase "$REPLY"
        [ -z "$REPLY" ] || detail=" · $REPLY"
      fi
    fi
    line="$lead$UI_BLUE${frames[tick % ${#frames[@]}]}$UI_OFF $title"
    # 80 columns: the speed goes first, then the size.
    [ $((${#lead} + 2 + ${#title} + ${#detail})) -le "$UI_WIDTH" ] || detail=${detail% · *}
    [ $((${#lead} + 2 + ${#title} + ${#detail})) -le "$UI_WIDTH" ] || detail=''
    if [ "$mode" = closed ]; then
      printf '\r\e[K%s%s%s%s' "$line" "$UI_DIM" "$detail" "$UI_OFF"
    elif [ "$drawn" -eq 0 ]; then
      # The row, then two empty lines; the cursor waits on the lower one.
      printf '\r\e[K%s%s%s%s\n\n' "$line" "$UI_DIM" "$detail" "$UI_OFF"
    else
      # The cursor stays where it is: a sudo that started since the last look
      # may have put its Password: there.
      printf '\e7\e[2A\r\e[K%s%s%s%s\e8' "$line" "$UI_DIM" "$detail" "$UI_OFF"
    fi
    drawn=1 tick=$((tick + 1))
    sleep 0.2
  done
  wait "$pid" || status=$?
  if [ "$drawn" -eq 1 ]; then
    if [ "$mode" = closed ]; then printf '\r\e[K'; else printf '\e[2A\r\e[K'; fi
  fi
  [ "$status" -eq 0 ] || { UI_LAST_FAIL="$name didn't finish"; ui_show_failure; }
  return "$status"
}

# _ui_sudo_state <pid>: REPLY is "none" when no sudo runs under <pid>,
# "running" when every one has started its command (a sudo's child), "waiting"
# when one has none yet: it is asking for the password, or just about to run.
_ui_sudo_state() {
  local p pp args a0 kids=" " sudos=() s
  local -A parent=()
  REPLY=none
  while read -r p pp args; do
    parent[$p]=$pp
    kids+="$pp "
    a0=${args%% *}
    [ "${a0##*/}" != sudo ] || sudos+=("$p")
  done < <(ps -A -o pid= -o ppid= -o args= 2>/dev/null)
  for s in "${sudos[@]}"; do
    # Only a sudo under this command.
    p=$s
    while [ -n "${parent[$p]:-}" ] && [ "$p" != "$1" ] && [ "$p" -gt 1 ]; do p=${parent[$p]}; done
    [ "$p" = "$1" ] || continue
    if [[ $kids == *" $s "* ]]; then REPLY=running; else REPLY=waiting; return 0; fi
  done
}

# _ui_brew_line <offset>: REPLY is the last line Homebrew started with ==> in
# the log after <offset> bytes, without the ==>; empty when none.
_ui_brew_line() {
  local l
  REPLY=''
  [ "$OMAMAC_LOG" != /dev/null ] && [ -f "$OMAMAC_LOG" ] || return 0
  while IFS= read -r l; do
    [[ $l != '==> '* ]] || REPLY=${l#==> }
  done < <(tail -c +$(($1 + 1)) "$OMAMAC_LOG" 2>/dev/null)
}

# _ui_phase <line>: REPLY is what Homebrew is doing, in plain words, from one
# of its ==> lines; empty when it says nothing a user needs.
_ui_phase() {
  case $1 in
    Fetching*|Downloading*) REPLY='checking the download' ;;
    *launchctl*|Uninstall*|Removing*|Purging*|Backing*|Quitting*|Signalling*|Trashing*) REPLY='removing the old version' ;;
    Installing*|Moving*|Linking*|Running\ installer*|Artifact*|Upgrading*) REPLY='installing the new version' ;;
    *) REPLY='' ;;
  esac
}

# _ui_reason <line> <its|their>: REPLY is why sudo needs the password, from
# the ==> line Homebrew wrote last before it asked. It goes under "Spotify
# needs your Mac password", so it reads on from it.
_ui_reason() {
  case $1 in
    *installer*) REPLY="to run $2 installer" ;;
    *launchctl*) REPLY="to stop $2 background helper" ;;
    *packages*|*pkgutil*|*"Removing files"*|*Purging*) REPLY="to remove $2 system files" ;;
    *Link*|*link*) REPLY="to link $2 tools into /usr/local" ;;
    *) REPLY="to change system files" ;;
  esac
  REPLY+=.
}

# _ui_password_label <title> <offset> <lead>: sudo is waiting on the line
# below the row's empty one. The row says who needs the password, that line
# why; the cursor goes back to where sudo left it.
_ui_password_label() {
  local who=${1#* } verb=needs its=its pad row
  # "Upgrading Zoom, Google Drive": several apps.
  if [[ $who == *,* || $who == *" and "* ]]; then verb=need its=their; fi
  _ui_brew_line "$2"
  _ui_reason "$REPLY" "$its"
  if [ -n "$UI_STAGE_NAME" ]; then
    printf -v row '%s%s›%s %-*s %s%s %s your Mac password%s' "$3" "$UI_YELLOW" "$UI_OFF" "$UI_NAME" "$UI_STAGE_NAME" "$UI_YELLOW" "$who" "$verb" "$UI_OFF"
    printf -v pad '%*s' $((${#3} + 2 + UI_NAME + 1)) ''
  else
    printf -v row '%s%s›%s %s%s %s your Mac password%s' "$3" "$UI_YELLOW" "$UI_OFF" "$UI_YELLOW" "$who" "$verb" "$UI_OFF"
    printf -v pad '%*s' $((${#3} + 2)) ''
  fi
  printf '\e7\e[2A\r\e[K%s\e[1B\r\e[K%s%s%s%s\e8' "$row" "$pad" "$UI_DIM" "$REPLY" "$UI_OFF"
}

# _ui_download_bytes <since>: REPLY is how many bytes Homebrew's downloads
# started since <since> (epoch seconds) have come so far; empty when none runs.
_ui_download_bytes() {
  local files=("$UI_BREW_DOWNLOADS"/*.incomplete) out m z total=0 any=0
  REPLY=''
  [ -e "${files[0]}" ] || return 0
  # A file can finish between the glob and stat; it isn't running then.
  out=$(stat -f '%m %z' "${files[@]}" 2>/dev/null) || true
  while read -r m z; do
    [ -n "$z" ] && [ "$m" -ge "$1" ] || continue
    total=$((total + z)) any=1
  done <<< "$out"
  [ "$any" -eq 0 ] || REPLY=$total
}

# _ui_size <bytes>: REPLY is it as people read it: "4.2 MB", "142 MB", "1.3 GB".
_ui_size() {
  local tenths=$(($1 * 10 / 1048576))
  if [ "$tenths" -lt 100 ]; then REPLY="$((tenths / 10)).$((tenths % 10)) MB"
  elif [ "$tenths" -lt 10240 ]; then REPLY="$((tenths / 10)) MB"
  else tenths=$(($1 * 10 / 1073741824)); REPLY="$((tenths / 10)).$((tenths % 10)) GB"; fi
}

# --- The kit's internals. Each sets REPLY or UI_LINES rather than printing,
# so no subshell runs per cell.

# _ui_strip <text>: REPLY is the text without its colour codes.
_ui_strip() {
  REPLY=$1
  while [[ $REPLY =~ $'\e'\[[0-9\;]*m ]]; do REPLY=${REPLY/"${BASH_REMATCH[0]}"/}; done
}

# _ui_len <text>: REPLY is how many columns the text takes. UTF-8, so ✓ and →
# count once whatever the user's locale.
_ui_len() {
  local LC_ALL=en_US.UTF-8
  _ui_strip "$1"
  REPLY=${#REPLY}
}

# _ui_wrap <width> <text>: UI_LINES is the text broken at spaces into lines of
# at most width columns; a longer word is cut.
_ui_wrap() {
  local width=$1 word line='' words=() LC_ALL=en_US.UTF-8
  UI_LINES=()
  read -ra words <<< "$2"
  for word in "${words[@]}"; do
    while [ "${#word}" -gt "$width" ]; do
      [ -z "$line" ] || { UI_LINES+=("$line"); line=''; }
      UI_LINES+=("${word:0:width}")
      word=${word:width}
    done
    if [ -z "$line" ]; then
      line=$word
    elif [ $((${#line} + 1 + ${#word})) -le "$width" ]; then
      line+=" $word"
    else
      UI_LINES+=("$line")
      line=$word
    fi
  done
  [ -z "$line" ] || UI_LINES+=("$line")
  [ "${#UI_LINES[@]}" -gt 0 ] || UI_LINES=('')
}

# _ui_lead: REPLY is the start of a row. "  " outside a run's stages; in one,
# as wide as "12/12 ", so every row of the run lines up after the counts.
_ui_lead() {
  if [ "$UI_STAGES" -gt 0 ]; then printf -v REPLY '%*s' $((${#UI_STAGES} * 2 + 2)) ''; else REPLY='  '; fi
}

# --- The blocks.

# ui_row <ok|fail|info|step|none> <name> [<detail>]: one thing and its state.
# A mark, the name, and a dim detail in an aligned column (a ✗'s detail is
# red). With no detail, the name is the whole sentence (a ✗'s in red). Lines
# wrap under their column, so a row fits 80 columns.
ui_row() {
  local mark=$1 name=$2 detail=${3:-} sym=' ' col='' dcol=$UI_DIM lead pad i nw
  case $mark in
    ok) sym=✓ col=$UI_GREEN ;;
    fail) sym=✗ col=$UI_RED dcol=$UI_RED ;;
    info) sym=ℹ col=$UI_BLUE ;;
    step) sym=› col=$UI_BLUE ;;
  esac
  _ui_lead
  lead=$REPLY
  # The stage's own row carries its count, dim.
  if [ -n "${_UI_COUNTED:-}" ]; then
    printf -v lead '%*s ' $((${#lead} - 1)) "$UI_STAGE/$UI_STAGES"
    lead="$UI_DIM$lead$UI_OFF"
  fi
  _ui_len "$lead"
  printf -v pad '%*s' $((REPLY + 2)) ''
  if [ -z "$detail" ]; then
    _ui_wrap $((UI_WIDTH - ${#pad})) "$name"
    [ "$mark" = fail ] || dcol=''
    for i in "${!UI_LINES[@]}"; do
      if [ "$i" -eq 0 ]; then printf '%s%s%s%s %s%s%s\n' "$lead" "$col" "$sym" "$UI_OFF" "$dcol" "${UI_LINES[0]}" "${dcol:+$UI_OFF}"
      else printf '%s%s%s%s\n' "$pad" "$dcol" "${UI_LINES[$i]}" "${dcol:+$UI_OFF}"; fi
    done
    return 0
  fi
  _ui_len "$name"
  nw=$UI_NAME
  [ "$REPLY" -lt "$UI_NAME" ] || nw=$((REPLY + 1))
  _ui_wrap $((UI_WIDTH - ${#pad} - nw)) "$detail"
  local LC_ALL=en_US.UTF-8
  printf '%s%s%s%s %-*s%s%s%s\n' "$lead" "$col" "$sym" "$UI_OFF" "$nw" "$name" "$dcol" "${UI_LINES[0]}" "$UI_OFF"
  for i in "${!UI_LINES[@]}"; do
    [ "$i" -eq 0 ] || printf '%s%*s%s%s%s\n' "$pad" "$nw" '' "$dcol" "${UI_LINES[$i]}" "$UI_OFF"
  done
}

# ui_heading <text> [<more>]: names a group of rows. Bold; nothing else is.
# <more> follows it, dim: "Theme · Tokyo Night".
ui_heading() {
  if [ -n "${2:-}" ]; then printf '%s%s%s %s· %s%s\n' "$UI_BOLD" "$1" "$UI_OFF" "$UI_DIM" "$2" "$UI_OFF"
  else printf '%s%s%s\n' "$UI_BOLD" "$1" "$UI_OFF"; fi
}

# _ui_cell <cell>: REPLY is the cell's text and UI_STYLE its colour codes. A
# cell may start with a style: {dim} {bold} {ok} {fail} {info} {red} {yellow}.
_ui_cell() {
  UI_STYLE='' REPLY=$1
  if [[ $1 =~ ^\{(dim|bold|ok|fail|info|red|yellow)\}(.*)$ ]]; then
    REPLY=${BASH_REMATCH[2]}
    case ${BASH_REMATCH[1]} in
      dim) UI_STYLE=$UI_DIM ;;
      bold) UI_STYLE=$UI_BOLD ;;
      ok) UI_STYLE=$UI_GREEN ;;
      fail | red) UI_STYLE=$UI_RED ;;
      info) UI_STYLE=$UI_BLUE ;;
      yellow) UI_STYLE=$UI_YELLOW ;;
    esac
  fi
}

# _ui_csv <field>: REPLY is the field quoted for gum's CSV reader.
_ui_csv() { REPLY="\"${1//\"/\"\"}\""; }

# ui_sheet <header> <row>…: many things side by side, with gum table --print.
# The header and each row are cells joined by tabs (see _ui_cell for styles);
# an empty header draws none. The last column wraps, so the sheet fits 80
# columns; a cell in another column may hold colour codes of its own.
ui_sheet() {
  local header=$1 row i n=0 avail lastw=0 used=0 csv line sep=-1 cells=() widths=() out=() rows=() wrapped
  shift
  # Pass 1: how many columns, and how wide each is.
  for row in "$header" "$@"; do
    IFS=$'\x1f' read -ra cells <<< "${row//$'\t'/$'\x1f'}"
    [ "${#cells[@]}" -le "$n" ] || n=${#cells[@]}
    for i in "${!cells[@]}"; do
      _ui_cell "${cells[$i]}"
      _ui_len "$REPLY"
      [ "$REPLY" -le "${widths[$i]:-0}" ] || widths[i]=$REPLY
    done
  done
  for ((i = 0; i < n - 1; i++)); do used=$((used + ${widths[$i]:-0})); done
  # A border, then " cell " and a border per column.
  avail=$((UI_WIDTH - used - 3 * n - 1))
  lastw=${widths[$((n - 1))]:-1}
  [ "$lastw" -le "$avail" ] || lastw=$avail
  [ "$lastw" -ge 1 ] || lastw=1
  # Pass 2: each row as CSV, the last cell wrapped and every line styled.
  for row in "$@"; do
    IFS=$'\x1f' read -ra cells <<< "${row//$'\t'/$'\x1f'}"
    csv=''
    for ((i = 0; i < n; i++)); do
      _ui_cell "${cells[$i]:-}"
      if [ "$i" -eq $((n - 1)) ]; then
        _ui_wrap "$lastw" "$REPLY"
        wrapped=''
        for line in "${UI_LINES[@]}"; do
          wrapped+="${wrapped:+$'\n'}${UI_STYLE}${line}${UI_STYLE:+$UI_OFF}"
        done
        REPLY=$wrapped
      else
        REPLY="${UI_STYLE}${REPLY}${UI_STYLE:+$UI_OFF}"
      fi
      _ui_csv "$REPLY"
      csv+="${csv:+,}$REPLY"
    done
    rows+=("$csv")
  done
  # The column names, bold, or a space each when there is no header: the first
  # CSV line, not --columns, which splits a name at its comma.
  IFS=$'\x1f' read -ra cells <<< "${header//$'\t'/$'\x1f'}"
  csv=''
  for ((i = 0; i < n; i++)); do
    REPLY=' '
    [ -z "$header" ] || [ -z "${cells[$i]:-}" ] || REPLY="$UI_BOLD${cells[$i]}$UI_OFF"
    _ui_csv "$REPLY"
    csv+="${csv:+,}$REPLY"
  done
  # gum 2.0's --print styles the first data row as its header (bold), so an
  # empty first row takes that, and is dropped below.
  printf -v line '%*s' $((n - 1)) ''
  line=${line// /,}
  mapfile -t out < <(printf '%s\n' "$csv" "$line" "${rows[@]}" |
    _ui_gum_color "$UI_GUM" table --print --border=rounded --separator=,)
  for i in "${!out[@]}"; do
    if [[ ${out[$i]} == ├* ]]; then sep=$i; break; fi
  done
  [ "$sep" -ge 0 ] || { printf '%s\n' "${out[@]}"; return 0; }
  for i in "${!out[@]}"; do
    # The empty row; with no header, the header's line and the line under it too.
    [ "$i" -ne $((sep + 1)) ] || continue
    if [ -z "$header" ] && [ "$i" -ge 1 ] && [ "$i" -le "$sep" ]; then continue; fi
    printf '%s\n' "${out[$i]}"
  done
}

# _ui_gum_color <cmd…>: run gum, keeping the colour codes in its cells. gum
# drops them when stdout isn't a terminal, which is only the forced look of the tests.
_ui_gum_color() {
  if [ -n "$UI_OFF" ]; then CLICOLOR_FORCE=1 "$@"; else "$@"; fi
}

# ui_sheet_labels <label<TAB>value>…: a sheet of labels and their values,
# the labels dim; an empty value is a dim dash.
ui_sheet_labels() {
  local row label value rows=()
  for row in "$@"; do
    label=${row%%$'\t'*} value=${row#*$'\t'}
    [ "$row" != "$label" ] || value=''
    [ -n "$value" ] || value='{dim}—'
    rows+=("{dim}$label"$'\t'"$value")
  done
  ui_sheet '' "${rows[@]}"
}

# ui_titled [-c] <ok|warn|fail> <title> <row>…: one outcome in a rounded box,
# its title in the top border, coloured for its meaning: green Done, yellow To
# fix or Removes, red Stopped. A row is "label<TAB>value", the labels dim and
# lined up. A row "--" draws a divider, and every row after it is a dim line
# of its own (the log's last lines). With -c, each label is a command, on its
# own line with its value dim under it, and a blank line between them.
ui_titled() {
  local cmds=0 tone title col row label value labelw=0 w=0 i lines=() out=() dashes rest=0 LC_ALL=en_US.UTF-8
  [ "$1" != -c ] || { cmds=1; shift; }
  tone=$1 title=$2
  shift 2
  case $tone in
    ok) col=$UI_GREEN ;;
    warn) col=$UI_YELLOW ;;
    *) col=$UI_RED ;;
  esac
  for row in "$@"; do
    [ "$row" != -- ] || break
    label=${row%%$'\t'*}
    [ "${#label}" -le "$labelw" ] || labelw=${#label}
  done
  # The box's inside is 76 columns: a border and a space of padding each side.
  for row in "$@"; do
    if [ "$rest" -eq 1 ]; then
      # A log line: what a progress bar's \r left last, no control
      # characters, cut to the box.
      row=${row%$'\r'}
      row=${row##*$'\r'}
      _ui_strip "$row"
      row=${REPLY//$'\t'/ }
      row=${row//[[:cntrl:]]/}
      lines+=("$UI_DIM${row:0:76}$UI_OFF")
      continue
    fi
    if [ "$row" = -- ]; then
      rest=1
      lines+=('⁂')
      continue
    fi
    label=${row%%$'\t'*} value=${row#*$'\t'}
    [ "$row" != "$label" ] || value=''
    if [ "$cmds" -eq 1 ]; then
      [ "${#lines[@]}" -eq 0 ] || lines+=('')
      _ui_wrap 76 "$label"
      lines+=("${UI_LINES[@]}")
      _ui_wrap 74 "$value"
      for i in "${UI_LINES[@]}"; do lines+=("  $UI_DIM$i$UI_OFF"); done
      continue
    fi
    _ui_wrap $((76 - labelw - 2)) "$value"
    for i in "${!UI_LINES[@]}"; do
      if [ "$i" -eq 0 ]; then printf -v row '%s%-*s%s  %s' "$UI_DIM" "$labelw" "$label" "$UI_OFF" "${UI_LINES[0]}"
      else printf -v row '%*s  %s' "$labelw" '' "${UI_LINES[$i]}"; fi
      lines+=("$row")
    done
  done
  # Room for the title in the top border: "╭ Title ─╮".
  for row in "${lines[@]}"; do
    _ui_len "$row"
    [ "$REPLY" -le "$w" ] || w=$REPLY
  done
  if [ "$w" -lt $((${#title} + 1)) ]; then
    _ui_len "${lines[0]:-}"
    printf -v row '%*s' $((${#title} + 1 - REPLY)) ''
    lines[0]="${lines[0]:-}$row"
  fi
  mapfile -t out < <(_ui_gum_color "$UI_GUM" style --border=rounded --padding="0 1" "${lines[@]}")
  # The top border is plain box drawing; the title takes its start.
  w=${#out[0]}
  printf -v dashes '%*s' $((w - ${#title} - 4)) ''
  out[0]="╭ $col$title$UI_OFF ${dashes// /─}╮"
  printf -v dashes '%*s' $((w - 2)) ''
  for i in "${!out[@]}"; do
    [[ ${out[$i]} != *⁂* ]] || out[i]="├${dashes// /─}┤"
  done
  printf '%s\n' "${out[@]}"
}

# ui_count <problems> <notes> <fine> [<updates>]: the verdict under a sheet of
# checks, "1 problem · 1 note · 14 fine". A count of none is left out, except
# fine. Updates waiting end it, yellow: "· 2 updates waiting: omamac update".
ui_count() {
  local parts=() s
  [ "$1" -eq 0 ] || { s=s; [ "$1" -ne 1 ] || s=''; parts+=("$UI_RED$1 problem$s$UI_OFF"); }
  [ "$2" -eq 0 ] || { s=s; [ "$2" -ne 1 ] || s=''; parts+=("$UI_BLUE$2 note$s$UI_OFF"); }
  parts+=("$UI_GREEN$3 fine$UI_OFF")
  [ "${4:-0}" -eq 0 ] || { s=s; [ "$4" -ne 1 ] || s=''; parts+=("$UI_YELLOW$4 update$s waiting: omamac update$UI_OFF"); }
  local IFS=$'\x1f'
  s="${parts[*]}"
  printf '%s\n' "${s//$'\x1f'/ · }"
}

# --- Stages: a run's progress rows, each with its count ("3/6 ✓ Core tools").
# The caller counts only the stages this run will do, so no number is skipped.
# All are no-ops in plain text, which keeps its own lines.

# ui_stages <n>: this run has n stages.
ui_stages() { ui_term || return 0; UI_STAGES=$1 UI_STAGE=0 UI_STAGE_NAME=''; }

# ui_stage <name>: the next stage starts. Inside it, ui_step and ui_ok say
# nothing (its row will); ℹ and ✗ rows still show.
ui_stage() {
  ui_term || return 0
  UI_STAGE=$((UI_STAGE + 1)) UI_STAGE_NAME=$1 UI_LAST_FAIL=''
}

# ui_stage_done [<detail>]: the running stage's ✓ row.
ui_stage_done() {
  ui_term || return 0
  [ -n "$UI_STAGE_NAME" ] || return 0
  _UI_COUNTED=1 ui_row ok "$UI_STAGE_NAME" "${1:-}"
  UI_STAGE_NAME=''
}

# ui_stopped <fix>: a run stopped. The running stage's row turns into a red ✗
# with the reason, then a red Stopped box says while doing what (OMAMAC_STEP),
# how to fix it and where the log is, with the log's last lines.
ui_stopped() {
  local rows=() tail=() log=$OMAMAC_LOG why="didn't finish"
  if [ -n "$UI_STAGE_NAME" ]; then
    [ -z "$UI_LAST_FAIL" ] || why=$UI_LAST_FAIL
    _UI_COUNTED=1 ui_row fail "$UI_STAGE_NAME" "$why" >&2
    UI_STAGE_NAME=''
  fi
  rows=("While"$'\t'"${OMAMAC_STEP:-starting}" "Fix"$'\t'"$1")
  [ "$log" = /dev/null ] || rows+=("Log"$'\t'"${log/#"$HOME"/\~}")
  if [ "$log" != /dev/null ] && [ -s "$log" ]; then
    mapfile -t tail < <(tail -n 6 "$log")
    rows+=(-- "${tail[@]}")
  fi
  ui_titled fail Stopped "${rows[@]}" >&2
}
