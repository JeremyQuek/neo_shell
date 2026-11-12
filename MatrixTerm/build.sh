#!/bin/bash

# Builds NASH.app from the Swift package. Usage: ./build.sh [--open]

if ! command -v swift &>/dev/null; then
    echo "Error: Swift is not installed. Run: xcode-select --install"
    exit 1
fi

cd "$(dirname "$0")" || exit

echo "Building MatrixTerm (release)..."
swift build -c release || exit 1

# A .app is just a folder: the binary, an Info.plist and the icon. It's put
# together and signed outside the project, because iCloud keeps tagging
# folders on the Desktop with Finder metadata that codesign won't sign over.
STAGE="$(mktemp -d)"
STAGED="$STAGE/NASH.app"
mkdir -p "$STAGED/Contents/MacOS" "$STAGED/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/MatrixTerm" "$STAGED/Contents/MacOS/"
cp ../pseudo_terminal/main/icons/icon.icns "$STAGED/Contents/Resources/"

cat > "$STAGED/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NASH</string>
    <key>CFBundleDisplayName</key><string>NASH</string>
    <key>CFBundleExecutable</key><string>MatrixTerm</string>
    <key>CFBundleIdentifier</key><string>com.jeremyquek.matrixterm</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>icon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature, so macOS runs it without a developer certificate
xattr -cr "$STAGED"
codesign --force --sign - "$STAGED" || exit 1

APP="$PWD/build/NASH.app"
rm -rf "$APP"
mkdir -p build
ditto "$STAGED" "$APP"
rm -rf "$STAGE"

echo ""
echo "Built: $APP"

# -n: start a fresh copy even if NASH is already running
if [ "$1" = "--open" ]; then
    open -n "$APP"
fi
