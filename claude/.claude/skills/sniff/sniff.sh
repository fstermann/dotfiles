#!/usr/bin/env bash
# sniff deterministic pass. Runs every deterministic sniffer in scope over one file and
# prints findings. The model pass (model-only rules, D+ adjudication) is the skill's job.
#
# Usage: sniff.sh <file> [core|prompt|spec]   (default pack: core)
set -euo pipefail

TARGET="${1:?usage: sniff.sh <file> [core|prompt|spec]}"
PACK="${2:-core}"
RULES_DIR="$(cd "$(dirname "$0")" && pwd)/rules"

[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 2; }
[ -d "$RULES_DIR" ] || { echo "0 rules loaded" >&2; exit 0; }

# 1. Filtered view: blank out excluded spans, preserving line numbers so findings map back.
#    Excluded: fenced code blocks, Bad:/Good: example lines, blockquotes, inline `code` spans.
FILTERED="$(awk '
  BEGIN { infence = 0 }
  {
    if ($0 ~ /^[[:space:]]*```/) { infence = !infence; print ""; next }
    if (infence)                 { print ""; next }
    if ($0 ~ /^[[:space:]]*(Bad|Good):/) { print ""; next }
    if ($0 ~ /^[[:space:]]*>/)           { print ""; next }
    line = $0; gsub(/`[^`]*`/, " ", line); print line
  }
' "$TARGET")"

in_scope() { # $1 = rule pack; prompt and spec both include core
  case "$PACK" in
    core)   [ "$1" = core ] ;;
    prompt) [ "$1" = core ] || [ "$1" = prompt ] ;;
    spec)   [ "$1" = core ] || [ "$1" = spec ] ;;
    *)      return 1 ;;
  esac
}

field() { printf '%s\n' "$1" | sed -n "s/^$2: *//p" | head -1; }

loaded=0; findings=0
for rf in "$RULES_DIR"/*.md; do
  fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$rf")"
  pat="$(printf '%s\n' "$fm" | sed -n 's/^ *pattern: *//p' | head -1)"
  [ -n "$pat" ] || continue                       # model-only rule: not our job
  pack="$(field "$fm" pack)"
  in_scope "$pack" || continue
  loaded=$((loaded+1))
  id="$(field "$fm" id)"; sev="$(field "$fm" severity)"; msg="$(field "$fm" message)"
  pat="${pat#[\'\"]}"; pat="${pat%[\'\"]}"         # strip surrounding quotes
  pat="${pat//\\\\/\\}"                            # double-quoted YAML: \\ -> \
  while IFS=: read -r ln text; do
    [ -n "$ln" ] || continue
    span="$(printf '%s' "$text" | grep -oiE -- "$pat" | head -1)"
    printf '%s:%s  [%s]  %s\n    span: "%s"\n    why:  %s\n' "$TARGET" "$ln" "$sev" "$id" "$span" "$msg"
    findings=$((findings+1))
  done < <(printf '%s\n' "$FILTERED" | grep -niE -- "$pat" || true)
done

echo "---" >&2
echo "pack=$PACK  deterministic rules run=$loaded  findings=$findings" >&2
