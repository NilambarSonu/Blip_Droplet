# 50 — NATIVE BLIP PANEL IMPLEMENTATION & DROPPYKIT INTEGRATION

**Author**: Lead macOS SwiftUI & DroppyKit Engineer  
**Date**: October 19, 2026  
**Status**: COMPLETE & VERIFIED  
**Workspace Root**: `/Users/nilambarbehera/Documents/Projects/REA/blip-research/`  
**GitHub Repository**: `https://github.com/NilambarSonu/Blip_Droplet.git`  
**Commit**: `4992ab0`  

---

## 1. Overview

In Phase 3D, the Blip Droplet was re-architected to feature a persistent, native macOS floating panel. This panel serves as the primary interface for selecting and staging files to be sent to Android devices, completely eliminating reliance on the hover-dependent notch shelf.

---

## 2. DroppyKit Host Contract Audit & Approved APIs

DroppyKit v1.20.1 was thoroughly audited to determine sanctioned panel presentation APIs:

### 2.1 `DroppyPanelSurface`
- **Source**: `DroppyKit/DesignSystem/DroppyPanelSurface.swift`
- **Host Role**: Droppy's standard chrome for floating popovers, panels, and settings inspectors. Provides the exact Liquid Glass background with continuous rounded corners (`cornerRadius: 24pt`), dark macOS vibrancy, and border treatment.

### 2.2 `DroppyPanelActivation`
- **Source**: `DroppyKit/Support/DroppyPanelActivation.swift` (introduced in DroppyKit 1.15.0)
- **Host Role**: Manages panel focus without causing Droppy's notch shelf or other macOS applications to lose active application state abruptly.
- **Contract Methods**:
  - `DroppyPanelActivation.begin(for:returningTo:)`: Activates the panel and records the previously active window/app.
  - `DroppyPanelActivation.finish()`: Restores focus to the previous application or notch shelf upon panel dismissal.

### 2.3 `NSOpenPanel` File Picker Sanction
- **Host Role**: Droplets running in-process within Droppy inherit Droppy’s entitlements and sandbox boundaries. Presenting a standard `NSOpenPanel` as a sheet or independent modal dialog is fully supported by AppKit and DroppyKit.
- **Security-Scoped Access**: When a file is chosen via `NSOpenPanel`, security-scoped resource access (`startAccessingSecurityScopedResource()`) is immediately initiated, balanced, and stopped after staging completes.

---

## 3. Component Architecture

### 3.1 `BlipFloatingPanel` (`BlipPanelController.swift`)
```swift
final class BlipFloatingPanel: NSPanel {
    init(contentRect: NSRect, contentView: NSView) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        BlipPanelController.shared.closePanel()
    }
}
```

Key Traits:
- `.nonactivatingPanel`: Does not steal global focus aggressively, avoiding jarring app switches.
- `canBecomeKey = true`: Enables full keyboard navigation, text accessibility, and Escape key dismissal.
- `canBecomeMain = false`: Leaves Droppy or the user's primary application as the main window.
- `cancelOperation`: Maps the Escape key directly to `closePanel()`.

### 3.2 `BlipPanelController` (`BlipPanelController.swift`)
The singleton coordinator responsible for:
- **Anchored Top-Center Positioning**: Computes panel coordinates directly below the MacBook notch on `NSScreen.main`:
  ```swift
  let screenFrame = screen.frame
  let panelX = screenFrame.midX - (targetSize.width / 2.0)
  let panelY = screenFrame.maxY - 44.0 - targetSize.height
  ```
- **Lifecycle Management**: Toggles open/close state, creates the `NSHostingView(rootView: BlipSendPanelView)`, and coordinates `DroppyPanelActivation`.
- **`presentFilePicker()`**: Configures a dedicated `NSOpenPanel`:
  - `canChooseFiles = true`
  - `canChooseDirectories = false`
  - `allowsMultipleSelection = false`
  - `resolvesAliases = true`
  - Invokes `model.handleFileChosen(url: selectedURL)` upon user confirmation.

### 3.3 `BlipSendPanelView` (`BlipSendPanelView.swift`)
SwiftUI presentation surface implementing Droppy's Dark Liquid Glass design system:
- **Header**:
  - Blip icon with electric-blue glow pill
  - Title: "Blip" (weight: `.bold`)
  - Subtitle: "Send to your Android device"
  - Dismiss button: Circular quiet button with SF Symbol `xmark`
- **Main Interaction Area**:
  - **Empty State**:
    - Rounded container (`DroppyRadius.md`) with subtle border
    - SF Symbol `arrow.up.circle.fill`
    - "Drop a file here" / "Or choose one from your Mac"
    - Prominent `Choose File…` button styled with `DroppyAccentButtonStyle(color: electricBlue, size: .medium)`
    - Drop target with hover highlight (`isTargeted ? electricBlue : AdaptiveColors.subtleBorderAuto`)
  - **Validating State**:
    - Progress spinner with "Validating & Staging..." and non-blocking background task.
  - **Staged File State**:
    - File icon with badge
    - Real filename and byte size formatted via `ByteCountFormatter`
    - Short SHA-256 fingerprint prefix (`sha256: 7f8a...`)
    - "Staged locally" badge
    - Action buttons: "Change File" (clears staging) and "Continue in Blip" (with safety gate tooltip)
  - **Error State**:
    - Warning icon (`exclamationmark.triangle.fill`), non-technical error description, and "Try Again" action.
- **Footer**:
  - "Single file transfer" indicator
  - "Ready" status chip

---

## 4. Dual Input Processing via Shared Pipeline

Both the file picker and the drag target route into the single hardened validation engine in `FileDropModel.swift`:

```
[NSOpenPanel Selection] ---> handleFileChosen(url:) ---\
                                                       +---> stageAndValidate(url:opID:)
[In-Panel File Drop]    ---> handleDrop(providers:) ---/
```

### Defense Pipeline Applied to Both Methods:
1. **Security-Scoped Access**: Unlocks file access; ensures balanced `stopAccessingSecurityScopedResource()` on exit.
2. **Symlink / Alias Resolution**: Checks `isSymbolicLink`; resolves aliases safely without escaping sandbox.
3. **Directory Rejection**: Strictly rejects directories to preserve single-file transfer contract.
4. **Upfront Quota Validation**: Validates file size against `maxStagingBytes` (500 MB) BEFORE reading or copying.
5. **Storage Capacity Guard**: Verifies available partition capacity before destination allocation.
6. **Streaming SHA-256**: Reads file in 64 KB chunks via `FileHandle` to prevent memory spikes.
7. **MainActor Isolation**: Safely dispatches back to `MainActor` using immutable Sendable transfers.

---

## 5. Services Dispatch Safety Gate

As in Phase 3B/3C, live transmission to the Android device remains compiled out:
- `BLIP_DISPATCH_ENABLED` is undefined.
- `BlipServicesAdapter.isDispatchCompiledIn` evaluates to `false`.
- The "Continue in Blip" button remains disabled with the help message:
  *"Services dispatch compiled out in Phase 3 safety build"*.
- Zero background network calls or simulated transfers are performed.
