import AppKit
import Foundation

@MainActor
final class MacroScheduler: ObservableObject {
    @Published private(set) var isPaused: Bool
    @Published private(set) var currentMacroName: String?
    @Published private(set) var statusMessage = "Automation ready"

    private weak var library: MacroLibrary?
    private weak var player: MacroPlayer?
    private weak var settings: KeeperSettings?
    private var timer: Timer?
    private var graceUntil = Date.distantPast
    private let activityMonitor = UserActivityMonitor()
    private let shortcutMonitor = GlobalShortcutMonitor()
    private let session = SessionMonitor()
    private let notifier = AutomationNotifier()

    init() {
        isPaused = UserDefaults.standard.bool(forKey: "automationPaused")
    }

    func start(library: MacroLibrary, player: MacroPlayer, settings: KeeperSettings) {
        self.library = library; self.player = player; self.settings = settings
        timer?.invalidate()
        timer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        activityMonitor.start { [weak self] in self?.handleHumanActivity() }
        shortcutMonitor.start(settings: settings) { [weak self] in self?.pauseAll(reason: "Emergency shortcut") }
        if settings.notificationsEnabled { notifier.requestAuthorization() }
        tick()
    }

    var nextScheduledRun: (name: String, date: Date)? {
        library?.documents.compactMap { macro -> (String, Date)? in
            guard let schedule = macro.schedule, schedule.enabled,
                  let date = schedule.nextRun ?? schedule.nextOccurrence(after: .now, includingDate: true) else { return nil }
            return (macro.name, date)
        }.min { $0.1 < $1.1 }
    }

    var hasEnabledSchedules: Bool {
        library?.documents.contains { $0.schedule?.enabled == true } == true
    }

    func resume() {
        isPaused = false
        UserDefaults.standard.set(false, forKey: "automationPaused")
        graceUntil = .now.addingTimeInterval(30)
        statusMessage = "Automation active"
        tick()
    }

    func pauseAll(reason: String = "Paused manually") {
        guard !isPaused || player?.isPlaying == true else { return }
        player?.stop(); currentMacroName = nil; isPaused = true
        UserDefaults.standard.set(true, forKey: "automationPaused")
        statusMessage = reason
        notifier.send(title: "Keeper paused", body: reason, enabled: settings?.notificationsEnabled == true)
    }

    func stopCurrent() {
        guard player?.isPlaying == true else { return }
        player?.stop(); currentMacroName = nil; statusMessage = "Current run stopped"
    }

    private func handleHumanActivity() {
        guard settings?.pauseOnActivity == true, hasEnabledSchedules, !isPaused,
              Date.now >= graceUntil, !NSApp.isActive else { return }
        pauseAll(reason: "Paused because activity was detected")
    }

    private func tick() {
        guard let library, let player else { return }
        if currentMacroName != nil, !player.isPlaying { currentMacroName = nil }
        guard !isPaused else { return }
        let now = Date.now

        for macro in library.documents {
            guard var schedule = macro.schedule, schedule.enabled else { continue }
            let due = schedule.nextRun ?? schedule.nextOccurrence(after: now, includingDate: true)
            guard let due else { library.advanceSchedule(macro.id, nextRun: nil); continue }
            if schedule.nextRun == nil { library.advanceSchedule(macro.id, nextRun: due) }
            guard due <= now else { continue }

            let next = nextDate(after: now, schedule: schedule, didRun: false)
            if now.timeIntervalSince(due) > 5 {
                library.advanceSchedule(macro.id, nextRun: next)
                statusMessage = "Skipped a missed run of \(macro.name)"
                notifier.send(title: "Run skipped", body: "\(macro.name) missed its scheduled time.", enabled: settings?.notificationsEnabled == true)
                continue
            }
            guard session.isAvailable else {
                library.advanceSchedule(macro.id, nextRun: next)
                notifier.send(title: "Run skipped", body: "\(macro.name) could not run while the session was unavailable.", enabled: settings?.notificationsEnabled == true)
                continue
            }
            guard !player.isPlaying else {
                library.advanceSchedule(macro.id, nextRun: next)
                statusMessage = "Skipped an overlapping run of \(macro.name)"
                notifier.send(title: "Run skipped", body: "\(macro.name) was still busy at its next interval.", enabled: settings?.notificationsEnabled == true)
                continue
            }

            schedule.completedRuns += 1
            let nextAfterRun = nextDate(after: now, schedule: schedule, didRun: true)
            library.updateScheduleRun(macro.id, at: now, nextRun: nextAfterRun)
            currentMacroName = macro.name; statusMessage = "Running \(macro.name)"
            player.play(macro, library: library)
            break
        }
    }

    private func nextDate(after date: Date, schedule: RunSchedule, didRun: Bool) -> Date? {
        var updated = schedule
        if didRun { updated.completedRuns = schedule.completedRuns }
        return updated.nextOccurrence(after: date)
    }
}
