import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class MacroPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentStep: UUID?
    @Published private(set) var progress: Double = 0
    private var task: Task<Void, Never>?

    func play(_ macro: MacroDocument, library: MacroLibrary) {
        stop()
        guard !macro.steps.isEmpty else { return }
        isPlaying = true
        let documents = library.documents
        task = Task { [weak self] in
            let ordered = Self.expanded(macro, documents: documents, baseOffset: 0, stack: [])
            let totalDuration = ordered.map(\.offset).max() ?? 0
            var previous: TimeInterval = 0
            for step in ordered {
                guard !Task.isCancelled else { break }
                let delay = max(0, step.offset - previous) / max(macro.playbackRate, 0.1)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }
                await Self.perform(step)
                self?.currentStep = step.id
                self?.progress = totalDuration == 0 ? 1 : step.offset / totalDuration
                previous = step.offset
            }
            self?.isPlaying = false; self?.currentStep = nil; self?.task = nil
        }
    }

    private static func expanded(
        _ macro: MacroDocument,
        documents: [MacroDocument],
        baseOffset: TimeInterval,
        stack: Set<UUID>
    ) -> [MacroStep] {
        guard !stack.contains(macro.id) else { return [] }
        var nextStack = stack; nextStack.insert(macro.id)
        var result: [MacroStep] = []
        var occupiedUntil = baseOffset
        for step in macro.steps {
            let scheduledOffset = max(baseOffset + step.offset, occupiedUntil)
            if step.kind == .macro, let childID = step.referencedMacroID,
               let child = documents.first(where: { $0.id == childID }) {
                let nested = expanded(child, documents: documents,
                    baseOffset: scheduledOffset, stack: nextStack)
                result += nested
                occupiedUntil = max(scheduledOffset, nested.map(\.offset).max() ?? scheduledOffset)
            } else {
                var copy = step; copy.offset = scheduledOffset
                result.append(copy)
                occupiedUntil = scheduledOffset
            }
        }
        return result.sorted { $0.offset < $1.offset }
    }

    func stop() {
        task?.cancel(); task = nil; isPlaying = false; currentStep = nil; progress = 0
    }

    private static func perform(_ step: MacroStep) async {
        switch step.kind {
        case .application:
            guard let id = step.bundleID else { return }
            await focusApplication(bundleID: id)
        case .pointerMove:
            guard let point = step.point else { return }
            let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
            postGenerated(event)
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
            event?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(step.button ?? 0)); postGenerated(event)
        case .keyDown, .keyUp:
            guard let code = step.keyCode else { return }
            let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: step.kind == .keyDown)
            if let flags = step.eventFlags { event?.flags = CGEventFlags(rawValue: flags) }
            postGenerated(event)
        case .macro:
            break
        }
    }

    private static func postGenerated(_ event: CGEvent?) {
        event?.setIntegerValueField(.eventSourceUserData, value: AutomationEventMarker.value)
        event?.post(tap: .cghidEventTap)
    }

    private static func focusApplication(bundleID: String) async {
        var application = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first

        // NSWorkspace activation is more reliable than NSRunningApplication when
        // Keeper is no longer the frontmost process or the target is on another Space.
        application = await activateThroughWorkspace(bundleID: bundleID) ?? application

        guard let application else { return }

        for attempt in 0..<4 {
            guard !Task.isCancelled else { return }
            application.unhide()
            application.activate(options: [.activateAllWindows])
            forceFrontmost(application)

            // Activation is asynchronous. Do not send the next input event to the old app.
            for _ in 0..<10 {
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID { return }
                try? await Task.sleep(for: .milliseconds(25))
            }

            if attempt == 1 {
                _ = await activateThroughWorkspace(bundleID: bundleID)
            }
        }
    }

    private static func activateThroughWorkspace(bundleID: String) async -> NSRunningApplication? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, _ in
                continuation.resume(returning: app)
            }
        }
    }

    private static func forceFrontmost(_ application: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetAttributeValue(
            appElement,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )

        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        ) == .success, let focusedWindow else { return }
        AXUIElementPerformAction(focusedWindow as! AXUIElement, kAXRaiseAction as CFString)
    }
}

private extension MacroStep {
    var point: CGPoint? {
        guard let pointX, let pointY else { return nil }
        return CGPoint(x: pointX, y: pointY)
    }
}
