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

# VERSION file is the single source of truth (see plan.md > Versioning).
# "-dev" suffix keeps a locally-built copy visually distinct in the Debug
# menu's version display from whatever's actually installed in
# /Applications - both can be at the same VERSION number without this.
VERSION="$(cat VERSION)-dev"
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
codesign --force --sign "$SIGNING_IDENTITY" "${SPARKLE_VERSIONED}/XPCServices/Downloader.xpc"
codesign --force --sign "$SIGNING_IDENTITY" "${SPARKLE_VERSIONED}/XPCServices/Installer.xpc"
codesign --force --sign "$SIGNING_IDENTITY" "${SPARKLE_VERSIONED}/Updater.app"
codesign --force --sign "$SIGNING_IDENTITY" "${SPARKLE_VERSIONED}/Autoupdate"
codesign --force --sign "$SIGNING_IDENTITY" "${FRAMEWORKS_DIR}/Sparkle.framework"

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
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/LexxaRRioo/ramona-game/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>fQ6KeKg+0wlcdgUrrMke//RIz5HMdyfL1r8/hurfz/w=</string>
    <key>SUEnableAutomaticChecks</key>
    <false/>
</dict>
</plist>
PLIST

codesign --force --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

echo "Built ${APP_BUNDLE}"
echo "Run: open ${APP_BUNDLE}"
