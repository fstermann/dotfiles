#!/usr/bin/env bash
# Run the M6 eval: for each pair, call the model K times per variant, append samples to outputs.
# Needs a reachable Anthropic Messages API (ANTHROPIC_API_KEY, optional ANTHROPIC_BASE_URL).
#
# Usage: [ANTHROPIC_MODEL=... K=5] ./run.sh pairs.jsonl outputs.jsonl
set -euo pipefail

PAIRS="${1:?usage: run.sh pairs.jsonl outputs.jsonl}"
OUT="${2:?usage: run.sh pairs.jsonl outputs.jsonl}"
MODEL="${ANTHROPIC_MODEL:-claude-haiku-4-5-20251001}"
K="${K:-5}"
BASE="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
: "${ANTHROPIC_API_KEY:?set ANTHROPIC_API_KEY}"

: > "$OUT"
call() { # $1 = full prompt -> prints model text
  local body
  body=$(jq -n --arg m "$MODEL" --arg p "$1" \
    '{model:$m,max_tokens:400,messages:[{role:"user",content:$p}]}')
  curl -sS -m 60 "$BASE/v1/messages" \
    -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" -d "$body" \
  | jq -r '.content[0].text // ""'
}

while IFS= read -r line; do
  [ -n "$line" ] || continue
  id=$(jq -r .id <<<"$line"); smell=$(jq -r .smell <<<"$line")
  task=$(jq -r .task <<<"$line")
  for variant in smelly fixed; do
    instr=$(jq -r ".$variant" <<<"$line")
    prompt="$task $instr"
    for _ in $(seq 1 "$K"); do
      text=$(call "$prompt")
      jq -cn --arg id "$id" --arg s "$smell" --arg v "$variant" --arg t "$text" \
        '{id:$id,smell:$s,variant:$v,text:$t}' >> "$OUT"
    done
  done
  echo "done $id" >&2
done < "$PAIRS"

echo "wrote $OUT" >&2
