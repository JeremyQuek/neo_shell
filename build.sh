#!/bin/bash

# Builds NASH.app (Tauri). Usage: ./build.sh [--open]

# Pre-check dependencies
if ! command -v npm &>/dev/null; then
    echo "Error: npm is not installed."
    exit 1
fi

if ! command -v cargo &>/dev/null; then
    echo "Error: Rust (cargo) is not installed. Get it from https://rustup.rs"
    exit 1
fi

cd "$(dirname "$0")/pseudo_terminal" || exit

# xterm.js + Tauri CLI; only needed the first time (or after package.json changes)
if [ ! -d node_modules ]; then
    npm i -s || exit 1
fi

echo "Building NASH.app..."
npm run build || exit 1

APP="$PWD/src-tauri/target/release/bundle/macos/NASH.app"
echo ""
echo "Built: $APP"

if [ "$1" = "--open" ]; then
    open "$APP"
fi
