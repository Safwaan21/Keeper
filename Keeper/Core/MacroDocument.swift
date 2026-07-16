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

struct RunSchedule: Codable, Hashable {
    var enabled = true
    var time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    var weekdays: Set<Int> = []
    var lastRun: Date?

    var description: String {
        let timeText = time.formatted(date: .omitted, time: .shortened)
        guard !weekdays.isEmpty else { return "Every day at \(timeText)" }
        let names = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().map { names[$0 - 1] }.joined(separator: ", ") + " at \(timeText)"
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
