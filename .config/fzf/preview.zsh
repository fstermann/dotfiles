#!/usr/bin/env zsh

TARGET="${1:-$realpath}"

if [[ -z "$TARGET" ]]; then
    exit 0
fi

# Resolve to absolute path if relative
[[ "$TARGET" != /* ]] && TARGET="$PWD/$TARGET"

if [[ -d "$TARGET" ]]; then
    ls -G -A "$TARGET"
elif [[ -f "$TARGET" ]]; then
    bat --color=always --style=numbers --line-range=:500 "$TARGET"
fi
