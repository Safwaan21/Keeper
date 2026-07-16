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

Schedules run while Keeper is open. Reliable execution while the app is closed requires a separately installed launch agent, which is intentionally not installed without explicit user consent.
