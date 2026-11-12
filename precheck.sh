#!/bin/bash

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

# 3. Xcode Command Line Tools (Swift compiler, Metal and the macOS SDK)
if ! xcode-select -p &>/dev/null; then
    echo -e "${RED}❌ Error: Xcode Command Line Tools not found. Run: xcode-select --install${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Xcode tools found.${NC}"

# 4. Swift (builds the app)
if ! command -v swift &>/dev/null; then
    echo -e "${RED}❌ Error: Swift not found. Run: xcode-select --install${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Swift: $(swift --version 2>&1 | head -1) found.${NC}"

echo -e "\n${GREEN}🚀 All systems go! You are ready to run run.sh or build.sh.${NC}"