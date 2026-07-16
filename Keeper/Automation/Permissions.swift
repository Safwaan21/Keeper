import AppKit
import ApplicationServices

@MainActor
final class Permissions: ObservableObject {
    @Published private(set) var accessibility = false
    private var timer: Timer?

    init() {
        refresh()
        timer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }
    func refresh() { accessibility = AXIsProcessTrusted() }

    func request() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        refresh()
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
