#!/usr/bin/env bash
# Resolve a PR ref (number, URL, or empty=current branch) to its coordinates.
# Read-only. Prints JSON: {owner,repo,num,me,author,flow,url,headRef,currentBranch,dirty}
#   author: the PR author's login. flow: "own" if author==me else "reviewing".
# Usage: resolve-ref.sh [REF] [--repo owner/name]
#   --repo lets a multi-repo workspace resolve a PR when cwd isn't the target repo
#   (pass a PR number/URL too; current-branch detection still needs the checkout).
set -euo pipefail
REF=""; REPO=""
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="${2:-}"; shift 2 ;;
  *) REF="$1"; shift ;;
esac; done

if [ -n "$REPO" ]; then
  info=$(gh pr view ${REF:+"$REF"} --repo "$REPO" --json url,headRefName,author)
else
  info=$(gh pr view ${REF:+"$REF"} --json url,headRefName,author)
fi
URL=$(echo "$info" | jq -r .url)
HEAD=$(echo "$info" | jq -r .headRefName)
AUTHOR=$(echo "$info" | jq -r .author.login)
read -r O R N <<<"$(echo "$URL" | sed -E 's#^https?://[^/]+/([^/]+)/([^/]+)/pull/([0-9]+).*#\1 \2 \3#')"
ME=$(gh api user -q .login)
FLOW=reviewing; [ "$AUTHOR" = "$ME" ] && FLOW=own
BR=$(git branch --show-current 2>/dev/null || true)
DIRTY=false; [ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=true

jq -n --arg o "$O" --arg r "$R" --arg n "$N" --arg me "$ME" --arg author "$AUTHOR" \
      --arg flow "$FLOW" --arg url "$URL" \
      --arg head "$HEAD" --arg br "${BR:-}" --argjson dirty "$DIRTY" \
  '{owner:$o, repo:$r, num:($n|tonumber), me:$me, author:$author, flow:$flow, url:$url,
    headRef:$head, currentBranch:$br, dirty:$dirty}'
