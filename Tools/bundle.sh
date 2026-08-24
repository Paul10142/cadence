#!/bin/bash
# Builds Cadence.app and a distributable DMG.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Cadence"
BUNDLE_ID="com.paulclancy.Cadence"
VERSION="1.1.0"
APP="build/${APP_NAME}.app"

mkdir -p build
# Keep the freshly built app out of Spotlight, so searching for the app does not
# turn up this intermediate copy alongside the one in /Applications.
touch build/.metadata_never_index

# Some Command Line Tools installs carry a stale duplicate of the SwiftBridging
# module map, which makes importing AppKit fail. If this machine has it, hide the
# stale copy behind a virtual filesystem overlay for the duration of the build.
SWIFT_INC="/Library/Developer/CommandLineTools/usr/include/swift"
OVERLAY_ARGS=()
if [ -f "$SWIFT_INC/module.modulemap" ] && [ -f "$SWIFT_INC/bridging.modulemap" ]; then
  echo "note: working around duplicate SwiftBridging module map"
  : > build/empty.modulemap
  cat > build/vfs-overlay.yaml <<YAML
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
    {
      "type": "directory",
      "name": "$SWIFT_INC",
      "contents": [
        { "type": "file", "name": "module.modulemap",
          "external-contents": "$(pwd)/build/empty.modulemap" }
      ]
    }
  ]
}
YAML
  OVERLAY_ARGS=(-vfsoverlay build/vfs-overlay.yaml)
fi

swiftc -O -target arm64-apple-macos13.0 "${OVERLAY_ARGS[@]}" \
  -o "build/${APP_NAME}" Sources/*.swift

# App icon
swiftc -target arm64-apple-macos13.0 "${OVERLAY_ARGS[@]}" \
  -o build/makeicon Tools/makeicon.swift
./build/makeicon "build/${APP_NAME}.iconset"
iconutil -c icns "build/${APP_NAME}.iconset" -o "build/${APP_NAME}.icns"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "build/${APP_NAME}" "$APP/Contents/MacOS/${APP_NAME}"
cp "build/${APP_NAME}.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
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
    <key>NSHumanReadableCopyright</key><string>A menu bar timer, in the spirit of Thyme by João Moreno (MIT).</string>
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
