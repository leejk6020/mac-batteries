# BatteryBar

연결된 블루투스 기기들의 배터리 상태를 macOS 메뉴바에서 한눈에 보는 앱.

키보드·마우스·트랙패드·AirPods(좌/우/케이스) 등의 배터리를 표시하며,
메뉴바 아이콘은 전체 기기 중 **가장 낮은 배터리 수준**을 반영합니다.

## 요구 사항

- macOS 13 이상
- Swift 툴체인 (`swiftc` — Xcode 또는 Command Line Tools 설치 시 포함)

## 빌드

```sh
./build.sh
```

`build/BatteryBar.app` 이 생성됩니다.

## 실행

```sh
open "build/BatteryBar.app"
```

메뉴바 우측에 배터리 아이콘 + 최저 배터리 %가 나타납니다. 클릭하면 기기 목록이 펼쳐집니다.
- 🔄 새로고침 버튼으로 즉시 갱신 (자동으로 2분마다 갱신)
- **로그인 시 자동 실행** 토글 — 켜면 로그인할 때 앱이 자동 실행됨
- **저배터리 알림** 토글 + 임계값(10/15/20/30/40%) — 기기 배터리가 임계값
  이하로 떨어지면 알림. 회복(임계값+5%) 후 다시 떨어지면 재알림.
- **언어** — English(기본) / 한국어 / 日本語 실시간 전환 (시스템 언어와 무관)
- **종료** 버튼으로 앱 종료

> 로그인 항목과 알림은 앱을 `/Applications` 로 옮긴 뒤 실행하는 것을 권장합니다.
> 로그인 항목이 가리키는 경로가 안정적으로 유지됩니다.

## 배포용 DMG 만들기

```sh
./build.sh              # 앱 빌드
./tools/make_dmg.sh     # dist/BatteryBar.dmg 생성 (앱 + Applications 드래그 설치)
```

### ⚠️ Gatekeeper 안내 (외부 배포 시 필독)

이 앱은 **ad-hoc 서명**만 되어 있고 Apple 공증(notarization)이 없습니다.
웹에서 다운로드하면 macOS가 격리 속성을 붙여 실행을 막습니다
("확인되지 않은 개발자" 또는 "손상되었습니다"). 두 가지 해결책:

**A. 다운로드한 사용자가 직접 해제** (README에 안내 권장)

```sh
xattr -dr com.apple.quarantine /Applications/BatteryBar.app
```

또는 Finder에서 앱 **우클릭 → 열기** → 경고창에서 **열기**.

**B. 제대로 배포 (경고 없음)** — Apple Developer Program($99/년) 필요:

```sh
# Developer ID 인증서로 서명
codesign --deep --force --options runtime \
    --sign "Developer ID Application: 이름 (TEAMID)" build/BatteryBar.app
# DMG 만든 뒤 공증
xcrun notarytool submit dist/BatteryBar.dmg \
    --apple-id you@example.com --team-id TEAMID --password <앱암호> --wait
xcrun stapler staple dist/BatteryBar.dmg
```

인증서가 있으시면 위 과정을 스크립트로 만들어드릴 수 있습니다.

## Mac App Store 제출

App Store 빌드는 `BatteryBar.xcodeproj` 로 만듭니다 (`build.sh` 의 `swiftc` 방식으로는
Archive/업로드가 불가능). 프로젝트는 App Sandbox가 켜진 상태이므로 **에어팟은 지원되지
않습니다** — 아래 "App Sandbox 제약" 참고.

```sh
./tools/make_appstore_pkg.sh    # archive → 서명된 build/appstore/BatteryBar.pkg
```

사전 준비는 **Xcode → Settings → Accounts 에 Apple ID 로그인** 하나뿐입니다.
`Apple Distribution` / `3rd Party Mac Developer Installer` 인증서와 프로비저닝
프로파일은 `-allowProvisioningUpdates` 가 자동 생성합니다.

업로드는 Xcode **Organizer → Distribute App**, Transporter 앱, 또는:

```sh
xcrun altool --upload-app -f build/appstore/BatteryBar.pkg -t macos \
    --apple-id <Apple ID> --password <앱 암호>
```

> 업로드 전에 App Store Connect에서 번들 ID `com.jklee.batterybar` 로
> **앱 레코드를 먼저 생성**해야 합니다.

앱 설명에 **에어팟을 언급하지 마세요** — 샌드박스 빌드에서는 동작하지 않으므로
심사 거부 및 부정적 리뷰 사유가 됩니다.

## 동작 방식

배터리 데이터는 두 소스를 병합해서 얻습니다. 어느 쪽도 단독으로는 완전하지 않습니다.

| 소스 | 커버리지 | 샌드박스에서 |
|------|----------|--------------|
| IORegistry (`AppleDeviceManagementHIDEventService` 의 `BatteryPercent`) | Magic Keyboard / Mouse / Trackpad | **동작** |
| `system_profiler SPBluetoothDataType -json` | AirPods(`Case`/`Left`/`Right`) 및 서드파티 기기 | **빈 결과** |

별도 권한이나 백그라운드 데몬은 필요 없습니다.

### App Sandbox 제약

App Sandbox 안에서 `system_profiler` 는 실패하지 않고 **성공한 것처럼 빈 목록을
반환**합니다. macOS 26 기준 에어팟 배터리는 IORegistry 어디에도 없으므로
(`BatteryPercent` 키는 레지스트리 전체에서 Magic Keyboard 하나뿐),
**샌드박스 빌드는 에어팟을 지원할 수 없습니다.**

- 기본 빌드 = 샌드박스 없음 → 전체 기기 지원, 직접 배포(Developer ID + 공증)용
- `SANDBOX=1 ./build.sh` → Mac App Store 제출용, Apple HID 액세서리만 지원

## 구조

| 파일 | 설명 |
|------|------|
| `Sources/App.swift` | 전체 앱 (모델·데이터 조회·SwiftUI 뷰) |
| `BatteryBar.xcodeproj` | App Store 제출용 Xcode 프로젝트 (Archive/업로드) |
| `Info.plist` | 번들 메타데이터 (`LSUIElement`=메뉴바 전용, Dock 아이콘 없음) |
| `build.sh` | `swiftc`로 `.app` 번들 생성 + 아이콘 삽입 + 샌드박스 서명 |
| `BatteryBar.entitlements` | App Sandbox 활성화 (Mac App Store 필수) |
| `Resources/AppIcon.icns` | 앱 아이콘 (배터리 + 블루투스) |
| `tools/make_icon.swift` | 아이콘 생성기 (CoreGraphics로 1024px PNG 렌더) |
| `tools/make_icns.sh` | PNG → iconset → `.icns` 변환 |
| `tools/make_dmg.sh` | 배포용 `dist/BatteryBar.dmg` 생성 (설치 안내 포함) |
| `tools/make_appstore_pkg.sh` | App Store 제출용 서명된 `.pkg` 생성 (archive + export) |
| `CHANGELOG.md` | 버전별 업데이트 이력 (업데이트 페이지 소스) |

## 아이콘 다시 만들기

```sh
./tools/make_icns.sh    # PNG 렌더 → iconset → Resources/AppIcon.icns
```

디자인을 바꾸려면 `tools/make_icon.swift`를 수정한 뒤 위 스크립트를 다시 실행하세요.

## 구현 메모

- **메뉴바 전용 앱**: `Info.plist`의 `LSUIElement=true`로 Dock 아이콘 없이 메뉴바에만 상주.
- **`DeviceStore.shared` 싱글톤**: `MenuBarExtra`는 `label:`과 `content:`를
  별도 호스팅 환경에서 렌더링하므로, 앱 레벨 `@StateObject`는 두 번 생성되어
  아이콘과 팝오버가 서로 다른 상태를 갖게 됩니다. 싱글톤으로 공유해 이를 방지.
- **목록은 `ScrollView`가 아닌 `VStack`**: `ScrollView`는 고유 높이가 없어
  콘텐츠에 맞춰 크기가 정해지는 팝오버 안에서 높이 0으로 접힙니다.
  기기 수가 적으므로 `VStack`으로 내용에 맞춰 표시.
- **로그인 항목**: `SMAppService.mainApp` (ServiceManagement) 사용. macOS 13+ 방식.
- **알림**: `UNUserNotificationCenter` 사용. 임계값 교차 시 1회만 알리도록
  기기별·구성요소별(`왼쪽`/`오른쪽`/`케이스`) 상태를 추적하고, 5% 히스테리시스로
  회복 후 재무장(re-arm)합니다.
