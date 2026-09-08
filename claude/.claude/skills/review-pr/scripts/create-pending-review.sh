#!/usr/bin/env bash
# Create a PENDING review from a JSON array of comments on stdin.
# Each element: {path, line, body}; optional side (default RIGHT) and start_line.
# No event is sent, so the review stays pending until I submit it myself.
# Usage: echo '[{"path":"a.ts","line":10,"body":"..."}]' | create-pending-review.sh OWNER REPO NUM
# Prints the pending review's id. Fails if I already have a pending review on the PR.
set -euo pipefail
O=$1 R=$2 N=$3
jq '{comments: .}' \
  | gh api --method POST "repos/$O/$R/pulls/$N/reviews" --input - --jq '.id'
