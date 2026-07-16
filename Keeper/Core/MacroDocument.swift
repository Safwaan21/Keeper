import Foundation

enum CaptureKind: String, Codable, CaseIterable, Identifiable {
    case pointerMove, mouseDown, mouseUp, keyDown, keyUp, application, macro

    var id: Self { self }
    var title: String {
        switch self {
        case .pointerMove: "Move pointer"
        case .mouseDown: "Mouse down"
        case .mouseUp: "Mouse up"
        case .keyDown: "Key down"
        case .keyUp: "Key up"
        case .application: "Focus app"
        case .macro: "Run macro"
        }
    }
    var symbol: String {
        switch self {
        case .pointerMove: "cursorarrow.motionlines"
        case .mouseDown, .mouseUp: "computermouse"
        case .keyDown, .keyUp: "keyboard"
        case .application: "macwindow.on.rectangle"
        case .macro: "command.square"
        }
    }
}

struct MacroStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var offset: TimeInterval
    var kind: CaptureKind
    var pointX: Double?
    var pointY: Double?
    var button: Int?
    var keyCode: Int?
    var eventFlags: UInt64?
    var text: String?
    var bundleID: String?
    var appName: String?
    var referencedMacroID: UUID?
    var referencedMacroName: String?

    var detail: String {
        switch kind {
        case .pointerMove: "\(Int(pointX ?? 0)), \(Int(pointY ?? 0))"
        case .mouseDown: "Button \((button ?? 0) + 1) pressed"
        case .mouseUp: "Button \((button ?? 0) + 1) released"
        case .keyDown: text?.isEmpty == false ? "\(text!) pressed" : "Key \(keyCode ?? 0) pressed"
        case .keyUp: text?.isEmpty == false ? "\(text!) released" : "Key \(keyCode ?? 0) released"
        case .application: appName ?? bundleID ?? "Unknown app"
        case .macro: referencedMacroName ?? "Missing macro"
        }
    }
}

enum BlockFamily: Hashable {
    case pointer, clicks, keyboard, application, macro(UUID?)

    var title: String {
        switch self {
        case .pointer: "Pointer movements"
        case .clicks: "Mouse clicks"
        case .keyboard: "Keyboard input"
        case .application: "Application focus"
        case .macro: "Nested macro"
        }
    }
    var symbol: String {
        switch self {
        case .pointer: "cursorarrow.motionlines"
        case .clicks: "computermouse"
        case .keyboard: "keyboard"
        case .application: "macwindow.on.rectangle"
        case .macro: "command.square"
        }
    }
}

struct ActionBlock: Identifiable, Hashable {
    var id: UUID { steps[0].id }
    let family: BlockFamily
    var steps: [MacroStep]
    var start: TimeInterval { steps.first?.offset ?? 0 }
    var duration: TimeInterval { max(0, (steps.last?.offset ?? start) - start) }
}

extension MacroStep {
    var blockFamily: BlockFamily {
        switch kind {
        case .pointerMove: .pointer
        case .mouseDown, .mouseUp: .clicks
        case .keyDown, .keyUp: .keyboard
        case .application: .application
        case .macro: .macro(referencedMacroID)
        }
    }
}

struct CaptureSettings: Codable, Hashable {
    var pointerMovement = true
    var mouseClicks = true
    var keyboard = true
    var applications = true
    var movementPrecision = 3.0

    var hasSelection: Bool { pointerMovement || mouseClicks || keyboard || applications }
}

enum ScheduleStopRule: String, Codable, CaseIterable, Identifiable {
    case never, date, runCount
    var id: Self { self }
    var title: String {
        switch self {
        case .never: "Never"
        case .date: "At a date"
        case .runCount: "After runs"
        }
    }
}

struct RunSchedule: Codable, Hashable {
    var enabled = true
    var startsAt = Date.now.addingTimeInterval(60)
    var intervalMinutes = 10
    var stopRule = ScheduleStopRule.never
    var endsAt = Date.now.addingTimeInterval(3_600)
    var maximumRuns = 10
    var completedRuns = 0
    var lastRun: Date?
    var nextRun: Date?

    var description: String {
        "Every \(intervalMinutes) min from \(startsAt.formatted(date: .abbreviated, time: .shortened))"
    }

    func nextOccurrence(after date: Date, includingDate: Bool = false) -> Date? {
        let interval = TimeInterval(max(intervalMinutes, 1) * 60)
        var candidate = startsAt
        if candidate < date || (!includingDate && candidate == date) {
            let elapsed = max(0, date.timeIntervalSince(startsAt))
            let periods = floor(elapsed / interval) + (includingDate && elapsed.truncatingRemainder(dividingBy: interval) == 0 ? 0 : 1)
            candidate = startsAt.addingTimeInterval(periods * interval)
        }
        switch stopRule {
        case .never: break
        case .date where candidate > endsAt: return nil
        case .runCount where completedRuns >= max(maximumRuns, 1): return nil
        default: break
        }
        return candidate
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, startsAt, intervalMinutes, stopRule, endsAt, maximumRuns
        case completedRuns, lastRun, nextRun
        // Legacy schedule keys.
        case time, weekdays
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        startsAt = try values.decodeIfPresent(Date.self, forKey: .startsAt)
            ?? values.decodeIfPresent(Date.self, forKey: .time)
            ?? Date.now.addingTimeInterval(60)
        intervalMinutes = try values.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 10
        stopRule = try values.decodeIfPresent(ScheduleStopRule.self, forKey: .stopRule) ?? .never
        endsAt = try values.decodeIfPresent(Date.self, forKey: .endsAt) ?? startsAt.addingTimeInterval(3_600)
        maximumRuns = try values.decodeIfPresent(Int.self, forKey: .maximumRuns) ?? 10
        completedRuns = try values.decodeIfPresent(Int.self, forKey: .completedRuns) ?? 0
        lastRun = try values.decodeIfPresent(Date.self, forKey: .lastRun)
        nextRun = try values.decodeIfPresent(Date.self, forKey: .nextRun)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(enabled, forKey: .enabled)
        try values.encode(startsAt, forKey: .startsAt)
        try values.encode(intervalMinutes, forKey: .intervalMinutes)
        try values.encode(stopRule, forKey: .stopRule)
        try values.encode(endsAt, forKey: .endsAt)
        try values.encode(maximumRuns, forKey: .maximumRuns)
        try values.encode(completedRuns, forKey: .completedRuns)
        try values.encodeIfPresent(lastRun, forKey: .lastRun)
        try values.encodeIfPresent(nextRun, forKey: .nextRun)
    }
}

struct MacroDocument: Identifiable, Codable, Hashable {
    var id = UUID()
    var name = "Untitled macro"
    var createdAt = Date.now
    var modifiedAt = Date.now
    var settings = CaptureSettings()
    var steps: [MacroStep] = []
    var schedule: RunSchedule?
    var playbackRate = 1.0

    var duration: TimeInterval { steps.map(\.offset).max() ?? 0 }

    var blocks: [ActionBlock] {
        var result: [ActionBlock] = []
        for step in steps {
            let family = step.blockFamily
            if family != .macro(step.referencedMacroID), result.last?.family == family {
                result[result.count - 1].steps.append(step)
            } else {
                result.append(ActionBlock(family: family, steps: [step]))
            }
        }
        return result
    }
}
