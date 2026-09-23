#!/usr/bin/env bash
# Build signed (and notarized when configured) Mac Power Switcher macOS DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=../lib/build-app.sh
source "$ROOT/scripts/lib/build-app.sh"
# shellcheck source=/dev/null
source "$ROOT/scripts/deploy/load-apple-signing.sh"

APP_NAME="MacPowerSwitcher"
APP_DIR="$ROOT/dist/${APP_NAME}.app"
DMG_STAGING="$ROOT/dist/dmg-staging"
DMG_PATH="$ROOT/dist/${APP_NAME}.dmg"
ENTITLEMENTS="$ROOT/scripts/deploy/MacPowerSwitcher.entitlements"

mkdir -p "$ROOT/dist"
build_mac_power_switcher_app "$ROOT" "$APP_DIR"

echo "→ Signing .app (hardened runtime)..."
codesign \
  --force \
  --options runtime \
  --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$APPLE_SIGNING_IDENTITY" \
  "$APP_DIR/Contents/MacOS/$APP_NAME"

codesign \
  --force \
  --options runtime \
  --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$APPLE_SIGNING_IDENTITY" \
  "$APP_DIR"

echo "→ Verifying .app signature..."
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "→ Creating DMG..."
hdiutil create \
  -volname "Mac Power Switcher" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo "→ Signing DMG..."
codesign \
  --force \
  --timestamp \
  --sign "$APPLE_SIGNING_IDENTITY" \
  "$DMG_PATH"

if [[ "${MAC_POWER_SWITCHER_NOTARIZE:-0}" == "1" ]]; then
  bash "$ROOT/scripts/deploy/notarize-dmg.sh"
fi

echo "→ Verifying DMG signature"
codesign -dv --verbose=2 "$DMG_PATH" 2>&1 | head -15 || true
if [[ "${MAC_POWER_SWITCHER_NOTARIZE:-0}" == "1" ]]; then
  echo "→ Checking notarization (Gatekeeper)"
  spctl -a -vv -t install "$DMG_PATH" 2>&1 || true
fi

echo "✓ Release build complete: $DMG_PATH"
