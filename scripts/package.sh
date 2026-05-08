#!/bin/bash
# OpenShark macOS packaging script
# Usage: ./scripts/package.sh [--sign "Developer ID Application: ..."]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
APP="$BUILD_DIR/openshark.app"
ENTITLEMENTS="$ROOT_DIR/entitlements.plist"
DMG_OUT="$BUILD_DIR/OpenShark.dmg"
SIGN_IDENTITY="${1:-}"   # pass Developer ID as first arg, or leave empty for ad-hoc

if [ ! -d "$APP" ]; then
    echo "error: $APP not found — run cmake --build build first"
    exit 1
fi

# Work on a copy so the dev build stays intact
STAGE="$BUILD_DIR/OpenShark-stage.app"
rm -rf "$STAGE"
cp -a "$APP" "$STAGE"
APP="$STAGE"

echo "━━━ macdeployqt ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Non-zero exit from macdeployqt is expected for optional Qt modules (Qt3D, PDF, etc.)
# that aren't installed. Core frameworks are still bundled correctly.
macdeployqt "$APP" \
    -qmldir="$ROOT_DIR/qml" \
    -no-strip \
    -verbose=1 || echo "(some optional Qt modules could not be resolved — this is expected)"

echo ""
echo "━━━ Stripping Finder xattrs ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Homebrew Qt frameworks carry com.apple.FinderInfo attrs that block codesign
xattr -r -d com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -r -d "com.apple.fileprovider.fpfs#P" "$APP" 2>/dev/null || true
# Also strip from the .app directory node itself (not covered by -r)
xattr -d com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -d "com.apple.fileprovider.fpfs#P" "$APP" 2>/dev/null || true

echo ""
echo "━━━ Code signing ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing with: $SIGN_IDENTITY"
    codesign --force --deep --options runtime \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$ENTITLEMENTS" \
        "$APP"
else
    echo "No Developer ID provided — using ad-hoc signature (local use only)"
    codesign --force --deep --sign - \
        --entitlements "$ENTITLEMENTS" \
        "$APP"
fi

echo ""
echo "━━━ DMG packaging ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
rm -f "$DMG_OUT"
hdiutil create \
    -volname "OpenShark" \
    -srcfolder "$APP" \
    -ov \
    -format UDZO \
    "$DMG_OUT"

rm -rf "$STAGE"

echo ""
echo "✓  $DMG_OUT"
echo ""

# Optional: notarize (requires Apple ID + app-specific password in keychain)
# xcrun notarytool submit "$DMG_OUT" \
#     --keychain-profile "AC_PASSWORD" \
#     --wait
# xcrun stapler staple "$DMG_OUT"
