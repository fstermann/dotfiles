#!/usr/bin/env bash
# Poll loop for the auto-watch flow. Every INTERVAL seconds run the deterministic
# gate (check-work.sh) and exit the instant there is work, so the harness re-invokes
# the session to address it. Stops on its own after MAX idle seconds or when the PR
# closes/merges.
# Usage: watch-comments.sh OWNER REPO NUM ME FLOW [INTERVAL] [MAX]  (default 60, 1800)
# Launch with the Bash tool's run_in_background.
# Exit 0 = work found, 2 = idle timeout (paused), 3 = PR closed.
set -uo pipefail
O=$1 R=$2 N=$3 ME=$4 FLOW=$5 INTERVAL=${6:-60} MAX=${7:-1800}
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while true; do
  sleep "$INTERVAL"
  out=$("$S/check-work.sh" "$O" "$R" "$N" "$ME" "$FLOW"); rc=$?
  case $rc in
    0) echo "$out"; echo "review-pr watch: work found on $O/$R#$N"; exit 0 ;;
    3) echo "review-pr watch: $O/$R#$N is closed; stopping."; exit 3 ;;
  esac
  if [ "$SECONDS" -ge "$MAX" ]; then
    echo "review-pr watch: idle $((MAX/60))m on $O/$R#$N; paused."; exit 2
  fi
done
