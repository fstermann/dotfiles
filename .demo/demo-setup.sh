#!/usr/bin/env bash
# demo-setup.sh — prepare a realistic dirty git state for VHS recording
# Sourced/run before the recording starts.
# In CI this creates fake changes; locally the real working state is fine.

set -e

DOTFILES_DIR="$HOME/.dotfiles"
cd "$DOTFILES_DIR"

# Only create fake changes if the tree is clean (i.e. in CI)
if git diff --quiet && git diff --cached --quiet 2>/dev/null; then
  echo "# wip" >> README.md
  echo "alias ll='ls -la'" > zsh/.zsh_aliases
  git add zsh/.zsh_aliases
  echo "Demo: created staged + unstaged changes"
else
  echo "Demo: using existing dirty state"
fi
