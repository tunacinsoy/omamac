# shellcheck shell=bash
# omamac with no command: ask what to do, then run that command as if it had
# been typed, so its errors, exit codes and "run omamac X again" lines are its
# own. Sourced after lib/ask.sh.

menu_run() {
  ask_choose "What do you want to do?" \
    "Install something:install" \
    "Remove something:uninstall" \
    "Change a macOS setting:configure" \
    "Switch the theme:theme" \
    "Update everything:update" \
    "Check everything:doctor"
  exec "$BASH" "$OMAMAC_CHECKOUT/bin/omamac" "$ASK_PICKED"
}
