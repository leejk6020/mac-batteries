#!/bin/bash
# Archives BatteryBar.xcodeproj and exports a signed .pkg for Mac App Store upload.
#
# The App Sandbox is on in this build, so it does NOT report AirPods or third-party
# devices — only Apple HID accessories. See README "App Sandbox 제약".
#
# Requires an Apple ID signed into Xcode (Settings → Accounts); certificates and the
# provisioning profile are created on demand by -allowProvisioningUpdates.
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="BatteryBar"
TEAM_ID="NX4KU2A5JP"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/appstore"
OPTIONS="$BUILD_DIR/ExportOptions.plist"

mkdir -p "$BUILD_DIR"

echo "→ Archiving"
rm -rf "$ARCHIVE"
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
    -configuration Release archive -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates >/dev/null

# xcodebuild also registers the archive in Xcode's Organizer library on its own.
# If Organizer shows "No Archives", the window is just stale — reopen it.

echo "→ Writing export options"
cat > "$OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>export</string>
</dict></plist>
EOF

echo "→ Exporting signed package"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$OPTIONS" -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates >/dev/null

PKG="$EXPORT_DIR/$SCHEME.pkg"
echo "✓ Built: $PKG"
pkgutil --check-signature "$PKG" | sed -n '1,3p'

cat <<'EOF'

Next: create the app record in App Store Connect (bundle ID com.jklee.batterybar),
then upload with Xcode Organizer, Transporter, or:

  xcrun altool --upload-app -f build/appstore/BatteryBar.pkg -t macos \
      --apple-id <Apple ID> --password <app-specific password>
EOF
