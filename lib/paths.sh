# shellcheck shell=bash
# shellcheck disable=SC2034 # used by the scripts that source this file
# omamac's paths and the two lines it adds to user files. Sourced; reads HOME at source time.

OMAMAC_REPO_URL=https://github.com/tunacinsoy/omamac
OMAMAC_BREW_PREFIX=${OMAMAC_TEST_BREW_PREFIX:-/opt/homebrew}
OMAMAC_USR_LOCAL_BREW=${OMAMAC_TEST_USR_LOCAL_BREW:-/usr/local/bin/brew}
OMAMAC_HOME=$HOME/.local/share/omamac
OMAMAC_CONFIG_DIR=$HOME/.config/omamac
OMAMAC_STATE_DIR=$HOME/.local/state/omamac
OMAMAC_ZSH_FILE=$OMAMAC_CONFIG_DIR/zshrc
OMAMAC_NVIM_DIR=$HOME/.config/nvim
OMAMAC_NVIM_MARKER=$OMAMAC_NVIM_DIR/lua/plugins/omamac.lua
OMAMAC_LAZYVIM_URL=${OMAMAC_TEST_LAZYVIM_URL:-https://github.com/LazyVim/starter}
OMAMAC_CHOICES_FILE=$OMAMAC_STATE_DIR/choices.env
# Prompts read the terminal: after boot.sh's exec, stdin is the spent curl pipe.
OMAMAC_TTY=${OMAMAC_TEST_TTY:-/dev/tty}
# shellcheck disable=SC2016 # literal text for the user's file, not expanded here
OMAMAC_ZPROFILE_LINE='eval "$(/opt/homebrew/bin/brew shellenv)" # added by omamac'
# shellcheck disable=SC2016
OMAMAC_ZSHRC_LINE='[[ -r ~/.config/omamac/zshrc ]] && source ~/.config/omamac/zshrc # added by omamac'
