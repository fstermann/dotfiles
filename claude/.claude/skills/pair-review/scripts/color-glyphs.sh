#!/usr/bin/env bash
# Color the status glyph that starts a line, via GitHub math (the only color markup comments keep).
# Filter: body on stdin, colored body on stdout. A colored glyph starts with `$`, so re-running is a no-op.
set -euo pipefail
sed -E \
  -e 's/^❊/$\\color{#D97757}{❊}$/' \
  -e 's/^●/$\\color{#64b75d}{●}$/' \
  -e 's/^◐/$\\color{#c99b3e}{◐}$/' \
  -e 's/^○/$\\color{#e55e51}{○}$/'
