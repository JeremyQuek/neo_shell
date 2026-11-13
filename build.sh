#!/bin/bash

# Builds neo_shell.app (Swift + Metal). Usage: ./build.sh [--open]

if ! command -v swift &>/dev/null; then
    echo "Error: Swift is not installed. Run: xcode-select --install"
    exit 1
fi

cd "$(dirname "$0")/terminal_app" || exit

# Regenerate the app icon whenever icon.svg is newer than icon.icns.
# Inkscape (which the SVG was made in) renders it; Quick Look and WebKit
# both mangle its shapes. sips makes each size macOS wants, and iconutil
# packs them into the .icns. Without Inkscape the current icon is kept.
INKSCAPE=/Applications/Inkscape.app/Contents/MacOS/inkscape
if [ icon/icon.svg -nt icon/icon.icns ]; then
    if [ ! -x "$INKSCAPE" ]; then
        echo "Warning: icon.svg changed but Inkscape isn't installed; keeping the old icon."
    else
        echo "Regenerating icon.icns from icon.svg..."
        ICONS="$(mktemp -d)"
        "$INKSCAPE" icon/icon.svg --export-type=png --export-area-page --export-width=1024 \
            --export-filename="$ICONS/icon.png" 2>/dev/null
        if [ ! -f "$ICONS/icon.png" ]; then
            echo "Error: couldn't render icon/icon.svg"
            exit 1
        fi
        SET="$ICONS/icon.iconset"
        mkdir -p "$SET"
        for size in 16 32 128 256 512; do
            sips -z $size $size "$ICONS/icon.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
            sips -z $((size * 2)) $((size * 2)) "$ICONS/icon.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
        done
        iconutil -c icns "$SET" -o icon/icon.icns || exit 1
        rm -rf "$ICONS"
    fi
fi

echo "Building neo_shell.app..."
swift build -c release || exit 1

# A .app is just a folder: the binary, an Info.plist and the icon. It's put
# together and signed outside the project, because iCloud keeps tagging
# folders on the Desktop with Finder metadata that codesign won't sign over.
STAGE="$(mktemp -d)"
STAGED="$STAGE/neo_shell.app"
mkdir -p "$STAGED/Contents/MacOS" "$STAGED/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/neo_shell" "$STAGED/Contents/MacOS/"
cp icon/icon.icns "$STAGED/Contents/Resources/"

cat > "$STAGED/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Neo Shell</string>
    <key>CFBundleDisplayName</key><string>Neo Shell</string>
    <key>CFBundleExecutable</key><string>neo_shell</string>
    <key>CFBundleIdentifier</key><string>com.jeremyquek.neoshell</string>
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

APP="$PWD/build/neo_shell.app"
rm -rf "$APP"
mkdir -p build
ditto "$STAGED" "$APP"
rm -rf "$STAGE"

echo ""
echo "Built: $APP"

# -n: start a fresh copy even if Neo Shell is already running (plain `open`
# would just bring the old, already-running version to the front)
if [ "$1" = "--open" ]; then
    open -n "$APP"
fi
