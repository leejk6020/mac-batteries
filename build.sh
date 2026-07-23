#!/bin/bash
# Builds "Bluetooth Batteries.app" from Sources/ using swiftc (no Xcode project needed).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="BatteryBar"
BIN_NAME="BatteryBar"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "→ Cleaning previous build"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "→ Compiling Swift sources"
swiftc -O -parse-as-library \
    Sources/*.swift \
    -framework SwiftUI -framework AppKit \
    -o "$MACOS_DIR/$BIN_NAME"

echo "→ Installing Info.plist"
cp Info.plist "$APP_DIR/Contents/Info.plist"

echo "→ Installing app icon"
cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"

# The sandbox is off by default: it is required only for the Mac App Store, and it
# costs AirPods support (their battery level is reachable solely through
# system_profiler, which returns nothing once sandboxed). Opt in with:
#   SANDBOX=1 SIGN_IDENTITY="Apple Distribution: ..." ./build.sh
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "${SANDBOX:-0}" = "1" ]; then
    echo "→ Code signing (App Sandbox ON — no AirPods) as: $SIGN_IDENTITY"
    codesign --force --deep --sign "$SIGN_IDENTITY" \
        --entitlements BatteryBar.entitlements \
        "$APP_DIR" >/dev/null 2>&1 || echo "  (codesign skipped)"
else
    echo "→ Code signing (no sandbox) as: $SIGN_IDENTITY"
    codesign --force --deep --sign "$SIGN_IDENTITY" \
        "$APP_DIR" >/dev/null 2>&1 || echo "  (codesign skipped)"
fi

echo "✓ Built: $APP_DIR"
echo "  Run with:  open \"$APP_DIR\""
