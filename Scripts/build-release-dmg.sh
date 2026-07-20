#!/bin/bash
# Builds a release .app bundle and wraps it in a .dmg for distribution.
# Unsigned (no Developer ID) by design (plan.md: "unsigned .dmg via GitHub
# Releases") - no Apple Developer account required. The bundle still gets
# an ad-hoc codesign pass below: without it, the bundle's signature (from
# SwiftPM's linker-signed executable) doesn't cover Contents/Resources, and
# Gatekeeper reports the whole app as "damaged" - a hard failure with no
# user override, unlike the recoverable "Apple could not verify" prompt an
# ad-hoc-signed-but-unnotarized app gets (System Settings > Privacy &
# Security > Open Anyway) which matches the flow documented in README.md.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.1}"
APP_NAME="Ramona"
BUNDLE_ID="dev.ramona.Ramona"
BUILD_DIR=".build/release"
STAGING_DIR=".build/dmg-staging"
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
DMG_PATH=".build/${APP_NAME}-${VERSION}.dmg"

swift build -c release

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Unlike Scripts/build-dev-app.sh (which relies on the build-directory
# fallback path baked into Bundle.module at compile time, since it always
# runs on the same machine that built it), a distributed release has to
# find resources without that fallback. Bundle.module's generated accessor
# checks Bundle.main.resourceURL as one of its candidates, which for a real
# .app is Contents/Resources - the standard, portable location.
cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${RESOURCES_DIR}/"

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
    <string>${VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE"

ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

echo "Built ${DMG_PATH}"
