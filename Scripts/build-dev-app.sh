#!/bin/bash
# Builds Ramona and wraps it in a minimal .app bundle with a fixed bundle
# identifier, ad-hoc signed. Unbundled `swift run` binaries get a fresh
# TCC identity on every rebuild, so macOS forgets the Accessibility grant
# each time - a real app bundle at a stable path/identifier doesn't have
# that problem. Grant Accessibility once for .build/Ramona.app; it survives
# future rebuilds via this script.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build

APP_NAME="Ramona"
BUNDLE_ID="dev.ramona.Ramona"
BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_BUNDLE=".build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built ${APP_BUNDLE}"
echo "Run: open ${APP_BUNDLE}"
