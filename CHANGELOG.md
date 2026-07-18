# Changelog

BatteryBar의 모든 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르고,
버전은 [유의적 버전(SemVer)](https://semver.org/lang/ko/)을 따릅니다.

> **버전 올리는 법**: `Info.plist`의 `CFBundleShortVersionString`(표시 버전, 예 `1.1.0`)과
> `CFBundleVersion`(빌드 번호, 매 릴리스 +1)을 수정한 뒤, 아래 `[Unreleased]` 항목을
> 새 버전 번호로 확정(날짜 기입)하세요.

---

## [Unreleased]

_아직 없음. 다음 릴리스에 넣을 변경 사항을 여기에 추가하세요._

<!--
템플릿:
### Added        새 기능
### Changed      기존 동작 변경
### Fixed         버그 수정
### Removed       제거된 기능
-->

---

## [1.0.0] — 2026-07-18

첫 공개 릴리스.

### Added
- 메뉴바에서 연결된 Bluetooth 기기들의 배터리를 한눈에 확인.
- 기기별 아이콘 + 배터리 막대(색상: 초록/주황/빨강) 표시.
- AirPods 등은 **왼쪽 / 오른쪽 / 케이스** 배터리를 개별 표시.
- 메뉴바 아이콘이 **가장 낮은 배터리**를 반영하고, 옆에 최저 % 숫자 표시.
- 2분마다 자동 갱신 + 수동 새로고침 버튼.
- **로그인 시 자동 실행** 토글 (`SMAppService`).
- **저배터리 알림** — 임계값(10/15/20/30/40%) 선택, 임계값 교차 시 1회 알림,
  회복(+5%) 후 재알림(히스테리시스).
- **언어 전환** — English(기본) / 한국어 / 日本語, 시스템 언어와 무관하게 앱 내에서 즉시 전환.
- 앱 아이콘 (배터리 + Bluetooth).

### 릴리스 노트 (업데이트 페이지용)

**English**
> BatteryBar 1.0.0 — First release. See the battery level of every connected
> Bluetooth device right from the menu bar: keyboards, mice, trackpads, and
> AirPods (left / right / case shown separately). The menu bar icon reflects the
> lowest battery and shows its percentage. Includes launch-at-login, low-battery
> notifications with an adjustable threshold, and English / Korean / Japanese
> language options.

**한국어**
> BatteryBar 1.0.0 — 첫 출시. 연결된 모든 Bluetooth 기기(키보드·마우스·트랙패드·
> AirPods 좌/우/케이스)의 배터리를 메뉴바에서 바로 확인하세요. 메뉴바 아이콘은
> 가장 낮은 배터리를 표시하고 퍼센트를 함께 보여줍니다. 로그인 시 자동 실행,
> 임계값 조절이 가능한 저배터리 알림, 영어/한국어/일본어 지원.

**日本語**
> BatteryBar 1.0.0 — 初リリース。接続中のすべてのBluetoothデバイス(キーボード・
> マウス・トラックパッド・AirPodsの左/右/ケース)のバッテリー残量をメニューバーから
> 確認できます。メニューバーのアイコンは最も低いバッテリーを表示し、パーセントも
> 表示します。ログイン時に起動、しきい値を調整できるバッテリー残量アラート、
> 英語/韓国語/日本語に対応。

[Unreleased]: https://example.com/  <!-- 배포 후 릴리스/커밋 비교 URL로 교체 -->
[1.0.0]: https://example.com/        <!-- 예: GitHub Releases 태그 URL -->
