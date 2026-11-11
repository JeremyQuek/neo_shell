#!/bin/bash

# Pre-check dependencies
if ! command -v npm &>/dev/null; then
    echo "Error: npm is not installed."
    exit 1
fi

if ! command -v cargo &>/dev/null; then
    echo "Error: Rust (cargo) is not installed. Get it from https://rustup.rs"
    exit 1
fi

if [ ! -x /bin/zsh ]; then
    echo "Error: zsh is not installed."
    exit 1
fi


# npm i (xterm.js + Tauri CLI) && start; first run compiles the Rust side
cd ./pseudo_terminal || exit
npm i -s
echo "Spawning NASH terminal..."
npm start & cd ../
