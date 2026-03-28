#!/usr/bin/env bash
# update.sh — pull latest dotfiles, restow packages, and update installed tools
#
# Usage:
#   dotfiles update          (via shell function)
#   bash ~/.dotfiles/installers/update.sh

set -e

DOTFILES_DIR="$HOME/.dotfiles"
STOW_PACKAGES=(zsh git fzf oh-my-posh macos claude)

# shellcheck source=lib/ui.sh
source "$DOTFILES_DIR/installers/lib/ui.sh"

_errors=0

printf "\n${BOLD}  Dotfiles Update${RESET}\n\n"

# ── Pull latest ──────────────────────────────────────────────────────────────
section "Dotfiles"

step "Pull latest dotfiles" \
  git -C "$DOTFILES_DIR" pull --ff-only || (( _errors++ ))

# Re-source UI in case it changed
# shellcheck source=lib/ui.sh
source "$DOTFILES_DIR/installers/lib/ui.sh"

# ── Restow ───────────────────────────────────────────────────────────────────
section "Symlinks"

step "Restow packages" \
  stow --restow --no-folding -d "$DOTFILES_DIR" -t "$HOME" "${STOW_PACKAGES[@]}" || (( _errors++ ))

# ── Platform tools ───────────────────────────────────────────────────────────
section "Tools"

if [[ "$OSTYPE" == "darwin"* ]]; then
  if command -v brew &>/dev/null; then
    step "Update Homebrew packages" \
      bash -c 'brew update && brew upgrade' || (( _errors++ ))
  fi
else
  # Update zsh plugins (git-cloned on Linux)
  _update_zsh_plugins() {
    local plugin_dir="$HOME/.config/zsh/plugins"
    if [[ -d "$plugin_dir" ]]; then
      for dir in "$plugin_dir"/*/; do
        [[ -d "$dir/.git" ]] && git -C "$dir" pull --ff-only
      done
    fi
  }
  step "Update zsh plugins" _update_zsh_plugins || (( _errors++ ))

  # Update fzf
  if [[ -d "$HOME/.fzf" ]]; then
    step "Update fzf" \
      bash -c 'cd "$HOME/.fzf" && git pull --ff-only && ./install --bin' || (( _errors++ ))
  fi
fi

if command -v oh-my-posh &>/dev/null; then
  step "Update oh-my-posh" \
    oh-my-posh upgrade || (( _errors++ ))
fi

# ── Summary ──────────────────────────────────────────────────────────────────
install_summary "$_errors"
