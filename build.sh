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

if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools not found. Run: xcode-select --install"
    exit 1
fi

cd "$(dirname "$0")/pseudo_terminal" || exit

# xterm.js + Tauri CLI; a quick no-op when nothing in package.json changed
npm i -s || exit 1

echo "Building NASH.app..."
npm run build || exit 1

APP="$PWD/main/target/release/bundle/macos/NASH.app"
echo ""
echo "Built: $APP"

if [ "$1" = "--open" ]; then
    open "$APP"
fi
