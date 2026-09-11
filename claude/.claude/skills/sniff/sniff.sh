#!/usr/bin/env bash
# Compatibility wrapper for the original positional interface.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?usage: sniff.sh <file> [core|prompt|spec]}"
OLD_PROFILE="${2:-core}"

case "$OLD_PROFILE" in
  core) PROFILE=document ;;
  prompt|spec) PROFILE="$OLD_PROFILE" ;;
  *) echo "unknown legacy pack: $OLD_PROFILE" >&2; exit 2 ;;
esac

exec "$ROOT/sniff" check "$TARGET" --profile "$PROFILE"
