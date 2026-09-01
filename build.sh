#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MacPowerSwitcher"
APP_DIR="$ROOT/dist/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
BIN="$MACOS_DIR/$APP_NAME"

mkdir -p "$MACOS_DIR"

echo "Building ${APP_NAME}..."
/usr/bin/swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macosx13.0 \
  -framework IOKit \
  -o "$BIN" \
  "$ROOT/Sources/MacPowerSwitcherApp.swift" \
  "$ROOT/Sources/SleepPreventer.swift" \
  "$ROOT/Sources/PowerStatus.swift" \
  "$ROOT/Sources/BiometricAuth.swift" \
  "$ROOT/Sources/PrivilegedHelper.swift"

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

DMG_STAGING="$ROOT/dist/dmg-staging"
DMG_PATH="$ROOT/dist/${APP_NAME}.dmg"

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
