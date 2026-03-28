#!/usr/bin/env bash
# base.sh — shared baseline profile (always installed)
#
# Every profile sources this first, then adds/removes items.

# Stow packages to symlink
PROFILE_STOW_PACKAGES=(zsh git fzf oh-my-posh macos claude)

# Extra installer scripts to run after platform packages (brew.macos, etc.)
PROFILE_BREW_FILES=()

# Description shown during profile selection
PROFILE_DESCRIPTION="Core tools only (zsh, fzf, git, oh-my-posh)"
