#!/usr/bin/env bash
# work.sh — work machine profile
#
# Core tools + work apps (browser, editor, 1Password), no personal apps.

# shellcheck source=base.sh
source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

PROFILE_BREW_FILES=(brew.macos)
PROFILE_DESCRIPTION="Work machine (core + browser, VS Code, 1Password)"
