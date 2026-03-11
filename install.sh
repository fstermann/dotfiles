#!/usr/bin/env bash

set -e

DOTFILES_REPO="https://github.com/fstermann/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

dotfiles() {
  /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

echo "==> Cloning dotfiles bare repository..."
if [ -d "$DOTFILES_DIR" ]; then
  echo "    $DOTFILES_DIR already exists, skipping clone."
else
  git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

echo "==> Backing up pre-existing dotfiles to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

conflicting=$(dotfiles checkout 2>&1 | grep -E "^\s+\." | awk '{print $1}')

while IFS= read -r file; do
  dest="$BACKUP_DIR/$file"
  mkdir -p "$(dirname "$dest")"
  mv "$HOME/$file" "$dest"
  echo "    backed up: $file"
done <<< "$conflicting"

echo "==> Checking out dotfiles..."
dotfiles checkout

echo "==> Hiding untracked files from dotfiles status..."
dotfiles config --local status.showUntrackedFiles no

echo ""
echo "Done! Dotfiles installed."
echo "You can now use the 'dotfiles' alias to manage your dotfiles."
