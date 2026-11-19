# shellcheck shell=bash
# shellcheck disable=SC2034 # used by the scripts that source this file
# omamac's paths and the two lines it adds to user files. Sourced; reads HOME at source time.

OMAMAC_REPO_URL=https://github.com/tunacinsoy/omamac
OMAMAC_BREW_PREFIX=${OMAMAC_TEST_BREW_PREFIX:-/opt/homebrew}
OMAMAC_USR_LOCAL_BREW=${OMAMAC_TEST_USR_LOCAL_BREW:-/usr/local/bin/brew}
OMAMAC_APPLICATIONS=${OMAMAC_TEST_APPLICATIONS:-/Applications}
OMAMAC_HOME=$HOME/.local/share/omamac
OMAMAC_CONFIG_DIR=$HOME/.config/omamac
OMAMAC_STATE_DIR=$HOME/.local/state/omamac
OMAMAC_ZSH_FILE=$OMAMAC_CONFIG_DIR/zshrc
OMAMAC_NVIM_DIR=$HOME/.config/nvim
OMAMAC_NVIM_MARKER=$OMAMAC_NVIM_DIR/lua/plugins/omamac.lua
OMAMAC_LAZYVIM_URL=${OMAMAC_TEST_LAZYVIM_URL:-https://github.com/LazyVim/starter}
OMAMAC_CHOICES_FILE=$OMAMAC_STATE_DIR/choices.env
OMAMAC_HERDR_FILE=$OMAMAC_CONFIG_DIR/herdr.toml
OMAMAC_HERDR_USER_FILE=$HOME/.config/herdr/config.toml
OMAMAC_STARSHIP_FILE=$OMAMAC_CONFIG_DIR/starship.toml
OMAMAC_STARSHIP_USER_FILE=$HOME/.config/starship.toml
OMAMAC_BTOP_FILE=$OMAMAC_CONFIG_DIR/btop.conf
OMAMAC_BTOP_THEMES=$OMAMAC_CONFIG_DIR/btop-themes
OMAMAC_BTOP_USER_FILE=$HOME/.config/btop/btop.conf
OMAMAC_NEOVIM_THEME_FILE=$OMAMAC_CONFIG_DIR/neovim.lua
OMAMAC_HERDR_HELPER=$OMAMAC_HOME/bin/omamac-herdr-mode
OMAMAC_MISE_DROPIN=$HOME/.config/mise/conf.d/omamac.toml
OMAMAC_MISE_USER_FILE=$HOME/.config/mise/config.toml
# Prompts read the terminal: after boot.sh's exec, stdin is the spent curl pipe.
OMAMAC_TTY=${OMAMAC_TEST_TTY:-/dev/tty}
# shellcheck disable=SC2016 # literal text for the user's file, not expanded here
OMAMAC_ZPROFILE_LINE='eval "$(/opt/homebrew/bin/brew shellenv)" # added by omamac'
# shellcheck disable=SC2016
OMAMAC_ZSHRC_LINE='[[ -r ~/.config/omamac/zshrc ]] && source ~/.config/omamac/zshrc # added by omamac'
OMAMAC_GHOSTTY_FILE=$OMAMAC_CONFIG_DIR/ghostty.conf
OMAMAC_TERMINAL=$OMAMAC_HOME/bin/omamac-terminal
# No trailing comment: Ghostty reads all after = as the path, so a comment would stop the file loading.
OMAMAC_GHOSTTY_LINE='config-file = ?~/.config/omamac/ghostty.conf'
# One line per macOS setting omamac changed, with its earlier value (lib/settings.sh).
OMAMAC_SETTINGS_RECORD=$OMAMAC_STATE_DIR/macos-settings.tsv
# Written once omamac has started colima's login service (lib/docker.sh). With
# it, omamac never starts the service again, so a user's stop stays.
OMAMAC_COLIMA_MARKER=$OMAMAC_STATE_DIR/colima-service
