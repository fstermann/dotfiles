#!/usr/bin/env bash
# Resolve a PR ref (number, URL, or empty=current branch) to its coordinates.
# Read-only. Prints JSON: {owner,repo,num,me,url,headRef,currentBranch,dirty}
set -euo pipefail
REF="${1:-}"

info=$(gh pr view ${REF:+"$REF"} --json url,headRefName)
URL=$(echo "$info" | jq -r .url)
HEAD=$(echo "$info" | jq -r .headRefName)
read -r O R N <<<"$(echo "$URL" | sed -E 's#.*github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\1 \2 \3#')"
ME=$(gh api user -q .login)
BR=$(git branch --show-current 2>/dev/null || true)
DIRTY=false; [ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=true

jq -n --arg o "$O" --arg r "$R" --arg n "$N" --arg me "$ME" --arg url "$URL" \
      --arg head "$HEAD" --arg br "${BR:-}" --argjson dirty "$DIRTY" \
  '{owner:$o, repo:$r, num:($n|tonumber), me:$me, url:$url,
    headRef:$head, currentBranch:$br, dirty:$dirty}'
