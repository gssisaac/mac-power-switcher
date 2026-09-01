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
  -o "$BIN" \
  "$ROOT/Sources/MacPowerSwitcherApp.swift" \
  "$ROOT/Sources/SleepPreventer.swift" \
  "$ROOT/Sources/BiometricAuth.swift" \
  "$ROOT/Sources/PrivilegedHelper.swift"

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

echo "Built: $APP_DIR"
echo "Open with: open \"$APP_DIR\""
