#!/usr/bin/env bash
# Compile MacPowerSwitcher.app (unsigned). Sourced by build.sh and scripts/deploy/build-macos.sh.
set -euo pipefail

build_mac_power_switcher_app() {
  local root="$1"
  local app_dir="$2"

  local app_name="MacPowerSwitcher"
  local contents="$app_dir/Contents"
  local macos_dir="$contents/MacOS"
  local resources="$contents/Resources"
  local bin="$macos_dir/$app_name"
  local icns="$resources/AppIcon.icns"

  rm -rf "$app_dir"
  mkdir -p "$macos_dir" "$resources"

  echo "→ Generating app icon..."
  /usr/bin/swift "$root/scripts/generate-app-icon.swift" "$icns"

  echo "→ Compiling ${app_name}..."
  /usr/bin/swiftc \
    -O \
    -parse-as-library \
    -target arm64-apple-macosx13.0 \
    -framework AppKit \
    -framework IOKit \
    -framework LocalAuthentication \
    -framework SwiftUI \
    -o "$bin" \
    "$root/Sources/MacPowerSwitcherApp.swift" \
    "$root/Sources/AppSettings.swift" \
    "$root/Sources/SettingsView.swift" \
    "$root/Sources/SleepPreventer.swift" \
    "$root/Sources/PowerStatus.swift" \
    "$root/Sources/BiometricAuth.swift" \
    "$root/Sources/PrivilegedHelper.swift"

  cp "$root/Info.plist" "$contents/Info.plist"
}
