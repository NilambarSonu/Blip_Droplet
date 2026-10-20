# Report 61: Native macOS Window Controls and Draggable Blip Panel Architecture

**Date:** 2026-10-19  
**Phase:** Phase 3E  
**Component:** `BlipDroplet` (`BlipFloatingPanel`, `BlipPanelController`, `BlipSendPanelView`)  
**Repository:** [https://github.com/NilambarSonu/Blip_Droplet.git](https://github.com/NilambarSonu/Blip_Droplet.git)  
**Author:** Lead macOS AppKit & DroppyKit Systems Engineer  

---

## 1. Executive Summary

Phase 3D demonstrated successful end-to-end functionality on a physical MacBook Air:
- The floating Blip panel opens reliably from the Droppy notch.
- The panel stays open after moving away from the notch.
- Native file selection stages real files with correct quotas and MIME metadata.
- "Change File" and dismissal/reopening work as expected.

Phase 3E elevates the user experience and native macOS fidelity:
1. **Native Window Controls (Traffic Lights):** Replaced custom close button with real AppKit `standardWindowButton` controls on the top-left (Close, Miniaturize/Hide, Zoom).
2. **Draggable Panel:** Allowed native window dragging via `window.performDrag(with: event)` on the title bar, while preserving file-drop target areas.
3. **Position Persistence & Display Resilience:** Saved panel position across launches with intelligent clamping to screen `visibleFrame` and dynamic handling of display topology changes (e.g., monitor disconnects).
4. **Reset Position Action:** Added an accessible reset button to return the panel directly below the notch.
5. **Dark Opaque Material:** Resolved excessive glass transparency with a multi-layered dark base material (`.ultraDarkMaterial` + `.windowBackgroundColor.opacity(0.92)` + `DroppyPanelSurface.opacity(0.70)`).
6. **Strict Transfer Safety:** Retained compile-time gating (`BLIP_DISPATCH_ENABLED`) with explicit truthful user-facing messaging: *"File staged locally. Sending is not enabled in this test build."*

---

## 2. Native macOS Traffic Light Controls

### 2.1 AppKit Window Configuration

To host genuine macOS traffic lights rather than decorative SwiftUI mockups, `BlipFloatingPanel` adopts standard AppKit window style masks:

```swift
super.init(
    contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
    styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
```

Key characteristics:
- `.titled` + `.fullSizeContentView`: Instructs AppKit to instantiate the native `NSThemeFrame` window chrome while allowing the SwiftUI `contentView` to extend beneath it.
- `titleVisibility = .hidden` & `titlebarAppearsTransparent = true`: Suppresses default title text and gray bar styling while keeping standard buttons active.
- `isMovableByWindowBackground = false`: Prevents inadvertent drags when clicking buttons or interacting with the drop card.

### 2.2 Control Mapping & Accessible Behaviors

| Button | Standard AppKit Identifier | Target / Action | Behavior & Contract |
|---|---|---|---|
| **Red** | `.closeButton` | `#selector(handleClose)` | Invokes `onClose` closure, closing panel via `DroppyPanelActivation.end()` and restoring previous application key focus. |
| **Yellow** | `.miniaturizeButton` | `#selector(handleMiniaturize)` | **Honest Equivalent:** Standard macOS floating utility panels (`.floating` level) do not dock to the macOS Dock. The miniaturize action cleanly hides the panel back to the Droppy notch. |
| **Green** | `.zoomButton` | `#selector(handleZoom)` | Toggles between compact mode (380×320) and expanded mode (440×400) using smooth AppKit frame animation. |

### 2.3 Layout Clearance & Alignment

AppKit places the standard controls at `x: 14pt .. 68pt` in the window frame. To avoid overlap, `BlipSendPanelView` includes an explicit 58pt leading spacer:

```swift
HStack(spacing: DroppySpacing.sm) {
    // Clearance for top-left native AppKit traffic lights (Red, Yellow, Green)
    Spacer()
        .frame(width: 58)

    // Blip icon badge
    ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(electricBlue.opacity(0.18))
            .frame(width: 28, height: 28)
        Image(systemName: "paperplane.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(electricBlue)
    }

    VStack(alignment: .leading, spacing: 1) {
        Text("Blip")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
        Text("Send to your Android device")
            .font(.system(size: 11))
            .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
    }
    ...
}
```

This positions the Blip badge and title cleanly to the right of the controls with comfortable breathing room.

---

## 3. Draggable Title Bar Architecture

### 3.1 AppKit Dragging vs. Drop Target Isolation

Making the entire window draggable via `isMovableByWindowBackground = true` breaks file drag-and-drop targets because mouse events intended for the drop card are captured as window drag tracking sessions.

To solve this, Phase 3E isolates window dragging exclusively to the header bar using an AppKit `NSViewRepresentable`:

```swift
final class DraggableHeaderNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Double-click title bar toggles zoom
            BlipPanelController.shared.toggleZoom()
        } else if let window = self.window {
            window.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}
```

### 3.2 Preserving Interactive Controls

In SwiftUI, child views in an `HStack` share coordinate space. To prevent the draggable background from intercepting clicks on the "Reset Position" button:
1. The `DraggableHeaderArea` is attached exclusively to the leading title `HStack`.
2. The Reset button sits outside this background, maintaining isolated click dispatch.

```
+-------------------------------------------------------------------------+
| [O O O]  [Icon] Blip - Send to Android       [Spacer]  | [Reset Button] |
| <----------- DraggableHeaderArea (performDrag) ------->| (Button Action)|
+-------------------------------------------------------------------------+
| [Divider]                                                               |
+-------------------------------------------------------------------------+
| [File Drop Card / File Picker Button]                                   |
| (Interactive Drop Target - Completely Unaffected)                       |
+-------------------------------------------------------------------------+
```

---

## 4. Position Persistence, Bounds Clamping & Display Topology

### 4.1 Persistence Contract

When the user moves the panel:
1. `NSWindowDelegate.windowDidMove(_:)` receives notification.
2. The new window origin is clamped to the current screen's `visibleFrame`.
3. Coordinates are persisted to `UserDefaults.standard` under `"BlipDroplet.PanelOrigin"`.

### 4.2 Safe Bounds Clamping

To prevent windows from being dragged off-screen or rendered inaccessible behind the notch or Dock:

```swift
public func clampToVisibleScreen(origin: NSPoint, size: CGSize) -> NSPoint {
    let targetRect = NSRect(origin: origin, size: size)
    let centerPoint = NSPoint(x: targetRect.midX, y: targetRect.midY)

    let targetScreen = NSScreen.screens.first { NSMouseInRect(centerPoint, $0.frame, false) }
        ?? NSScreen.main
        ?? NSScreen.screens.first

    guard let screen = targetScreen else { return origin }
    let visible = screen.visibleFrame

    var x = origin.x
    var y = origin.y

    // Clamp horizontally: at least 12pt margin from visible screen edges
    if x < visible.minX + 12 {
        x = visible.minX + 12
    } else if x + size.width > visible.maxX - 12 {
        x = visible.maxX - size.width - 12
    }

    // Clamp vertically: at least 12pt margin from dock/menu bar
    if y < visible.minY + 12 {
        y = visible.minY + 12
    } else if y + size.height > visible.maxY - 12 {
        y = visible.maxY - size.height - 12
    }

    return NSPoint(x: x, y: y)
}
```

### 4.3 Display Parameter Notifications

External monitors can be attached or disconnected at any time. When an external display is disconnected:
- `NSApplication.didChangeScreenParametersNotification` fires.
- `BlipPanelController` receives the event via a Combine publisher.
- If the panel was located on the disconnected display, `clampToVisibleScreen` falls back to `NSScreen.main` and smoothly animates the panel onto the primary laptop display.

### 4.4 Reset Position Action

An accessible reset button (`arrow.counterclockwise`) in the header allows users to instantly clear saved position preferences and center the panel 14pt beneath the notch.

---

## 5. Premium Appearance & Contrast Fix

### 5.1 Problem Analysis
In physical tests on macOS, the Phase 3D panel appeared overly transparent against bright desktop wallpapers or complex application windows because `DroppyPanelSurface` by itself provides dynamic translucent glass.

### 5.2 Multi-Layered Material Architecture

Phase 3E introduces a four-layer composite background:

```swift
ZStack {
    // Layer 1: Solid dark base for readability
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        .background(
            // Layer 2: Native system ultraDark blur depth
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraDarkMaterial)
        )

    // Layer 3: Droppy native glass surface for sheen and host theme harmony
    DroppyPanelSurface(cornerRadius: 24)
        .opacity(0.70)

    // Layer 4: Crisp hairline border
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
}
```

Additionally, drop card surfaces within the panel use `Color(nsColor: .controlBackgroundColor).opacity(0.65)` with subtle borders, ensuring high legibility and contrast under all lighting conditions.

---

## 6. Safety Gate & Truthful Messaging

1. `BLIP_DISPATCH_ENABLED` remains compiled out in this build.
2. The "Continue in Blip" button remains disabled with clear tooltip explanation.
3. Near the action buttons, an explicit truthful explanatory message is rendered:
   ```swift
   HStack(spacing: 4) {
       Image(systemName: "lock.shield")
           .font(.system(size: 10))
           .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
       Text("File staged locally. Sending is not enabled in this test build.")
           .font(.system(size: 10))
           .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
           .lineLimit(2)
   }
   ```
4. No fake transfer progress, pseudo-device pairing, or synthetic delivery statuses are displayed.
