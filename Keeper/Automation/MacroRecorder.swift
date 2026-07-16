import AppKit
import CoreGraphics

@MainActor
final class MacroRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var stepCount = 0

    private var settings = CaptureSettings()
    private var steps: [MacroStep] = []
    private var startedAt = Date.now
    private var lastPoint: CGPoint?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retainedSelf: UnsafeMutableRawPointer?
    private var timer: Timer?
    private var workspaceObserver: NSObjectProtocol?

    func start(settings: CaptureSettings) -> Bool {
        guard !isRecording, settings.hasSelection else { return false }
        self.settings = settings; steps = []; stepCount = 0; elapsed = 0; lastPoint = nil; startedAt = .now
        guard installTap() else { return false }
        isRecording = true
        observeApplications()
        timer = .scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed = Date.now.timeIntervalSince(self?.startedAt ?? .now) }
        }
        return true
    }

    func stop() -> [MacroStep] {
        guard isRecording else { return [] }
        isRecording = false; timer?.invalidate(); timer = nil
        removeTap()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        workspaceObserver = nil
        return steps.sorted { $0.offset < $1.offset }
    }

    private func observeApplications() {
        guard settings.applications else { return }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self, self.isRecording,
                      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
                self.append(MacroStep(offset: self.offset, kind: .application,
                                      bundleID: app.bundleIdentifier, appName: app.localizedName))
            }
        }
    }

    private var offset: TimeInterval { Date.now.timeIntervalSince(startedAt) }
    private func append(_ step: MacroStep) { steps.append(step); stepCount = steps.count }

    private func installTap() -> Bool {
        var mask: CGEventMask = 0
        func include(_ type: CGEventType) { mask |= 1 << type.rawValue }
        if settings.pointerMovement { [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged].forEach(include) }
        if settings.mouseClicks { [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp].forEach(include) }
        if settings.keyboard { [.keyDown, .keyUp].forEach(include) }
        let retained = Unmanaged.passRetained(self); retainedSelf = retained.toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<MacroRecorder>.fromOpaque(context).takeUnretainedValue()
                owner.receive(type, event: event)
                return Unmanaged.passUnretained(event)
            }, userInfo: retainedSelf) else {
            retained.release(); retainedSelf = nil; return false
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    nonisolated private func receive(_ type: CGEventType, event: CGEvent) {
        let snapshot = EventSnapshot(type: type, point: event.location,
            button: Int(event.getIntegerValueField(.mouseEventButtonNumber)),
            keyCode: Int(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags.rawValue, text: event.characters)
        Task { @MainActor in self.capture(snapshot) }
    }

    private func capture(_ event: EventSnapshot) {
        guard isRecording else { return }
        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if let lastPoint, hypot(event.point.x - lastPoint.x, event.point.y - lastPoint.y) < settings.movementPrecision { return }
            lastPoint = event.point
            append(MacroStep(offset: offset, kind: .pointerMove, pointX: event.point.x, pointY: event.point.y))
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            append(MacroStep(offset: offset, kind: .mouseDown, pointX: event.point.x, pointY: event.point.y, button: event.button))
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            append(MacroStep(offset: offset, kind: .mouseUp, pointX: event.point.x, pointY: event.point.y, button: event.button))
        case .keyDown:
            append(MacroStep(offset: offset, kind: .keyDown, keyCode: event.keyCode, eventFlags: event.flags, text: event.text))
        case .keyUp:
            append(MacroStep(offset: offset, kind: .keyUp, keyCode: event.keyCode, eventFlags: event.flags, text: event.text))
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        default: break
        }
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
        if let retainedSelf { Unmanaged<MacroRecorder>.fromOpaque(retainedSelf).release() }
        retainedSelf = nil
    }
}

private struct EventSnapshot: Sendable {
    let type: CGEventType
    let point: CGPoint
    let button: Int
    let keyCode: Int
    let flags: UInt64
    let text: String?
}

private extension CGEvent {
    var characters: String? {
        var count = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &count, unicodeString: &buffer)
        return count == 0 ? nil : String(utf16CodeUnits: buffer, count: count)
    }
}
