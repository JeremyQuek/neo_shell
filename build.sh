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

# tauri build only packs main/icons/, so regenerate them when icon.svg is newer
if [ main/icon.svg -nt main/icons/icon.icns ]; then
    echo "Regenerating icons from icon.svg..."
    npx tauri icon main/icon.svg -o main/icons >/dev/null || exit 1
    # Keep only the macOS sizes tauri.conf.json uses
    (cd main/icons && rm -rf android ios Square*.png StoreLogo.png icon.ico 64x64.png)
fi

echo "Building NASH.app..."
npm run build || exit 1

APP="$PWD/main/target/release/bundle/macos/NASH.app"
echo ""
echo "Built: $APP"

# -n: start a fresh copy even if NASH is already running (plain `open`
# would just bring the old, already-running version to the front)
if [ "$1" = "--open" ]; then
    open -n "$APP"
fi
