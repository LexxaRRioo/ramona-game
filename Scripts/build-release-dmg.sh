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

# VERSION file is the single source of truth (see plan.md > Versioning);
# override only for one-off test builds, e.g. build-release-dmg.sh 0.0.3-test.
VERSION="${1:-$(cat VERSION)}"
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

# SwiftPM links Sparkle.framework via @rpath, resolved against @loader_path
# (Contents/MacOS/) by default - that only finds a framework sitting right
# next to the executable, not the conventional Contents/Frameworks/ location
# below. Patching in an extra rpath keeps the standard bundle layout instead
# of dumping the framework in MacOS/. Must happen before signing - it
# invalidates whatever signature was already on the binary.
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}"

FRAMEWORKS_DIR="${CONTENTS}/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"
cp -R "${BUILD_DIR}/Sparkle.framework" "${FRAMEWORKS_DIR}/"
SPARKLE_VERSIONED="${FRAMEWORKS_DIR}/Sparkle.framework/Versions/B"
# Order matters: leaf XPC services/helpers first, framework wrapper last,
# then the outer app WITHOUT --deep below - Sparkle's own docs warn --deep
# on the app corrupts the XPC services' signatures if applied afterward.
codesign --force --sign - "${SPARKLE_VERSIONED}/XPCServices/Downloader.xpc"
codesign --force --sign - "${SPARKLE_VERSIONED}/XPCServices/Installer.xpc"
codesign --force --sign - "${SPARKLE_VERSIONED}/Updater.app"
codesign --force --sign - "${SPARKLE_VERSIONED}/Autoupdate"
codesign --force --sign - "${FRAMEWORKS_DIR}/Sparkle.framework"

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
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/LexxaRRioo/ramona-game/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>fQ6KeKg+0wlcdgUrrMke//RIz5HMdyfL1r8/hurfz/w=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_BUNDLE"

ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

echo "Built ${DMG_PATH}"
