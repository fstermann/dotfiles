#!/usr/bin/env bash
# migrate.sh — one-time migration from bare git repo to GNU Stow
#
# Run this on a machine currently managed with the old bare-repo approach.
# It will:
#   1. Back up the old bare repo
#   2. Clone the (restructured) repo as a normal git repo into ~/.dotfiles/
#   3. Use `stow --adopt` to replace existing files with symlinks
#   4. Print verification steps

set -e

DOTFILES_REPO="https://github.com/fstermann/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BARE_BACKUP="$HOME/.dotfiles-bare-backup"
STOW_PACKAGES=(zsh git fzf oh-my-posh macos)

# ── Colors ────────────────────────────────────────────────────────────────────
RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'
info()  { printf "  ${CYAN}·${RESET} %s\n" "$*"; }
warn()  { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
error() { printf "  ${RED}✗${RESET} %s\n" "$*" >&2; }
ok()    { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }

printf "\n${BOLD}  Dotfiles Migration: bare repo → GNU Stow${RESET}\n\n"

# ── Preflight checks ──────────────────────────────────────────────────────────

# Check that stow is available (install it first if needed)
if ! command -v stow &>/dev/null; then
  error "GNU Stow is not installed."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    printf "  Install it with: brew install stow\n"
  else
    printf "  Install it with: sudo apt-get install stow\n"
  fi
  exit 1
fi

# Refuse to run if ~/.dotfiles/ is already a normal git repo
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  error "$DOTFILES_DIR already contains a normal git repo."
  info  "If you already migrated, run install.sh instead."
  exit 1
fi

# ── Step 1: Back up old bare repo ─────────────────────────────────────────────
if [[ -d "$DOTFILES_DIR" ]]; then
  info "Backing up old bare repo to $BARE_BACKUP …"
  mv "$DOTFILES_DIR" "$BARE_BACKUP"
  ok "Backed up $DOTFILES_DIR → $BARE_BACKUP"
else
  warn "No existing $DOTFILES_DIR found — nothing to back up"
fi

# ── Step 2: Clone as a normal repo ───────────────────────────────────────────
info "Cloning $DOTFILES_REPO → $DOTFILES_DIR …"
git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
ok "Cloned repository"

# Source the UI library now that the repo is available
# shellcheck source=installers/lib/ui.sh
source "$DOTFILES_DIR/installers/lib/ui.sh"

# ── Step 3: stow --adopt ──────────────────────────────────────────────────────
section "Adopt existing files"

info "Running 'stow --adopt' — existing dotfiles will become symlinks pointing"
info "into $DOTFILES_DIR. Any content differences will be reflected in the repo."
echo ""

stow --no-folding --adopt -d "$DOTFILES_DIR" -t "$HOME" "${STOW_PACKAGES[@]}"
ok "Stow adopt complete"

# ── Step 4: git diff — surface any content drift ─────────────────────────────
section "Review"

cd "$DOTFILES_DIR"
if git diff --quiet; then
  ok "No content differences — repo is clean"
else
  warn "The following files differ from the repo (your local changes were adopted):"
  git diff --stat
  echo ""
  info "Review with: git -C ~/.dotfiles diff"
  info "Commit your local changes: git -C ~/.dotfiles commit -am 'chore: adopt local changes'"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
install_summary 0

info "Repo: $DOTFILES_DIR"
info "To restow:  stow --no-folding -d ~/.dotfiles -t \$HOME zsh git fzf oh-my-posh macos"
info "To unstow:  stow -d ~/.dotfiles -t \$HOME -D zsh git fzf oh-my-posh macos"
info "Old bare repo backup: $BARE_BACKUP (delete when satisfied)"
