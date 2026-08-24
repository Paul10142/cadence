#!/bin/bash
# Builds Thyme Custom.app and a distributable DMG.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Thyme Custom"
BUNDLE_ID="com.paulclancy.ThymeCustom"
VERSION="1.0.0"
APP="build/${APP_NAME}.app"

# The Command Line Tools on this Mac ship a stale duplicate module map; the
# overlay hides it so AppKit can be imported. Harmless if the file is ever fixed.
swiftc -O -target arm64-apple-macos13.0 \
  -vfsoverlay build/vfs-overlay.yaml \
  -o build/ThymeCustom Sources/*.swift

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/ThymeCustom "$APP/Contents/MacOS/ThymeCustom"
cp build/ThymeCustom.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>ThymeCustom</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>A menu bar stopwatch, in the spirit of Thyme by João Moreno (MIT).</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: required for the app to run at all on Apple Silicon.
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"

# DMG
rm -f "build/${APP_NAME}.dmg"
rm -rf build/dmg && mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "${APP_NAME}" -srcfolder build/dmg -ov -format UDZO \
  "build/${APP_NAME}.dmg" >/dev/null
rm -rf build/dmg

echo "Built: $APP"
echo "Built: build/${APP_NAME}.dmg"
