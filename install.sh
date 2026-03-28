#!/usr/bin/env bash

set -e

# ── Parse flags ───────────────────────────────────────────────────────────────
_CLI_PROFILE=""
for arg in "$@"; do
  case "$arg" in
    --profile=*) _CLI_PROFILE="${arg#--profile=}" ;;
  esac
done

DOTFILES_REPO="https://github.com/fstermann/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"
PROFILE_FILE="$HOME/.dotfiles-profile"

# Default stow packages (overridden by profile)
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

# ── Banner ────────────────────────────────────────────────────────────────────
printf "\n${BOLD}  Dotfiles Installer${RESET}\n"
printf "  ${DIM}%s${RESET}\n" "$DOTFILES_REPO"

# ── Clone ─────────────────────────────────────────────────────────────────────
section "Clone"

if [[ -d "$DOTFILES_DIR/.git" ]]; then
  info "$DOTFILES_DIR already exists — skipping clone"
else
  step "Clone dotfiles repository" \
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || (( _errors++ ))
fi

# Re-source the local copy now that the repo is cloned
# shellcheck source=installers/lib/ui.sh
source "$DOTFILES_DIR/installers/lib/ui.sh"

# ── Profile selection ───────────────────────────────────────────────────────
section "Profile"

_PROFILES_DIR="$DOTFILES_DIR/installers/profiles"
_selected_profile=""

# Priority: CLI flag > env var > saved file > interactive prompt
if [[ -n "$_CLI_PROFILE" ]]; then
  _selected_profile="$_CLI_PROFILE"
elif [[ -n "${DOTFILES_PROFILE:-}" ]]; then
  _selected_profile="$DOTFILES_PROFILE"
elif [[ -f "$PROFILE_FILE" ]]; then
  _selected_profile=$(cat "$PROFILE_FILE")
fi

# If no profile selected yet, prompt interactively
if [[ -z "$_selected_profile" ]] && [[ -d "$_PROFILES_DIR" ]]; then
  _available=()
  for f in "$_PROFILES_DIR"/*.sh; do
    [[ "$(basename "$f")" == "base.sh" ]] && continue
    _name=$(basename "$f" .sh)
    # shellcheck disable=SC1090
    ( source "$f"; printf "  ${CYAN}%s${RESET} — %s\n" "$_name" "$PROFILE_DESCRIPTION" )
    _available+=("$_name")
  done

  if [[ ${#_available[@]} -gt 0 ]]; then
    echo ""
    read -rp "  Select a profile [${_available[*]}]: " _selected_profile
    # Default to base if empty or invalid
    if [[ -z "$_selected_profile" ]]; then
      _selected_profile="base"
    fi
  fi
fi

# Fall back to base
: "${_selected_profile:=base}"

_profile_path="$_PROFILES_DIR/${_selected_profile}.sh"
if [[ -f "$_profile_path" ]]; then
  # shellcheck disable=SC1090
  source "$_profile_path"
  STOW_PACKAGES=("${PROFILE_STOW_PACKAGES[@]}")
  info "Profile: $_selected_profile — $PROFILE_DESCRIPTION"
else
  warn "Profile '$_selected_profile' not found, using defaults"
fi

# Save the selection for next time
printf '%s' "$_selected_profile" > "$PROFILE_FILE"

# ── Install GNU Stow ──────────────────────────────────────────────────────────
section "Stow"

if command -v stow &>/dev/null; then
  info "GNU Stow is already installed"
else
  if [[ "$OSTYPE" == "darwin"* ]]; then
    step "Install GNU Stow" brew install stow || (( _errors++ ))
  else
    step "Install GNU Stow" sudo apt-get install -y stow || (( _errors++ ))
  fi
fi

# ── Backup conflicting files ──────────────────────────────────────────────────
section "Backup"

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

# ── Stow packages ─────────────────────────────────────────────────────────────
section "Symlink"

step "Stow dotfile packages" \
  stow --no-folding -d "$DOTFILES_DIR" -t "$HOME" "${STOW_PACKAGES[@]}" || (( _errors++ ))

# ── Platform packages ─────────────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
  section "macOS Packages"
  # shellcheck source=installers/brew.install
  if command -v brew &>/dev/null; then
    info "Homebrew is already installed, skipping"
  else
    source "$DOTFILES_DIR/installers/brew.install" || (( _errors++ ))
  fi
  # shellcheck source=installers/macos.install
  step "Configure macOS settings" \
    source "$DOTFILES_DIR/installers/macos.install" || (( _errors++ ))
  # shellcheck source=installers/terminal.install
  step "Configure macOS terminal settings" \
    source "$DOTFILES_DIR/installers/terminal.install" || (( _errors++ ))

  # Install profile-specific brew packages
  for _brew_file in "${PROFILE_BREW_FILES[@]}"; do
    _brew_path="$DOTFILES_DIR/installers/$_brew_file"
    if [[ -f "$_brew_path" ]]; then
      step "Install $_brew_file packages" \
        source "$_brew_path" || (( _errors++ ))
    else
      warn "Brew file not found: $_brew_file"
    fi
  done
fi

# ── Shell ─────────────────────────────────────────────────────────────────────
section "Shell"
# shellcheck source=installers/zsh.install
step "Install zsh and plugins" \
  source "$DOTFILES_DIR/installers/zsh.install" || (( _errors++ ))
# shellcheck source=installers/fzf.install
step "Install fzf" \
  source "$DOTFILES_DIR/installers/fzf.install" || (( _errors++ ))

# ── Local config stubs ────────────────────────────────────────────────────────
section "Local configs"
# shellcheck source=installers/local.install
step "Create .local config stubs" \
  source "$DOTFILES_DIR/installers/local.install" || (( _errors++ ))

# ── Summary ───────────────────────────────────────────────────────────────────
install_summary "$_errors"

info "Dotfiles are managed with GNU Stow. Repo is at $DOTFILES_DIR"
info "To restow: stow --no-folding -d ~/.dotfiles -t \$HOME zsh git fzf oh-my-posh macos"
