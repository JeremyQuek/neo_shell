#!/bin/bash

# --- CONFIGURATION ---
MIN_NODE_VERSION=14

# Colors for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Starting system compatibility check for NASH..."

# 1. Architecture/OS Check (Enforce macOS)
OS_TYPE=$(uname)
if [ "$OS_TYPE" != "Darwin" ]; then
    echo -e "${RED}❌ Error: This shell is only supported on macOS (Darwin). Current OS: $OS_TYPE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ OS: macOS detected.${NC}"

# 2. zsh Check (the shell the terminal runs)
if [ ! -x /bin/zsh ]; then
    echo -e "${RED}❌ Error: /bin/zsh not found.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Shell: zsh found.${NC}"

# 3. Rust toolchain (Tauri compiles the app's backend)
if ! command -v cargo &>/dev/null; then
    echo -e "${RED}❌ Error: Rust (cargo) not found. Install it from https://rustup.rs${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Rust: $(cargo --version) found.${NC}"

# 4. Xcode Command Line Tools (linker + macOS SDK for the WebView)
if ! xcode-select -p &>/dev/null; then
    echo -e "${RED}❌ Error: Xcode Command Line Tools not found. Run: xcode-select --install${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Xcode tools found.${NC}"

# 5. Node.js & npm Check (xterm.js + the Tauri CLI)
if ! command -v node &>/dev/null; then
    echo -e "${RED}❌ Error: Node.js is not installed. (Required for the Tauri CLI)${NC}"
    exit 1
fi

echo -e "\n${GREEN}🚀 All systems go! You are ready to run run.sh or build.sh.${NC}"