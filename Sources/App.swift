import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

// MARK: - Localization

/// Supported UI languages. Default is English.
enum Lang: String, CaseIterable, Identifiable {
    case en, ko, ja
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어"
        case .ja: return "日本語"
        }
    }
}

/// All user-facing strings, resolved for a given language. Keeping every string
/// in one place (rather than .lproj bundles) lets the user switch language at
/// runtime independent of the system locale.
struct L10n {
    let lang: Lang

    private func t(_ en: String, _ ko: String, _ ja: String) -> String {
        switch lang {
        case .en: return en
        case .ko: return ko
        case .ja: return ja
        }
    }

    var header: String { t("Bluetooth Batteries", "Bluetooth 배터리", "Bluetooth バッテリー") }
    var refresh: String { t("Refresh", "새로고침", "更新") }
    var loading: String { t("Loading…", "불러오는 중…", "読み込み中…") }
    var noDevices: String { t("No connected devices", "연결된 기기가 없습니다", "接続されたデバイスがありません") }
    var noBattery: String { t("No battery info", "배터리 정보 없음", "バッテリー情報なし") }
    var launchAtLogin: String { t("Launch at login", "로그인 시 자동 실행", "ログイン時に起動") }
    var lowBatteryAlert: String { t("Low battery alert", "저배터리 알림", "バッテリー残量アラート") }
    var language: String { t("Language", "언어", "言語") }
    var quit: String { t("Quit", "종료", "終了") }
    var labelLeft: String { t("Left", "왼쪽", "左") }
    var labelRight: String { t("Right", "오른쪽", "右") }
    var labelCase: String { t("Case", "케이스", "ケース") }
    var notifTitle: String { t("Low Battery", "배터리 부족", "バッテリー残量低下") }

    func threshold(_ n: Int) -> String { t("Below \(n)%", "\(n)% 이하", "\(n)% 以下") }
    func updated(_ time: String) -> String { t("Updated \(time)", "업데이트 \(time)", "更新 \(time)") }
    func notifBody(_ device: String, _ level: Int) -> String {
        t("\(device) battery is at \(level)%.",
          "\(device) 배터리가 \(level)% 입니다.",
          "\(device) のバッテリーは \(level)% です。")
    }
}

// MARK: - Model

/// A single connected Bluetooth device with any battery readings it exposes.
struct BTDevice: Identifiable {
    let id: String          // device address (stable) or name fallback
    let name: String
    let minorType: String?
    let main: Int?          // single-battery devices (keyboard, mouse, ...)
    let caseLevel: Int?     // AirPods case
    let left: Int?          // AirPods left bud
    let right: Int?         // AirPods right bud

    /// All battery readings this device reports, lowest first is not assumed.
    var levels: [Int] {
        [main, caseLevel, left, right].compactMap { $0 }
    }

    var hasBattery: Bool { !levels.isEmpty }

    /// The lowest reading, used for at-a-glance status.
    var lowest: Int? { levels.min() }

    /// Combines two readings of the same device, keeping any battery value the
    /// other one is missing and the richer name/type.
    func merged(with other: BTDevice) -> BTDevice {
        BTDevice(
            id: id,
            name: other.levels.count > levels.count ? other.name : name,
            minorType: minorType ?? other.minorType,
            main: main ?? other.main,
            caseLevel: caseLevel ?? other.caseLevel,
            left: left ?? other.left,
            right: right ?? other.right
        )
    }
}

private func parsePercent(_ value: Any?) -> Int? {
    guard let s = value as? String else { return nil }
    let cleaned = s.replacingOccurrences(of: "%", with: "")
        .trimmingCharacters(in: .whitespaces)
    return Int(cleaned)
}

/// Runs `system_profiler` and parses the connected-device battery data.
func fetchDevices() -> [BTDevice] {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    task.arguments = ["SPBluetoothDataType", "-json"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()

    do {
        try task.run()
    } catch {
        return []
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()

    guard
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let sections = root["SPBluetoothDataType"] as? [[String: Any]]
    else { return [] }

    // system_profiler can transiently list the same device (same address) twice —
    // e.g. right after AirPods connect, one entry with only the case and another
    // with all buds. Merge by id, coalescing each battery reading, so a device
    // never appears as duplicate rows (which would also collide in ForEach's id).
    var byId: [String: BTDevice] = [:]
    var order: [String] = []
    for section in sections {
        guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
        for entry in connected {
            // Each entry is a single-key dict: { "<device name>": { props... } }
            for (name, raw) in entry {
                guard let props = raw as? [String: Any] else { continue }
                let address = (props["device_address"] as? String) ?? name
                let incoming = BTDevice(
                    id: address,
                    name: name,
                    minorType: props["device_minorType"] as? String,
                    main: parsePercent(props["device_batteryLevelMain"]),
                    caseLevel: parsePercent(props["device_batteryLevelCase"]),
                    left: parsePercent(props["device_batteryLevelLeft"]),
                    right: parsePercent(props["device_batteryLevelRight"])
                )
                if let existing = byId[address] {
                    byId[address] = existing.merged(with: incoming)
                } else {
                    byId[address] = incoming
                    order.append(address)
                }
            }
        }
    }
    let devices = order.compactMap { byId[$0] }

    // Devices with a battery first, then the rest; each group sorted by name.
    return devices.sorted {
        if $0.hasBattery != $1.hasBattery { return $0.hasBattery }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
}

/// Observable store that periodically refreshes the device list.
@MainActor
final class DeviceStore: ObservableObject {
    /// Shared instance. MenuBarExtra hosts its `label:` and `content:` in separate
    /// environments, so a per-App @StateObject would be created twice — one for the
    /// icon and a second, empty one for the popover. A singleton keeps them in sync.
    static let shared = DeviceStore()

    @Published var devices: [BTDevice] = []
    @Published var lastUpdated: Date? = nil
    @Published var isLoading = false

    // User settings, persisted in UserDefaults.
    @Published var alertsEnabled: Bool {
        didSet { UserDefaults.standard.set(alertsEnabled, forKey: "alertsEnabled") }
    }
    @Published var alertThreshold: Int {
        didSet { UserDefaults.standard.set(alertThreshold, forKey: "alertThreshold") }
    }
    @Published var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") }
    }

    /// Localized strings for the current language.
    var l10n: L10n { L10n(lang: lang) }

    private var timer: Timer?

    /// Keys (device+component) currently in the "already alerted" state, so we
    /// notify once per crossing rather than every refresh.
    private var alertedKeys: Set<String> = []

    init() {
        let defaults = UserDefaults.standard
        // `object(forKey:)` distinguishes "unset" (default true) from an explicit false.
        alertsEnabled = defaults.object(forKey: "alertsEnabled") as? Bool ?? true
        let saved = defaults.integer(forKey: "alertThreshold")
        alertThreshold = saved == 0 ? 20 : saved
        // Default to English when unset.
        lang = Lang(rawValue: defaults.string(forKey: "lang") ?? "") ?? .en
        start()
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let result = fetchDevices()
            await MainActor.run {
                self.devices = result
                self.lastUpdated = Date()
                self.isLoading = false
                self.checkLowBattery(result)
            }
        }
    }

    /// Posts a notification the first time a battery drops to/below the threshold,
    /// and re-arms once it recovers a little above it (hysteresis of 5%).
    private func checkLowBattery(_ devices: [BTDevice]) {
        guard alertsEnabled else { alertedKeys.removeAll(); return }
        let strings = l10n
        // (stable id for the dedup key, localized display label, value)
        for device in devices {
            let components: [(String, String, Int?)] = [
                ("main", "", device.main),
                ("case", strings.labelCase, device.caseLevel),
                ("left", strings.labelLeft, device.left),
                ("right", strings.labelRight, device.right),
            ]
            for (compId, label, value) in components {
                guard let level = value else { continue }
                let key = device.id + "/" + compId
                if level <= alertThreshold {
                    if !alertedKeys.contains(key) {
                        alertedKeys.insert(key)
                        let where_ = label.isEmpty ? device.name : "\(device.name) (\(label))"
                        Notifier.shared.postLowBattery(
                            title: strings.notifTitle,
                            body: strings.notifBody(where_, level))
                    }
                } else if level >= alertThreshold + 5 {
                    alertedKeys.remove(key)   // recovered — re-arm
                }
            }
        }
    }

    /// Lowest battery across all devices, for the menu bar glyph.
    var overallLowest: Int? {
        devices.compactMap { $0.lowest }.min()
    }
}

// MARK: - Notifications

/// Wraps UserNotifications for low-battery alerts.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private var authorized = false

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            self.authorized = granted
        }
    }

    func postLowBattery(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Show the banner even though the app is a menu-bar (never "frontmost") app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Login item

/// Thin wrapper over SMAppService for "launch at login".
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItem toggle failed: \(error)")
        }
    }
}

// MARK: - Helpers

private func batteryColor(_ level: Int) -> Color {
    switch level {
    case ..<20: return .red
    case ..<50: return .orange
    default: return .green
    }
}

/// Picks an SF Symbol for a device based on its name / minor type.
private func deviceIcon(_ device: BTDevice) -> String {
    let hay = (device.name + " " + (device.minorType ?? "")).lowercased()
    if hay.contains("airpod") || hay.contains("headphone") || hay.contains("earbud") || hay.contains("buds") {
        return "airpodspro"
    }
    if hay.contains("keyboard") { return "keyboard" }
    if hay.contains("trackpad") { return "trackpad.fill" }
    if hay.contains("mouse") { return "computermouse.fill" }
    if hay.contains("watch") { return "applewatch" }
    if hay.contains("pencil") { return "applepencil" }
    if hay.contains("speaker") { return "hifispeaker.fill" }
    if hay.contains("game") || hay.contains("controller") { return "gamecontroller.fill" }
    return "dot.radiowaves.left.and.right"
}

/// SF Symbol name for a battery fill level.
private func batterySymbol(_ level: Int?) -> String {
    guard let level = level else { return "battery.0" }
    switch level {
    case ..<13: return "battery.0"
    case ..<38: return "battery.25"
    case ..<63: return "battery.50"
    case ..<88: return "battery.75"
    default: return "battery.100"
    }
}

// MARK: - Views

struct BatteryPill: View {
    let label: String?   // e.g. "L", "R", "Case", or nil for a single reading
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .leading)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(batteryColor(level))
                    .frame(width: max(4, 34 * CGFloat(level) / 100))
            }
            .frame(width: 34, height: 7)
            Text("\(level)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(minWidth: 34, alignment: .trailing)
        }
    }
}

struct DeviceRow: View {
    let device: BTDevice
    let l10n: L10n

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: deviceIcon(device))
                .font(.system(size: 15))
                .frame(width: 22)
                .foregroundStyle(.primary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if device.hasBattery {
                    // AirPods-style multi-battery layout, else a single pill.
                    if device.left != nil || device.right != nil || device.caseLevel != nil {
                        VStack(alignment: .leading, spacing: 3) {
                            if let l = device.left { BatteryPill(label: l10n.labelLeft, level: l) }
                            if let r = device.right { BatteryPill(label: l10n.labelRight, level: r) }
                            if let c = device.caseLevel { BatteryPill(label: l10n.labelCase, level: c) }
                            if let m = device.main { BatteryPill(label: nil, level: m) }
                        }
                    } else if let m = device.main {
                        BatteryPill(label: nil, level: m)
                    }
                } else {
                    Text(l10n.noBattery)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
    }
}

struct ContentView: View {
    @ObservedObject var store: DeviceStore
    @State private var launchAtLogin = LoginItem.isEnabled

    private var timeText: String {
        guard let d = store.lastUpdated else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }

    var body: some View {
        let l = store.l10n
        return VStack(spacing: 0) {
            // Header
            HStack {
                Text(l.header)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { store.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help(l.refresh)
                .disabled(store.isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Device list
            if store.devices.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: store.isLoading ? "hourglass" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    Text(store.isLoading ? l.loading : l.noDevices)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                // A plain VStack sizes to its content; a ScrollView has no intrinsic
                // height and would collapse to zero inside the self-sizing popover.
                VStack(spacing: 0) {
                    ForEach(Array(store.devices.enumerated()), id: \.element.id) { index, device in
                        DeviceRow(device: device, l10n: l)
                        if index < store.devices.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }

            Divider()

            // Settings
            VStack(spacing: 8) {
                Toggle(isOn: $launchAtLogin) {
                    Text(l.launchAtLogin).font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItem.set(newValue)
                    launchAtLogin = LoginItem.isEnabled   // reflect actual state
                }

                HStack {
                    Toggle(isOn: $store.alertsEnabled) {
                        Text(l.lowBatteryAlert).font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    Spacer()
                    Menu("\(store.alertThreshold)%") {
                        ForEach([10, 15, 20, 30, 40], id: \.self) { t in
                            Button(l.threshold(t)) { store.alertThreshold = t }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .font(.system(size: 12))
                    .disabled(!store.alertsEnabled)
                }

                HStack {
                    Text(l.language).font(.system(size: 12))
                    Spacer()
                    Menu(store.lang.displayName) {
                        ForEach(Lang.allCases) { lang in
                            Button(lang.displayName) { store.lang = lang }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Footer
            HStack {
                Text(l.updated(timeText))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(l.quit) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 288)
    }
}

// MARK: - App

@main
struct BluetoothBatteriesApp: App {
    @ObservedObject private var store = DeviceStore.shared

    init() {
        Notifier.shared.requestAuthorization()
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
                .onAppear { store.refresh() }
        } label: {
            if let low = store.overallLowest {
                Image(systemName: batterySymbol(low))
                Text("\(low)%")
            } else {
                Image(systemName: batterySymbol(nil))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
