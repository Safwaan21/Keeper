import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: KeeperSettings
    @EnvironmentObject private var scheduler: MacroScheduler

    var body: some View {
        TabView {
            Form {
                Section("Startup") {
                    Toggle("Launch Keeper at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    if let error = settings.loginItemError {
                        Text(error).font(.caption).foregroundStyle(Theme.recording)
                    }
                }
                Section("Notifications") {
                    Toggle("Show automation notifications", isOn: $settings.notificationsEnabled)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("Safety") {
                    Toggle("Pause scheduled automation when activity is detected", isOn: $settings.pauseOnActivity)
                    Text("Keeper ignores its own generated input. Activity detection begins 30 seconds after automation is resumed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Emergency shortcut") {
                    Picker("Pause all automation", selection: $settings.shortcut) {
                        ForEach(EmergencyShortcut.allCases) { shortcut in Text(shortcut.title).tag(shortcut) }
                    }
                    Text("The shortcut stops the current run and prevents future scheduled runs until you resume.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    HStack {
                        Text(scheduler.isPaused ? "Automation is paused" : "Automation is active")
                        Spacer()
                        Button(scheduler.isPaused ? "Resume" : "Pause") {
                            scheduler.isPaused ? scheduler.resume() : scheduler.pauseAll()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Automation", systemImage: "bolt.shield") }
        }
        .frame(width: 520, height: 390)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var scheduler: MacroScheduler
    @EnvironmentObject private var settings: KeeperSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let current = scheduler.currentMacroName {
            Text("Running \(current)")
            Button("Stop Current Run") { scheduler.stopCurrent() }
        } else if let next = scheduler.nextScheduledRun {
            Text("Next: \(next.name)")
            Text(next.date.formatted(date: .abbreviated, time: .shortened))
        } else {
            Text("No scheduled runs")
        }
        Text(scheduler.statusMessage)
        Divider()
        Button(scheduler.isPaused ? "Resume Automation" : "Pause All Automation") {
            scheduler.isPaused ? scheduler.resume() : scheduler.pauseAll()
        }
        Text("Emergency stop: \(settings.shortcut.title)")
        Divider()
        Button("Open Keeper") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Keeper") { NSApp.terminate(nil) }
    }
}
