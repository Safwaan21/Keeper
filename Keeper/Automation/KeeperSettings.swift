import AppKit
import ServiceManagement

enum EmergencyShortcut: String, CaseIterable, Identifiable {
    case commandOptionControlS
    case commandOptionControlPeriod
    case commandShiftEscape

    var id: Self { self }
    var title: String {
        switch self {
        case .commandOptionControlS: "⌃⌥⌘S"
        case .commandOptionControlPeriod: "⌃⌥⌘."
        case .commandShiftEscape: "⇧⌘⎋"
        }
    }
    var keyCode: UInt16 {
        switch self {
        case .commandOptionControlS: 1
        case .commandOptionControlPeriod: 47
        case .commandShiftEscape: 53
        }
    }
    var modifiers: NSEvent.ModifierFlags {
        switch self {
        case .commandOptionControlS, .commandOptionControlPeriod: [.command, .option, .control]
        case .commandShiftEscape: [.command, .shift]
        }
    }
}

@MainActor
final class KeeperSettings: ObservableObject {
    @Published var pauseOnActivity: Bool { didSet { defaults.set(pauseOnActivity, forKey: Keys.pauseOnActivity) } }
    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) } }
    @Published var shortcut: EmergencyShortcut { didSet { defaults.set(shortcut.rawValue, forKey: Keys.shortcut) } }
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var loginItemError: String?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let pauseOnActivity = "pauseOnActivity"
        static let notifications = "notificationsEnabled"
        static let shortcut = "emergencyShortcut"
    }

    init() {
        pauseOnActivity = defaults.object(forKey: Keys.pauseOnActivity) as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? true
        shortcut = EmergencyShortcut(rawValue: defaults.string(forKey: Keys.shortcut) ?? "") ?? .commandOptionControlS
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = error.localizedDescription
        }
    }
}
