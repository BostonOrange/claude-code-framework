#!/bin/bash
# Play a sound when Claude Code session stops
# macOS: uses built-in Glass sound
# Linux: uses paplay if available
if [[ "$OSTYPE" == "darwin"* ]]; then
    afplay /System/Library/Sounds/Glass.aiff &
elif command -v paplay &> /dev/null; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga &
fi
