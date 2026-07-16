import AppKit
import CoreGraphics
import UserNotifications

enum AutomationEventMarker {
    static let value: Int64 = 0x4B_45_45_50_45_52 // "KEEPER"
}

@MainActor
final class UserActivityMonitor {
    private var globalMonitor: Any?
    private var lastDelivery = Date.distantPast

    func start(onActivity: @escaping () -> Void) {
        stop()
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .mouseMoved]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            guard event.cgEvent?.getIntegerValueField(.eventSourceUserData) != AutomationEventMarker.value else { return }
            Task { @MainActor in
                guard let self, Date.now.timeIntervalSince(self.lastDelivery) > 1 else { return }
                self.lastDelivery = .now
                onActivity()
            }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
    }
}

@MainActor
final class GlobalShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start(settings: KeeperSettings, action: @escaping () -> Void) {
        stop()
        let handler: (NSEvent) -> Bool = { event in
            let expected = settings.shortcut.modifiers.intersection(.deviceIndependentFlagsMask)
            let actual = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == settings.shortcut.keyCode, actual == expected else { return false }
            action(); return true
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            Task { @MainActor in _ = handler(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event) ? nil : event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil; localMonitor = nil
    }
}

@MainActor
final class SessionMonitor: ObservableObject {
    @Published private(set) var isAvailable = true
    private var observers: [NSObjectProtocol] = []

    init() {
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any] {
            isAvailable = !(session["CGSSessionScreenIsLocked"] as? Bool ?? false)
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isAvailable = false }
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isAvailable = false }
        })
        for name in [NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.isAvailable = true }
            })
        }
    }
}

@MainActor
final class AutomationNotifier {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func send(title: String, body: String, enabled: Bool) {
        guard enabled else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
