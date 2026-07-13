#!/bin/bash
# Builds Ramona and wraps it in a minimal .app bundle with a fixed bundle
# identifier, signed with the local "Ramona Dev" certificate (Keychain
# Access > Certificate Assistant > Create a Certificate > Self Signed Root,
# Code Signing). Ad-hoc signing (--sign -) keys TCC's grant to the binary's
# content hash, which changes on every rebuild, so Accessibility silently
# reverts each time even though System Settings still shows it toggled on.
# Signing with a real (if self-signed) certificate keys the designated
# requirement to the certificate instead, so the grant survives rebuilds.
# Grant Accessibility once for .build/Ramona.app; it survives future
# rebuilds via this script.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build

APP_NAME="Ramona"
BUNDLE_ID="dev.ramona.Ramona"
SIGNING_IDENTITY="Ramona Dev"
BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_BUNDLE=".build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Bundled resources (Species/ramona.json etc.) are deliberately NOT copied
# into the .app: SwiftPM's generated Bundle.module accessor falls back to
# the absolute build-directory path baked in at compile time when it can't
# find a resource bundle at the app root, and placing one there ourselves
# makes codesign reject the bundle ("unsealed contents present in the
# bundle root") since it's outside Contents/. So this only works as long as
# BUILD_DIR/*.bundle still exists on disk - don't delete .build by hand
# between building and running; re-run this script instead.

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

codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

echo "Built ${APP_BUNDLE}"
echo "Run: open ${APP_BUNDLE}"
