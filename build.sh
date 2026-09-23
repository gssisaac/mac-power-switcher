#!/usr/bin/env bash
# Local unsigned build + DMG (no code signing).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/build-app.sh
source "$ROOT/scripts/lib/build-app.sh"

APP_NAME="MacPowerSwitcher"
APP_DIR="$ROOT/dist/${APP_NAME}.app"
DMG_STAGING="$ROOT/dist/dmg-staging"
DMG_PATH="$ROOT/dist/${APP_NAME}.dmg"

mkdir -p "$ROOT/dist"
build_mac_power_switcher_app "$ROOT" "$APP_DIR"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "Creating ${APP_NAME}.dmg..."
hdiutil create \
  -volname "Mac Power Switcher" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo "Built: $APP_DIR"
echo "DMG:   $DMG_PATH"
echo "Open with: open \"$DMG_PATH\""
