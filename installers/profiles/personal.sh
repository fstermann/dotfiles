#!/usr/bin/env bash
# personal.sh — personal machine profile
#
# Everything: core + work apps + personal apps (music, media, messaging).

# shellcheck source=base.sh
source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

PROFILE_BREW_FILES=(brew.macos brew.personal)
PROFILE_DESCRIPTION="Personal machine (core + all apps)"
