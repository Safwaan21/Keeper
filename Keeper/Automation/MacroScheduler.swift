import Foundation

@MainActor
final class MacroScheduler {
    private var timer: Timer?

    func start(library: MacroLibrary, player: MacroPlayer) {
        timer?.invalidate()
        timer = .scheduledTimer(withTimeInterval: 15, repeats: true) { [weak library, weak player] _ in
            Task { @MainActor in
                guard let library, let player, !player.isPlaying else { return }
                let now = Date.now, calendar = Calendar.current
                for macro in library.documents {
                    guard let schedule = macro.schedule, schedule.enabled, !macro.steps.isEmpty else { continue }
                    let weekday = calendar.component(.weekday, from: now)
                    guard schedule.weekdays.isEmpty || schedule.weekdays.contains(weekday) else { continue }
                    let target = calendar.dateComponents([.hour, .minute], from: schedule.time)
                    let current = calendar.dateComponents([.hour, .minute], from: now)
                    guard target.hour == current.hour, target.minute == current.minute else { continue }
                    if let last = schedule.lastRun, calendar.isDate(last, equalTo: now, toGranularity: .minute) { continue }
                    library.markScheduleRun(macro.id, at: now); player.play(macro); break
                }
            }
        }
    }
}
