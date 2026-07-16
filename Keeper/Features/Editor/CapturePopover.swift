import SwiftUI

struct CapturePopover: View {
    @Binding var settings: CaptureSettings
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("New recording").font(.system(size: 15, weight: .semibold))
                Text("Choose what Keeper should capture.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            VStack(spacing: 1) {
                CaptureToggle("Pointer movement", symbol: "cursorarrow.motionlines", value: $settings.pointerMovement)
                CaptureToggle("Mouse clicks", symbol: "computermouse", value: $settings.mouseClicks)
                CaptureToggle("Keyboard input", symbol: "keyboard", value: $settings.keyboard)
                CaptureToggle("Application focus", symbol: "macwindow.on.rectangle", value: $settings.applications)
            }
            Button(action: start) {
                Label("Start recording", systemImage: "record.circle").font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 30)
            }
            .buttonStyle(.borderedProminent).tint(.primary).disabled(!settings.hasSelection)
            Text("Press ⌘. to stop recording").font(.system(size: 10)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
        }.padding(16).frame(width: 280)
    }
}

private struct CaptureToggle: View {
    let title: String, symbol: String
    @Binding var value: Bool
    init(_ title: String, symbol: String, value: Binding<Bool>) { self.title = title; self.symbol = symbol; self._value = value }
    var body: some View {
        Toggle(isOn: $value) {
            Label(title, systemImage: symbol).font(.system(size: 12)).symbolRenderingMode(.hierarchical)
        }.toggleStyle(.switch).controlSize(.mini).padding(.vertical, 6)
    }
}
