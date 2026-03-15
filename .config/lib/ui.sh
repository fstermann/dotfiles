#!/usr/bin/env bash
# ui.sh — terminal UI helpers for dotfiles install scripts
# Source this file; do not execute it directly.
#
# Usage in sub-scripts:
#   [[ $(type -t step) == function ]] || source ~/.config/lib/ui.sh

# ── ANSI styles ─────────────────────────────────────────────────────────────
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
CYAN=$'\033[36m'

# ── Log file ─────────────────────────────────────────────────────────────────
: "${INSTALL_LOG:=$(mktemp /tmp/dotfiles-install-XXXXXX)}"
export INSTALL_LOG

# ── Helpers ──────────────────────────────────────────────────────────────────

# Print a styled section header
#   section "Installing zsh"
section() {
  local label="$1"
  local width=60
  local pad=$(( (width - ${#label} - 2) / 2 ))
  local line
  printf -v line '%*s' "$pad" ''; line="${line// /─}"
  printf "\n${BOLD}${CYAN}%s ${label} %s${RESET}\n" "$line" "$line"
}

# Print a single-line info/warn/error message
info()  { printf "  ${CYAN}·${RESET} %s\n" "$*"; }
warn()  { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
error() { printf "  ${RED}✗${RESET} %s\n" "$*" >&2; }

# Run a command with a live scrolling output box at fixed height.
#   step "Install Homebrew" brew install homebrew
#   VERBOSE=1 step "..." cmd  — always show output after success too
step() {
  local label="$1"; shift
  local BOX_H=5
  local tmpout; tmpout=$(mktemp)
  local stop_flag; stop_flag=$(mktemp)
  local TOTAL=$(( BOX_H + 3 ))  # spinner + top border + BOX_H lines + bottom border

  # Responsive width capped at 120, minimum 60
  local cols; cols=$(tput cols 2>/dev/null || echo 80)
  [[ $cols -gt 120 ]] && cols=120
  [[ $cols -lt 60  ]] && cols=60
  local BOX_W=$(( cols - 10 ))
  local sep; sep=$(printf '%*s' $(( BOX_W - 8 )) '' | tr ' ' '─')
  local bot; bot=$(printf '%*s' $(( BOX_W + 1 )) '' | tr ' ' '─')

  local spinner_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

  # Print initial empty box to reserve the screen space for redraws
  printf "  ${CYAN}⠋${RESET}  %s\n" "$label"
  printf "    ${DIM}┌─ output %s${RESET}\n" "$sep"
  for (( _i=0; _i<BOX_H; _i++ )); do
    printf "    ${DIM}│${RESET}\n"
  done
  printf "    ${DIM}└%s${RESET}\n" "$bot"

  # Background: redraw with latest tail of output until stop flag is set
  (
    local frame=0 _i _line
    while [[ ! -s "$stop_flag" ]]; do
      printf "\033[%dA\r" "$TOTAL"
      printf "  ${CYAN}%s${RESET}  %s\033[K\n" "${spinner_frames[$((frame % 10))]}" "$label"
      printf "    ${DIM}┌─ output %s${RESET}\n" "$sep"
      _i=0
      while IFS= read -r _line && [[ $_i -lt $BOX_H ]]; do
        # Strip ANSI codes and carriage returns, truncate to box width
        _line=$(printf '%s' "$_line" | tr -d '\r' | sed $'s/\033\\[[0-9;:]*[a-zA-Z]//g' | cut -c1-$BOX_W)
        printf "    ${DIM}│${RESET} %-*s\033[K\n" "$BOX_W" "$_line"
        _i=$(( _i + 1 ))
      done < <(tail -n "$BOX_H" "$tmpout" 2>/dev/null)
      while [[ $_i -lt $BOX_H ]]; do
        printf "    ${DIM}│${RESET}\033[K\n"
        _i=$(( _i + 1 ))
      done
      printf "    ${DIM}└%s${RESET}\n" "$bot"
      frame=$(( frame + 1 ))
      sleep 0.12
    done
  ) &
  local spin_pid=$!

  # Run command, capture output — || to stay safe under set -e
  local exit_code=0
  "$@" >"$tmpout" 2>&1 || exit_code=$?

  # Signal spinner to stop cleanly (between iterations) then wait for it
  printf 'done' > "$stop_flag"
  wait "$spin_pid" 2>/dev/null || true
  rm -f "$stop_flag"

  # Append full output to install log
  { echo "── step: $label ──"; cat "$tmpout"; echo ""; } >> "$INSTALL_LOG"

  # Erase the live block entirely
  printf "\033[%dA\r" "$TOTAL"
  for (( _i=0; _i<TOTAL; _i++ )); do
    printf "\033[2K\n"
  done
  printf "\033[%dA\r" "$TOTAL"

  if [[ $exit_code -eq 0 ]]; then
    printf "  ${GREEN}✓${RESET}  %s\n" "$label"
    [[ "${VERBOSE:-}" == "1" ]] && _print_output_box "$tmpout" "$label"
  else
    printf "  ${RED}✗${RESET}  %s\n" "$label"
    _print_output_box "$tmpout" "$label"
  fi

  rm -f "$tmpout"
  return "$exit_code"
}

# Print a bordered output box from a file
#   _print_output_box /tmp/out.txt "label"
_print_output_box() {
  local file="$1"
  local label="${2:-Output}"
  local width=60
  local pad
  printf -v pad '%*s' $(( width - ${#label} - 5 )) ''; pad="${pad// /─}"
  printf "    ${DIM}┌─ %s %s${RESET}\n" "$label" "$pad"
  while IFS= read -r line; do
    printf "    ${DIM}│${RESET} %s\n" "$line"
  done < "$file"
  printf "    ${DIM}└%s${RESET}\n" "$(printf '%*s' $((width - 1)) '' | tr ' ' '─')"
}

# Print a summary at the end of install.sh
install_summary() {
  local had_errors="${1:-0}"
  echo ""
  if [[ "$had_errors" -eq 0 ]]; then
    printf "  ${GREEN}${BOLD}✓ Done!${RESET} Dotfiles installed successfully.\n"
  else
    printf "  ${RED}${BOLD}✗ Finished with errors.${RESET}\n"
  fi
  printf "  ${DIM}Full log: %s${RESET}\n\n" "$INSTALL_LOG"
}
