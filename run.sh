#!/bin/bash

# Runs Neo Shell straight from source (debug build, no .app). Use build.sh for the app.

if ! command -v swift &>/dev/null; then
    echo "Error: Swift is not installed. Run: xcode-select --install"
    exit 1
fi

if [ ! -x /bin/zsh ]; then
    echo "Error: zsh is not installed."
    exit 1
fi

# First run fetches SwiftTerm and compiles it (~1 min); later runs are quick
cd "$(dirname "$0")/terminal_app" || exit
swift build || exit 1
echo "Spawning Neo Shell..."
"$(swift build --show-bin-path)/neo_shell" &
