# shellcheck shell=bash
# The run's log file. Sourced after lib/paths.sh. boot.sh keeps its own copy
# (boot_log_start): it runs before the checkout, so it can't source lib/.

# log_start: a new log in $OMAMAC_STATE_DIR/logs; sets and exports OMAMAC_LOG.
log_start() {
  local dir="$OMAMAC_STATE_DIR/logs" old
  mkdir -p "$dir"
  OMAMAC_LOG="$dir/$(date -u +%Y%m%dT%H%M%SZ).log"
  : > "$OMAMAC_LOG"
  export OMAMAC_LOG
  # Names sort by time, so everything after the newest 10 is old.
  # shellcheck disable=SC2012 # our own names are plain, and ls sorts them
  ls -1 "$dir" | sort -r | tail -n +11 | while IFS= read -r old; do
    rm -f "$dir/$old"
  done
}
