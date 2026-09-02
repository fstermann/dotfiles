#!/usr/bin/env bash
# packages.sh — single source of truth for the stow package list.
# Sourced by install.sh, migrate.sh, and installers/{update,restow}.sh.

# One package per tool — each mirrors the $HOME directory structure.
STOW_PACKAGES=(zsh git fzf oh-my-posh macos claude codex)
