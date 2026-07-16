import SwiftUI

enum Theme {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .underPageBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let raised = Color(nsColor: .textBackgroundColor)
    static let line = Color.primary.opacity(0.085)
    static let muted = Color.secondary.opacity(0.72)
    static let recording = Color(red: 0.92, green: 0.20, blue: 0.18)
    static let radius: CGFloat = 12
    static let smallRadius: CGFloat = 8
}

struct Panel: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line))
    }
}

extension View {
    func panel(padding: CGFloat = 16) -> some View { modifier(Panel(padding: padding)) }
}

extension TimeInterval {
    var formattedElapsed: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let hundredths = Int((self * 100).truncatingRemainder(dividingBy: 100))
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}

struct SymbolButton: View {
    let symbol: String
    var help = ""
    var active = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 28, height: 28)
                .background(active ? Color.primary : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(active ? Theme.canvas : .primary)
        }
        .buttonStyle(.plain).help(help)
    }
}

struct EmptyPlaceholder: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(message).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 280)
        }
    }
}
