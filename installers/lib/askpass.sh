#!/usr/bin/env bash
# askpass.sh — SUDO_ASKPASS helper that pauses the step spinner and prompts on the terminal.
# sudo passes its prompt as $1 and reads the password from stdout.

[[ -n "${STEP_PAUSE_FLAG:-}" ]] && printf 'paused' > "$STEP_PAUSE_FLAG" && sleep 0.3

printf '\n  \033[33m!\033[0m %s ' "${1:-Password:}" > /dev/tty
IFS= read -rs password < /dev/tty
printf '\n' > /dev/tty

[[ -n "${STEP_PAUSE_FLAG:-}" ]] && : > "$STEP_PAUSE_FLAG"
printf '%s\n' "$password"
