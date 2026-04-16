#!/bin/zsh
if command -v oh-my-posh &>/dev/null; then
    oh-my-posh claude --config ~/.config/zsh/oh-my-posh/pure.claude.toml
else
    input=$(cat)

    MODEL=$(echo "$input" | jq -r '.model.display_name')
    DIR=$(echo "$input" | jq -r '.workspace.current_dir')
    COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
    PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
    DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

    CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; ORANGE='\033[34m'; GRAY='\033[90m'; RESET='\033[0m'

    # Pick color based on context usage
    if [ "$PCT" -ge 90 ]; then PCT_COLOR="$RED"
    elif [ "$PCT" -ge 70 ]; then PCT_COLOR="$YELLOW"
    else PCT_COLOR="$GREEN"; fi

    MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

    COST_FMT=$(printf '$%.2f' "$COST")

    echo -e "${GRAY}[$MODEL]${RESET} ${ORANGE}${DIR##*/}${RESET} ${PCT_COLOR}${PCT}%${RESET} ${RED}${COST_FMT}${RESET} ${YELLOW}${MINS}m ${SECS}s${RESET}"
fi
