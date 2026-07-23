#!/bin/bash
# Produces App Store screenshots (2880x1800) from the real running app.
#
# Captures only the app's own popover and its own menu bar item — never the rest
# of the desktop — then composes them onto a clean canvas.
#
# Requires:
#   - Screen Recording and Accessibility permission for the calling terminal
#   - The App Sandbox build, so the shot shows what App Store users actually get:
#       SANDBOX=1 ./build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${APP:-build/BatteryBar.app}"
OUT="dist/screenshots"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"

echo "→ Launching $APP"
pkill -f "BatteryBar.app" 2>/dev/null || true
sleep 1
open "$APP"

geo() { osascript -e "tell application \"System Events\" to tell process \"BatteryBar\" to get {position, size} of $1" 2>/dev/null; }
field() { echo "$1" | cut -d, -f"$2" | tr -d ' '; }

# The status item is not in the accessibility tree the instant the app launches,
# so poll for it rather than guessing a sleep long enough.
# Right after launch the item briefly reports an off-screen origin, so require a
# sane on-screen x before accepting the reading.
BAR=""
for _ in $(seq 1 20); do
    BAR=$(geo "menu bar 2" || true)
    [ -n "$BAR" ] && [ "$(echo "$BAR" | cut -d, -f1 | tr -d ' ')" -gt 0 ] 2>/dev/null && break
    BAR=""
    sleep 1
done
[ -n "$BAR" ] || {
    echo "  Could not read the app's menu bar item. Grant Accessibility permission"
    echo "  to this terminal in System Settings → Privacy & Security → Accessibility."
    exit 1
}

echo "→ Capturing the status item"
screencapture -x -o -R"$(field "$BAR" 1),$(field "$BAR" 2),$(field "$BAR" 3),$(field "$BAR" 4)" "$TMP/statusitem-en.png"

echo "→ Opening and capturing the popover"
swiftc -O tools/screenshot/windowid.swift -o "$TMP/windowid"

# The popover is captured by window id, not by screen region: it uses a translucent
# material, so a region grab would bake whatever sits behind it into the shot.
# It also closes as soon as anything else takes focus, so the click, the id lookup
# and the capture have to run back to back with nothing in between.
CAPTURED=""
for _ in $(seq 1 5); do
    osascript -e 'tell application "System Events" to tell process "BatteryBar" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1 || true
    ID=$("$TMP/windowid" || true)
    if [ -n "$ID" ] && screencapture -x -o -l "$ID" "$TMP/popover-en.png" 2>/dev/null; then
        CAPTURED=yes
        break
    fi
    sleep 1
done
[ -n "$CAPTURED" ] || { echo "  Popover did not open."; exit 1; }

osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true

echo "→ Composing"
swiftc -O tools/screenshot/compose.swift -framework AppKit -o "$TMP/compose"
"$TMP/compose" "$TMP"

cp "$TMP/store-1.png" "$OUT/store-1-hero.png"
cp "$TMP/store-2.png" "$OUT/store-2-plain.png"
echo "✓ Wrote $OUT/store-1-hero.png and $OUT/store-2-plain.png (2880x1800)"
