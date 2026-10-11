#!/usr/bin/env bash
# PreToolUse (Bash) hook: block review-pr comment posts that break house prose style.
# The sniff executable comes from the standalone sniff@sniff Claude plugin.
# Fail open if the plugin, its dependencies, or a comment body is unavailable.
set -uo pipefail

export PATH="$HOME/.local/bin:/usr/bin:/bin:$PATH"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Only guard the review-pr scripts that publish prose to a PR.
case "$cmd" in
  *edit-comment.sh*|*post-comment.sh*|*create-pending-review.sh*) ;;
  *) exit 0 ;;
esac

plugin_root=$(claude plugin list --json 2>/dev/null \
  | jq -r '[.[] | select(.id == "sniff@sniff" and .enabled == true)] | last | .installPath // empty' \
    2>/dev/null)
SNIFF="$plugin_root/sniff"
[ -n "$plugin_root" ] && [ -x "$SNIFF" ] || exit 0

# Pull prose from heredoc bodies and single-quoted assignments. Feeding raw shell
# to Vale is unreliable, so scan clean Markdown only.
body=$(SNIFF_CMD="$cmd" python3 -c '
import os
import re
import sys

text = os.environ.get("SNIFF_CMD", "")
chunks = []
lines = text.split("\n")
heredoc = re.compile(r"<<-?\s*([\x27\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
i = 0
while i < len(lines):
    match = heredoc.search(lines[i])
    if match:
        marker = match.group(2)
        i += 1
        buffer = []
        while i < len(lines) and lines[i].strip() != marker:
            buffer.append(lines[i])
            i += 1
        chunks.append("\n".join(buffer))
    i += 1
for match in re.finditer(r"=\x27([^\x27]*)\x27", text, re.S):
    chunks.append(match.group(1))
sys.stdout.write("\n\n".join(chunk for chunk in chunks if chunk.strip()))
' 2>/dev/null)
[ -z "${body// }" ] && exit 0

findings=$(printf '%s' "$body" \
  | "$SNIFF" check - --profile document --format jsonl 2>/dev/null \
  | grep -E '"code": "LEX01[45]"' || true)

[ -z "$findings" ] && exit 0

{
  echo "BLOCKED: house-style prose violation in the comment body (sniff)."
  printf '%s\n' "$findings" | jq -r '"  - \"\(.span)\": \(.message)"'
  echo "Rewrite the body to remove these, then re-run the command."
} >&2
exit 2
