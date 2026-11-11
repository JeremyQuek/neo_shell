#!/bin/bash

# Pre-check dependencies
if ! command -v npm &>/dev/null; then
    echo "Error: npm is not installed."
    exit 1
fi

if [ ! -x /bin/zsh ]; then
    echo "Error: zsh is not installed."
    exit 1
fi


# npm i (postinstall rebuilds node-pty for Electron) && start
cd ./pseudo_terminal || exit
npm i -s
echo "Spawning NASH terminal..."
npm start & cd ../
