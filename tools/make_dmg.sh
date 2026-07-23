#!/bin/bash
# Builds a distributable BatteryBar.dmg from build/BatteryBar.app.
# Run ./build.sh first so build/BatteryBar.app is up to date.
set -euo pipefail
cd "$(dirname "$0")/.."

# Override APP to package a different build — make_release_dmg.sh passes the
# notarized, Developer ID signed one. NOTARIZED=1 swaps the Gatekeeper workaround
# in the bundled guide for a plain install note.
APP="${APP:-build/BatteryBar.app}"
NOTARIZED="${NOTARIZED:-0}"
VOL="BatteryBar"
OUT="${OUT:-dist/BatteryBar.dmg}"

[ -d "$APP" ] || { echo "✗ $APP not found — run ./build.sh first"; exit 1; }

mkdir -p dist
rm -f "$OUT"

STAGE="$(mktemp -d)"
echo "→ Staging app + Applications shortcut"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install target

echo "→ Writing install guide"
if [ "$NOTARIZED" = "1" ]; then
cat > "$STAGE/먼저 읽어주세요 — READ ME.txt" <<'GUIDE'
BatteryBar — 설치 안내 / Installation / インストール

────────────────────────────────────────────────────────
[한국어]
1) 이 창의 BatteryBar 아이콘을 왼쪽 Applications 폴더로 드래그하세요.
2) 응용 프로그램 폴더에서 BatteryBar를 더블클릭하세요.

이 앱은 Apple의 공증(notarization)을 받았으므로 별도의 보안 설정이
필요 없습니다. 메뉴 막대 오른쪽에 배터리 아이콘이 나타납니다.

────────────────────────────────────────────────────────
[English]
1) Drag the BatteryBar icon onto the Applications folder shown here.
2) Open the Applications folder and double-click BatteryBar.

The app is notarized by Apple, so no security settings need changing.
A battery icon appears on the right side of the menu bar.

────────────────────────────────────────────────────────
[日本語]
1) このウィンドウのBatteryBarアイコンをApplicationsフォルダにドラッグします。
2) アプリケーションフォルダでBatteryBarをダブルクリックします。

このアプリはAppleの公証(notarization)を受けているため、セキュリティ設定を
変更する必要はありません。メニューバー右側にバッテリーアイコンが表示されます。
GUIDE
else
cat > "$STAGE/먼저 읽어주세요 — READ ME.txt" <<'GUIDE'
BatteryBar — 설치 안내 / Installation / インストール

이 앱은 아직 Apple 공증(notarization) 전이라, 처음 실행할 때 macOS가
차단합니다. 정상입니다. 아래 방법으로 여세요.
This app is not yet notarized by Apple, so macOS blocks it on first launch.
This is expected — open it as follows.
このアプリはまだApple公証(notarization)前のため、初回起動時にmacOSが
ブロックします。正常な動作です。以下の方法で開いてください。

────────────────────────────────────────────────────────
[한국어]
1) 이 창의 BatteryBar 아이콘을 왼쪽 Applications 폴더로 드래그하세요.
2) 응용 프로그램 폴더에서 BatteryBar를 더블클릭하세요.
3) "열 수 없습니다" 경고가 뜨면:
   시스템 설정 > 개인정보 보호 및 보안 을 열고, 아래로 스크롤한 뒤
   BatteryBar 옆의 [확인 없이 열기] 를 누르세요. (한 번만 하면 됩니다.)

   ▸ 빠른 방법 (터미널):
     xattr -dr com.apple.quarantine "/Applications/BatteryBar.app"
     실행 후 BatteryBar를 평소처럼 여세요.

────────────────────────────────────────────────────────
[English]
1) Drag the BatteryBar icon onto the Applications folder shown here.
2) Open the Applications folder and double-click BatteryBar.
3) If macOS says it "can't be opened":
   Open  System Settings > Privacy & Security,  scroll down, and click
   [Open Anyway]  next to BatteryBar. (You only need to do this once.)

   ▸ Fast alternative (Terminal):
     xattr -dr com.apple.quarantine "/Applications/BatteryBar.app"
     then open BatteryBar normally.

────────────────────────────────────────────────────────
[日本語]
1) このウィンドウのBatteryBarアイコンをApplicationsフォルダにドラッグします。
2) アプリケーションフォルダでBatteryBarをダブルクリックします。
3) 「開けません」と表示されたら:
   システム設定 > プライバシーとセキュリティ を開き、下にスクロールして
   BatteryBarの横の [このまま開く] をクリックします。(初回のみ)

   ▸ 簡単な方法 (ターミナル):
     xattr -dr com.apple.quarantine "/Applications/BatteryBar.app"
     その後、通常どおりBatteryBarを開きます。
GUIDE
fi

echo "→ Creating compressed DMG"
hdiutil create \
    -volname "$VOL" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$OUT" >/dev/null

rm -rf "$STAGE"
SIZE="$(du -h "$OUT" | cut -f1)"
echo "✓ Built $OUT ($SIZE)"
