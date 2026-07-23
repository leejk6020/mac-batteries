#!/bin/bash
# Builds the notarized DMG for distribution from your own site — the full-feature
# build, with no App Sandbox, so AirPods and third-party devices are included.
#
# The app is archived through Xcode rather than build.sh because the Developer ID
# certificate Xcode issues is cloud-managed: `codesign --sign "Developer ID ..."`
# from the command line cannot see its private key, so signing has to happen
# inside an Xcode export.
#
# One-time setup — store an app-specific password (appleid.apple.com → Sign-In
# and Security → App-Specific Passwords) under the profile this script expects:
#
#   xcrun notarytool store-credentials batterybar \
#       --apple-id <your Apple ID> --team-id NX4KU2A5JP --password <app password>
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="BatteryBar"
TEAM_ID="NX4KU2A5JP"
PROFILE="${NOTARY_PROFILE:-batterybar}"
WORK="build/release"
ARCHIVE="$WORK/$SCHEME.xcarchive"
EXPORT="$WORK/export"
APP="$EXPORT/$SCHEME.app"

mkdir -p "$WORK"

echo "→ Archiving without the App Sandbox"
rm -rf "$ARCHIVE"
# Clearing CODE_SIGN_ENTITLEMENTS drops the sandbox the App Store build needs but
# this one must not have — sandboxed, the app cannot see AirPods at all.
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Release \
    archive -archivePath "$ARCHIVE" -allowProvisioningUpdates \
    CODE_SIGN_ENTITLEMENTS="" >/dev/null

echo "→ Exporting with Developer ID"
rm -rf "$EXPORT"
cat > "$WORK/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>export</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$WORK/ExportOptions.plist" -exportPath "$EXPORT" \
    -allowProvisioningUpdates >/dev/null

# Captured first rather than piped into grep -q: under `pipefail`, grep exiting on
# its first match kills codesign with SIGPIPE and the whole pipeline reads as failed.
SIGINFO="$(codesign -dv --verbose=2 "$APP" 2>&1)"
echo "  signed by: $(printf '%s\n' "$SIGINFO" | sed -n 's/^Authority=//p' | head -1)"
case "$SIGINFO" in
    *"(runtime)"*) ;;
    *) echo "✗ hardened runtime missing — notarization would be rejected"; exit 1 ;;
esac

echo "→ Notarizing (this usually takes a few minutes)"
# The app is zipped and notarized on its own, then stapled, and only then packed
# into the DMG: that way the ticket travels inside the app itself and the disk
# image needs no signature of its own.
#
# Credentials are not probed beforehand — `notarytool history` returns 401 on
# accounts that can still submit fine, so the submission itself is the only
# reliable check.
ZIP="$WORK/$SCHEME.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
if ! xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait; then
    cat <<EOF

✗ Notarization failed. If this was an authentication error, store credentials with:

    xcrun notarytool store-credentials $PROFILE \\
        --apple-id <your Apple ID> --team-id $TEAM_ID

  (omit --password and it prompts, so the secret stays off screen)

  The signed but un-notarized app is at $APP.
EOF
    exit 1
fi

echo "→ Stapling the ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "→ Packaging DMG"
APP="$APP" NOTARIZED=1 OUT="dist/BatteryBar.dmg" ./tools/make_dmg.sh

echo "→ Verifying Gatekeeper acceptance"
spctl --assess --type execute --verbose=2 "$APP" 2>&1 | sed 's/^/  /'
echo "✓ dist/BatteryBar.dmg is notarized and ready to publish"
