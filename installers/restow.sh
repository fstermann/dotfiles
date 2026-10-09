#!/usr/bin/env bash
# restow.sh — re-link dotfile packages: pick up newly added files, prune dead
# links, and back up any real (non-symlink) file sitting in the way.
#
# Usage:
#   dotfiles restow                 (via shell function)
#   bash ~/.dotfiles/installers/restow.sh [--dry-run] [--quiet]
#
# Machine-local skips: list one basename regex per line in
#   ~/.dotfiles/.restow-ignore.local
# to leave specific targets alone on THIS machine (e.g. a hand-merged
# ~/.claude/settings.json). Lines starting with # are ignored. The file is
# gitignored, so skips never leak to other machines.
#
# Extra Claude config dirs: each config dir named in CLAUDE_CONFIG_DIR_MAP
# (see README) also gets the claude package linked in. Unset means none.

set -e

DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"
IGNORE_FILE="$DOTFILES_DIR/.restow-ignore.local"

DRY_RUN=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --quiet)   QUIET=1 ;;
  esac
done

# shellcheck source=lib/ui.sh
source "$DOTFILES_DIR/installers/lib/ui.sh"
# shellcheck source=lib/packages.sh
source "$DOTFILES_DIR/installers/lib/packages.sh"

_errors=0

# Build --ignore args from the machine-local ignore file
IGNORE_ARGS=()
if [[ -f "$IGNORE_FILE" ]]; then
  while IFS= read -r pat || [[ -n "$pat" ]]; do
    [[ -z "$pat" || "$pat" == \#* ]] && continue
    IGNORE_ARGS+=("--ignore=$pat")
  done < "$IGNORE_FILE"
fi

[[ $QUIET -eq 0 ]] && printf "\n${BOLD}  Dotfiles Restow${RESET}\n\n"

if (( ${#IGNORE_ARGS[@]} )); then
  section "Ignore"
  info "Skipping (from ${IGNORE_FILE/#$HOME/~}):"
  for a in "${IGNORE_ARGS[@]}"; do info "  ${a#--ignore=}"; done
fi

# ── Back up real files blocking a target ─────────────────────────────────────
section "Backup"

_backup_conflicts() {
  local pkg conflicts f dest
  for pkg in "${STOW_PACKAGES[@]}"; do
    conflicts=$(stow --no-folding --restow --simulate \
      "${IGNORE_ARGS[@]}" -d "$DOTFILES_DIR" -t "$HOME" "$pkg" 2>&1 \
      | grep "existing target is" | awk '{print $NF}') || true
    [[ -z "$conflicts" ]] && continue
    while IFS= read -r f; do
      dest="$BACKUP_DIR/$f"
      mkdir -p "$(dirname "$dest")"
      mv "$HOME/$f" "$dest"
      echo "  backed up: $f"
    done <<< "$conflicts"
  done
}

if (( DRY_RUN )); then
  info "skipped (dry run)"
else
  mkdir -p "$BACKUP_DIR"
  step "Back up conflicting files" _backup_conflicts || (( _errors++ )) || true
fi

# ── Restow ───────────────────────────────────────────────────────────────────
section "Symlink"

_stow_flags=(--no-folding --restow "${IGNORE_ARGS[@]}" -d "$DOTFILES_DIR" -t "$HOME")
if (( DRY_RUN )); then
  step "Simulate restow" \
    stow "${_stow_flags[@]}" --simulate -v "${STOW_PACKAGES[@]}" || (( _errors++ )) || true
else
  step "Restow packages" \
    stow "${_stow_flags[@]}" "${STOW_PACKAGES[@]}" || (( _errors++ )) || true
fi

# Opt-in extra Claude config dirs, from CLAUDE_CONFIG_DIR_MAP in ~/.zshrc.local
_alt_dirs=()
while IFS= read -r _alt_dir; do
  [[ -n "$_alt_dir" ]] && _alt_dirs+=("$_alt_dir")
done < <(tr : '\n' <<< "${CLAUDE_CONFIG_DIR_MAP:-}" | sed -n 's/^[^=]*=//p' | sort -u)

for _alt_dir in "${_alt_dirs[@]}"; do
  _alt_flags=(--no-folding --restow "${IGNORE_ARGS[@]}" -d "$DOTFILES_DIR/claude" -t "$_alt_dir")
  if (( DRY_RUN )) && [[ ! -d "$_alt_dir" ]]; then
    info "Would create ${_alt_dir/#$HOME/~} and link claude into it"
  elif (( DRY_RUN )); then
    step "Simulate restow claude into ${_alt_dir/#$HOME/~}" \
      stow "${_alt_flags[@]}" --simulate -v .claude || (( _errors++ )) || true
  else
    mkdir -p "$_alt_dir"
    step "Restow claude into ${_alt_dir/#$HOME/~}" \
      stow "${_alt_flags[@]}" .claude || (( _errors++ )) || true
  fi
done

[[ $QUIET -eq 0 ]] && install_summary "$_errors"

exit $(( _errors > 0 ? 1 : 0 ))
