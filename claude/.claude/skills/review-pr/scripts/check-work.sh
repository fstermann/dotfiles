#!/usr/bin/env bash
# Deterministic gate for the auto-watch loop: is there review work to do right now?
# Reuses fetch-comments.sh / fetch-reviewer-comments.sh and keeps only actionable
# rows, no judgment. Prints the actionable set as JSON.
# Exit 0 = work found, 1 = nothing to do, 3 = PR closed/merged (stop watching).
# Usage: check-work.sh OWNER REPO NUM ME FLOW   (FLOW: own|reviewing)
set -uo pipefail
O=$1 R=$2 N=$3 ME=$4 FLOW=$5
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Stop the moment the PR leaves active review. A transient API failure must not
# read as "closed" (that would kill the watch), so on error report no work and let
# the loop poll again.
if state=$(gh api "repos/$O/$R/pulls/$N" --jq '.state + " " + (.merged|tostring)' 2>/dev/null); then
  [ "$state" = "open false" ] || exit 3
else
  exit 1
fi

if [ "$FLOW" = "reviewing" ]; then
  # A pending comment I tagged needs work when it awaits an answer, is a /reply
  # not yet collapsed, or has a separate follow-up reply to fold in.
  work=$("$S/fetch-comments.sh" "$O" "$R" "$N" "$ME" | jq '
    { flow:"reviewing",
      items:[ .[]
        | select(.source=="pending")
        | select(
            (.reply_to != null)
            or (.directive=="reply")
            or (.directive=="ask"
                and ((.body|sub("\\s+$";""))|endswith("<!-- claude:end -->")|not))
          ) ] }')
else
  reviewer=$("$S/fetch-reviewer-comments.sh" "$O" "$R" "$N" "$ME" | jq '[ .[] | select(.directive != null) ]')
  mine=$("$S/fetch-comments.sh" "$O" "$R" "$N" "$ME" | jq '[ .[] | select(.source!="pending") ]')
  work=$(jq -n --argjson r "$reviewer" --argjson m "$mine" '{flow:"own", reviewer:$r, mine:$m}')
fi

echo "$work"
count=$(echo "$work" | jq 'if .items then (.items|length) else ((.reviewer|length)+(.mine|length)) end')
[ "$count" -gt 0 ] && exit 0 || exit 1
