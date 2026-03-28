#!/usr/bin/env bash
# doctor.sh — verify dotfiles installation health
#
# Usage:
#   dotfiles doctor          (via shell function)
#   bash ~/.dotfiles/installers/doctor.sh

set -e

DOTFILES_DIR="$HOME/.dotfiles"
STOW_PACKAGES=(zsh git fzf oh-my-posh macos claude)

# shellcheck source=lib/ui.sh
source "$DOTFILES_DIR/installers/lib/ui.sh"

_pass=0
_warn=0
_fail=0

_check_pass() { printf "  ${GREEN}✓${RESET}  %s\n" "$*"; (( _pass++ )) || true; }
_check_warn() { printf "  ${YELLOW}⚠${RESET}  %s\n" "$*"; (( _warn++ )) || true; }
_check_fail() { printf "  ${RED}✗${RESET}  %s\n" "$*"; (( _fail++ )) || true; }

printf "\n${BOLD}  Dotfiles Doctor${RESET}\n"

# ── Symlinks ─────────────────────────────────────────────────────────────────
section "Symlinks"

_check_symlink() {
  local target="$1"
  if [[ -L "$target" ]]; then
    local actual resolved
    actual=$(readlink "$target")
    # Resolve relative symlinks to absolute paths portably (macOS + Linux)
    resolved=$(cd "$(dirname "$target")" && cd "$(dirname "$actual")" && echo "$PWD/$(basename "$actual")")
    if [[ "$resolved" == "$DOTFILES_DIR/"* ]]; then
      _check_pass "$target → $actual"
    else
      _check_warn "$target is a symlink but points to $actual (expected $DOTFILES_DIR/...)"
    fi
  elif [[ -e "$target" ]]; then
    _check_fail "$target exists but is not a symlink"
  else
    _check_fail "$target does not exist"
  fi
}

_check_symlink "$HOME/.zshrc"
_check_symlink "$HOME/.zprofile"
_check_symlink "$HOME/.gitconfig"
_check_symlink "$HOME/.config/fzf/fzf.zsh"
_check_symlink "$HOME/.config/zsh/oh-my-posh/oh-my-posh.zsh"
if [[ "$OSTYPE" == "darwin"* ]]; then
  _check_symlink "$HOME/.config/macos/Monokai Pro (Filter Octagon).terminal"
fi
_check_symlink "$HOME/.claude/settings.json"

# ── Tools on PATH ────────────────────────────────────────────────────────────
section "Tools"

_check_command() {
  local cmd="$1"
  local label="${2:-$cmd}"
  if command -v "$cmd" &>/dev/null; then
    local version
    version=$("$cmd" --version 2>/dev/null | head -1) || version="(version unknown)"
    _check_pass "$label: $version"
  else
    _check_fail "$label: not found on PATH"
  fi
}

_check_command git
_check_command stow "GNU Stow"
_check_command zsh
_check_command fzf
# On Ubuntu/Debian the binary is 'batcat' due to a naming conflict
if command -v bat &>/dev/null; then
  _check_command bat
elif command -v batcat &>/dev/null; then
  _check_command batcat "bat (batcat)"
else
  _check_fail "bat: not found on PATH"
fi
_bat_checked=1  # skip the generic check below
_check_command rg "ripgrep"

if [[ "$OSTYPE" == "darwin"* ]]; then
  _check_command brew "Homebrew"
fi

# oh-my-posh is optional (fallback prompt exists)
if command -v oh-my-posh &>/dev/null; then
  _check_pass "oh-my-posh: $(oh-my-posh version 2>/dev/null || echo 'installed')"
else
  _check_warn "oh-my-posh: not installed (fallback prompt will be used)"
fi

# ── Config files ─────────────────────────────────────────────────────────────
section "Config files"

_check_file() {
  local file="$1"
  if [[ -e "$file" ]]; then
    _check_pass "$file"
  else
    _check_fail "$file does not exist"
  fi
}

_check_file "$HOME/.zshrc"
_check_file "$HOME/.zprofile"
_check_file "$HOME/.config/fzf/fzf.zsh"
_check_file "$HOME/.config/zsh/oh-my-posh/oh-my-posh.zsh"

# ── Local stubs ──────────────────────────────────────────────────────────────
section "Local config"

if [[ -f "$HOME/.gitconfig.local" ]]; then
  _check_pass ".gitconfig.local"
else
  _check_warn ".gitconfig.local not found (run: dotfiles install)"
fi

if [[ -f "$HOME/.zshrc.local" ]]; then
  _check_pass ".zshrc.local"
else
  _check_warn ".zshrc.local not found (run: dotfiles install)"
fi

# ── Git identity ─────────────────────────────────────────────────────────────
section "Git identity"

_git_name=$(git config --global user.name 2>/dev/null || true)
_git_email=$(git config --global user.email 2>/dev/null || true)

if [[ -n "$_git_name" ]]; then
  _check_pass "user.name: $_git_name"
else
  _check_warn "user.name is not set (edit ~/.gitconfig.local)"
fi

if [[ -n "$_git_email" ]]; then
  _check_pass "user.email: $_git_email"
else
  _check_warn "user.email is not set (edit ~/.gitconfig.local)"
fi

# ── Shell ────────────────────────────────────────────────────────────────────
section "Shell"

_current_shell=$(basename "$SHELL" 2>/dev/null || echo "unknown")
if [[ "$_current_shell" == "zsh" ]]; then
  _check_pass "Default shell: zsh"
else
  _check_warn "Default shell is $_current_shell (expected zsh)"
fi

# ── Font ─────────────────────────────────────────────────────────────────────
section "Font"

if [[ "$OSTYPE" == "darwin"* ]]; then
  if ls ~/Library/Fonts/Meslo*.ttf &>/dev/null || ls /Library/Fonts/Meslo*.ttf &>/dev/null; then
    _check_pass "Meslo Nerd Font installed"
  else
    _check_warn "Meslo Nerd Font not found (run: oh-my-posh font install meslo)"
  fi
else
  if fc-list 2>/dev/null | grep -qi meslo; then
    _check_pass "Meslo Nerd Font installed"
  else
    _check_warn "Meslo Nerd Font not found (run: oh-my-posh font install meslo)"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
printf "  ${BOLD}Results:${RESET} "
printf "${GREEN}%d passed${RESET}  " "$_pass"
[[ $_warn -gt 0 ]] && printf "${YELLOW}%d warnings${RESET}  " "$_warn"
[[ $_fail -gt 0 ]] && printf "${RED}%d failed${RESET}  " "$_fail"
echo ""
echo ""

[[ $_fail -eq 0 ]]
