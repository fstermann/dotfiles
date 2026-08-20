#!/usr/bin/env bash
# Stop hook: once per session, past a turn threshold, block the stop and ask for a
# self-improvement review. Silent otherwise.
set -euo pipefail

THRESHOLD="${SELF_IMPROVE_THRESHOLD:-20}"
STATE_DIR="$HOME/.claude/.self-improve"

input=$(cat)
mkdir -p "$STATE_DIR"

# Old sessions never come back; keep the dir from growing forever.
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null || true

read -r session_id stop_active <<<"$(printf '%s' "$input" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("session_id", ""), str(d.get("stop_hook_active", False)).lower())
')"

# Re-entrant call from our own block, or malformed input: never loop.
[ "$stop_active" = "true" ] && exit 0
[ -n "$session_id" ] || exit 0

fired="$STATE_DIR/$session_id.fired"
[ -f "$fired" ] && exit 0

counter="$STATE_DIR/$session_id.count"
count=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$count" >"$counter"
[ "$count" -lt "$THRESHOLD" ] && exit 0

touch "$fired"
cat <<'JSON'
{
  "decision": "block",
  "reason": "Self-improvement checkpoint — reviewing this session for config-worthy learnings.",
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "This session passed the self-improvement turn threshold (fires at most once per session). Use the self-improve skill in session mode now: review THIS conversation for durable learnings worth writing into CLAUDE.md, a skill, a hook, settings, or memory. If nothing durable came up, say exactly that in one line and stop — do not manufacture findings. Never apply an edit without the user approving it first."
  }
}
JSON
