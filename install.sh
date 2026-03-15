#!/usr/bin/env bash

set -e

DOTFILES_REPO="https://github.com/fstermann/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

# ── Load UI library ──────────────────────────────────────────────────────────
# On a fresh install the dotfiles haven't been checked out yet, so fetch ui.sh
# directly from GitHub; re-source after checkout to pick up any local edits.
_UI_LIB="$HOME/.config/lib/ui.sh"
_UI_URL="https://raw.githubusercontent.com/fstermann/dotfiles/main/.config/lib/ui.sh"

if [[ -f "$_UI_LIB" ]]; then
  # shellcheck source=.config/lib/ui.sh
  source "$_UI_LIB"
else
  _ui_tmp=$(mktemp)
  curl -fsSL "$_UI_URL" -o "$_ui_tmp"
  source "$_ui_tmp"
  rm -f "$_ui_tmp"
fi
unset _UI_LIB _UI_URL _ui_tmp
# ─────────────────────────────────────────────────────────────────────────────

dotfiles() {
  /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

_errors=0

# ── Banner ────────────────────────────────────────────────────────────────────
printf "\n${BOLD}  Dotfiles Installer${RESET}\n"
printf "  ${DIM}%s${RESET}\n" "$DOTFILES_REPO"

# ── Clone ─────────────────────────────────────────────────────────────────────
section "Clone"

if [ -d "$DOTFILES_DIR" ]; then
  info "$DOTFILES_DIR already exists — skipping clone"
else
  step "Clone dotfiles repository" \
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR" || (( _errors++ ))
fi

# ── Backup ────────────────────────────────────────────────────────────────────
section "Backup"

mkdir -p "$BACKUP_DIR"
conflicting=$(dotfiles checkout 2>&1 | grep -E "^\s+\." | awk '{print $1}')

if [ -n "$conflicting" ]; then
  step "Back up conflicting dotfiles" bash -c "
    while IFS= read -r file; do
      dest=\"$BACKUP_DIR/\$file\"
      mkdir -p \"\$(dirname \"\$dest\")\"
      mv \"\$HOME/\$file\" \"\$dest\"
      echo \"  backed up: \$file\"
    done <<< \"\$conflicting\"
  " || (( _errors++ ))
else
  info "No conflicting dotfiles found"
fi

# ── Checkout ──────────────────────────────────────────────────────────────────
section "Checkout"

step "Check out dotfiles" \
  dotfiles checkout || (( _errors++ ))

step "Hide untracked files in status" \
  dotfiles config --local status.showUntrackedFiles no || (( _errors++ ))

# Re-source the local copy now that dotfiles are checked out
# shellcheck source=.config/lib/ui.sh
source "$HOME/.config/lib/ui.sh"

# ── Platform packages ─────────────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
  section "macOS Packages"
  # shellcheck source=.config/brew/brew.install
  if command -v brew &> /dev/null; then
    info "Homebrew is already installed, skipping"
  else
    source ~/.config/brew/brew.install || (( _errors++ ))
  fi
  # shellcheck source=.config/macos/macos.install
  step "Configure macOS settings" \
    source ~/.config/macos/macos.install || (( _errors++ ))
  # shellcheck source=.config/macos/terminal.install
  step "Configure macOS terminal settings" \
    source ~/.config/macos/terminal.install || (( _errors++ ))
fi

# ── Shell ─────────────────────────────────────────────────────────────────────
section "Shell"
# shellcheck source=.config/zsh/zsh.install
step "Install zsh and plugins" \
  source ~/.config/zsh/zsh.install || (( _errors++ ))
# shellcheck source=.config/fzf/fzf.install
step "Install fzf" \
  source ~/.config/fzf/fzf.install || (( _errors++ ))

# ── Summary ───────────────────────────────────────────────────────────────────
install_summary "$_errors"

info "Use the 'dotfiles' alias to manage your dotfiles."
