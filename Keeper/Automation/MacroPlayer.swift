import AppKit
import CoreGraphics

@MainActor
final class MacroPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentStep: UUID?
    @Published private(set) var progress: Double = 0
    private var task: Task<Void, Never>?

    func play(_ macro: MacroDocument) {
        stop()
        guard !macro.steps.isEmpty else { return }
        isPlaying = true
        task = Task { [weak self] in
            let ordered = macro.steps.sorted { $0.offset < $1.offset }
            var previous: TimeInterval = 0
            for step in ordered {
                guard !Task.isCancelled else { break }
                let delay = max(0, step.offset - previous) / max(macro.playbackRate, 0.1)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }
                Self.post(step)
                self?.currentStep = step.id
                self?.progress = macro.duration == 0 ? 1 : step.offset / macro.duration
                previous = step.offset
            }
            self?.isPlaying = false; self?.currentStep = nil; self?.task = nil
        }
    }

    func stop() {
        task?.cancel(); task = nil; isPlaying = false; currentStep = nil; progress = 0
    }

    private static func post(_ step: MacroStep) {
        switch step.kind {
        case .application:
            guard let id = step.bundleID else { return }
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                running.activate(options: [.activateAllWindows]); return
            }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
            let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        case .pointerMove:
            guard let point = step.point else { return }
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        case .mouseDown, .mouseUp:
            guard let point = step.point else { return }
            let button = CGMouseButton(rawValue: UInt32(step.button ?? 0)) ?? .left
            let type: CGEventType
            switch (step.kind, step.button ?? 0) {
            case (.mouseDown, 1): type = .rightMouseDown
            case (.mouseUp, 1): type = .rightMouseUp
            case (.mouseDown, 2...): type = .otherMouseDown
            case (.mouseUp, 2...): type = .otherMouseUp
            case (.mouseDown, _): type = .leftMouseDown
            default: type = .leftMouseUp
            }
            let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)
            event?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(step.button ?? 0)); event?.post(tap: .cghidEventTap)
        case .keyDown, .keyUp:
            guard let code = step.keyCode else { return }
            let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: step.kind == .keyDown)
            if let flags = step.eventFlags { event?.flags = CGEventFlags(rawValue: flags) }
            event?.post(tap: .cghidEventTap)
        }
    }
}

private extension MacroStep {
    var point: CGPoint? {
        guard let pointX, let pointY else { return nil }
        return CGPoint(x: pointX, y: pointY)
    }
}
