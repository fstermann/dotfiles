#!/usr/bin/env bash

set -e

# ── Parse flags ───────────────────────────────────────────────────────────────
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
  esac
done

DOTFILES_REPO="https://github.com/fstermann/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

# Stow packages (one per tool — each mirrors $HOME structure)
STOW_PACKAGES=(zsh git fzf oh-my-posh macos claude)

# ── Load UI library ──────────────────────────────────────────────────────────
# On a fresh install the repo hasn't been cloned yet, so fetch ui.sh directly
# from GitHub; re-source the local copy after cloning.
_UI_LIB="$DOTFILES_DIR/installers/lib/ui.sh"
_UI_URL="https://raw.githubusercontent.com/fstermann/dotfiles/main/installers/lib/ui.sh"

if [[ -f "$_UI_LIB" ]]; then
  # shellcheck source=installers/lib/ui.sh
  source "$_UI_LIB"
else
  _ui_tmp=$(mktemp)
  curl -fsSL "$_UI_URL" -o "$_ui_tmp"
  source "$_ui_tmp"
  rm -f "$_ui_tmp"
fi
unset _UI_LIB _UI_URL _ui_tmp
# ─────────────────────────────────────────────────────────────────────────────

_errors=0

# In dry-run mode, print what would happen instead of executing
_dry_step() {
  local label="$1"
  printf "  ${CYAN}○${RESET}  %s ${DIM}(skipped)${RESET}\n" "$label"
}

# ── Banner ────────────────────────────────────────────────────────────────────
if [[ $DRY_RUN -eq 1 ]]; then
  printf "\n${BOLD}  Dotfiles Installer ${YELLOW}[DRY RUN]${RESET}\n"
else
  printf "\n${BOLD}  Dotfiles Installer${RESET}\n"
fi
printf "  ${DIM}%s${RESET}\n" "$DOTFILES_REPO"

# ── Clone ─────────────────────────────────────────────────────────────────────
section "Clone"

if [[ -d "$DOTFILES_DIR/.git" ]]; then
  info "$DOTFILES_DIR already exists — skipping clone"
else
  if [[ $DRY_RUN -eq 1 ]]; then
    _dry_step "Clone dotfiles repository"
  else
    step "Clone dotfiles repository" \
      git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || (( _errors++ ))
  fi
fi

# Re-source the local copy now that the repo is cloned
# shellcheck source=installers/lib/ui.sh
[[ -f "$DOTFILES_DIR/installers/lib/ui.sh" ]] && source "$DOTFILES_DIR/installers/lib/ui.sh"

# ── Install GNU Stow ──────────────────────────────────────────────────────────
section "Stow"

if command -v stow &>/dev/null; then
  info "GNU Stow is already installed"
else
  if [[ $DRY_RUN -eq 1 ]]; then
    _dry_step "Install GNU Stow"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    step "Install GNU Stow" brew install stow || (( _errors++ ))
  else
    step "Install GNU Stow" sudo apt-get install -y stow || (( _errors++ ))
  fi
fi

# ── Backup conflicting files ──────────────────────────────────────────────────
section "Backup"

if [[ $DRY_RUN -eq 1 ]]; then
  # In dry-run mode, just report what stow would conflict with
  _dry_report_conflicts() {
    if ! command -v stow &>/dev/null; then
      echo "  (stow not installed — cannot check conflicts)"
      return 0
    fi
    local pkg
    for pkg in "${STOW_PACKAGES[@]}"; do
      local conflicts
      conflicts=$(stow --no-folding --simulate -d "$DOTFILES_DIR" -t "$HOME" "$pkg" 2>&1 \
        | grep "existing target is" | awk '{print $NF}') || true
      if [[ -n "$conflicts" ]]; then
        while IFS= read -r f; do
          echo "  would back up: $f"
        done <<< "$conflicts"
      fi
    done
  }
  step "Check for conflicting files" _dry_report_conflicts || (( _errors++ ))
else
  mkdir -p "$BACKUP_DIR"

  _backup_conflicts() {
    local pkg
    for pkg in "${STOW_PACKAGES[@]}"; do
      # Dry-run stow to find conflicts
      local conflicts
      conflicts=$(stow --no-folding --simulate -d "$DOTFILES_DIR" -t "$HOME" "$pkg" 2>&1 \
        | grep "existing target is" | awk '{print $NF}') || true
      if [[ -n "$conflicts" ]]; then
        while IFS= read -r f; do
          local dest="$BACKUP_DIR/$f"
          mkdir -p "$(dirname "$dest")"
          mv "$HOME/$f" "$dest"
          echo "  backed up: $f"
        done <<< "$conflicts"
      fi
    done
  }

  step "Back up conflicting files" _backup_conflicts || (( _errors++ ))
fi

# ── Stow packages ─────────────────────────────────────────────────────────────
section "Symlink"

if [[ $DRY_RUN -eq 1 ]]; then
  step "Simulate stow" \
    stow --no-folding --simulate -v -d "$DOTFILES_DIR" -t "$HOME" "${STOW_PACKAGES[@]}" || (( _errors++ ))
else
  step "Stow dotfile packages" \
    stow --no-folding -d "$DOTFILES_DIR" -t "$HOME" "${STOW_PACKAGES[@]}" || (( _errors++ ))
fi

# ── Platform packages ─────────────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
  section "macOS Packages"
  # shellcheck source=installers/brew.install
  if command -v brew &>/dev/null; then
    info "Homebrew is already installed, skipping"
  elif [[ $DRY_RUN -eq 1 ]]; then
    _dry_step "Install Homebrew"
  else
    source "$DOTFILES_DIR/installers/brew.install" || (( _errors++ ))
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    _dry_step "Configure macOS settings"
    _dry_step "Configure macOS terminal settings"
  else
    # shellcheck source=installers/macos.install
    step "Configure macOS settings" \
      source "$DOTFILES_DIR/installers/macos.install" || (( _errors++ ))
    # shellcheck source=installers/terminal.install
    step "Configure macOS terminal settings" \
      source "$DOTFILES_DIR/installers/terminal.install" || (( _errors++ ))
  fi
fi

# ── Shell ─────────────────────────────────────────────────────────────────────
section "Shell"
if [[ $DRY_RUN -eq 1 ]]; then
  _dry_step "Install zsh and plugins"
  _dry_step "Install fzf"
else
  # shellcheck source=installers/zsh.install
  step "Install zsh and plugins" \
    source "$DOTFILES_DIR/installers/zsh.install" || (( _errors++ ))
  # shellcheck source=installers/fzf.install
  step "Install fzf" \
    source "$DOTFILES_DIR/installers/fzf.install" || (( _errors++ ))
fi

# ── Local config stubs ────────────────────────────────────────────────────────
section "Local configs"
if [[ $DRY_RUN -eq 1 ]]; then
  _dry_step "Create .local config stubs"
else
  # shellcheck source=installers/local.install
  step "Create .local config stubs" \
    source "$DOTFILES_DIR/installers/local.install" || (( _errors++ ))
fi

# ── Summary ───────────────────────────────────────────────────────────────────
install_summary "$_errors"

info "Dotfiles are managed with GNU Stow. Repo is at $DOTFILES_DIR"
info "To restow: stow --no-folding -d ~/.dotfiles -t \$HOME zsh git fzf oh-my-posh macos"
