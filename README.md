# Keeper

Keeper is a native macOS macro recorder and sequence editor built with SwiftUI, AppKit, and Core Graphics.

Recorded events are presented as expandable action blocks. Blocks can be reordered by dragging, copied or duplicated from their context menu, and composed by adding another macro. Keeper rejects both direct and indirect recursive macro references.

## Run

Open `Keeper.xcodeproj` and run the `Keeper` scheme. On first use, grant Keeper access in **System Settings → Privacy & Security → Accessibility**. macOS may require restarting Keeper after granting access.

## Structure

- `Core` contains the portable macro document and JSON-backed library.
- `Automation` owns event capture, playback, permissions, and in-process scheduling.
- `DesignSystem` contains the visual tokens and reusable surfaces.
- `Features` contains the library, sequence editor, capture controls, and inspector.

Schedules use a fixed interval from their configured start time. Missed and overlapping runs are skipped, and automation pauses when human input is detected by default. The Mac must remain awake and the user session unlocked for UI automation to work.

Keeper remains active from its menu-bar item when the main window is closed. `Keeper → Settings…` controls the emergency shortcut, activity detection, notifications, and launch at login. Login-item registration requires a normally signed app build; unsigned local Release builds report the macOS registration error in Settings.
