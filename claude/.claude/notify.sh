#!/usr/bin/env bash
# On non-Darwin hosts this rings the terminal bell.
# To surface it as a notification in VSCode (incl. Remote sessions on Windows),
# enable in your VSCode user settings:
#   "terminal.integrated.enableBell": true
msg="$1"
title="${2:-Claude Code}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    terminal-notifier -message "$msg" -title "$title" \
        -activate com.microsoft.VSCode \
        -contentImage "/Applications/Visual Studio Code.app/Contents/Resources/Code.icns"
else
    printf '\a' > /dev/tty 2>/dev/null
fi
