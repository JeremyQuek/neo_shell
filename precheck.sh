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

# 3. Compiler Check (node-pty is a native module built on npm install)
if ! command -v g++ &>/dev/null; then
    echo -e "${RED}❌ Error: g++ (Compiler) not found. Please install Xcode Command Line Tools.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Compiler: g++ found.${NC}"

# 4. Node.js & npm Check
if ! command -v node &>/dev/null; then
    echo -e "${RED}❌ Error: Node.js is not installed. (Required for Electron)${NC}"
    exit 1
fi

# 5. Architecture Check (Intel vs Apple Silicon)
# node-pty is compiled for this architecture
ARCH=$(uname -m)
echo -e "ℹ️  Architecture detected: $ARCH"

# 6. Build tools for node-pty (node-gyp needs make + python3)
if ! command -v make &>/dev/null; then
    echo -e "${RED}❌ Error: 'make' utility not found.${NC}"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}❌ Error: python3 not found (needed by node-gyp).${NC}"
    exit 1
fi

echo -e "\n${GREEN}🚀 All systems go! You are ready to run shell.sh.${NC}"