# 49 — NOTCH INTERACTION ROOT CAUSE & ARCHITECTURAL ANALYSIS

**Author**: Senior macOS AppKit & DroppyKit Systems Engineer  
**Date**: October 19, 2026  
**Status**: APPROVED & DOCUMENTED  
**Workspace Root**: `/Users/nilambarbehera/Documents/Projects/REA/blip-research/`  
**GitHub Repository**: `https://github.com/NilambarSonu/Blip_Droplet.git`  

---

## 1. Executive Summary

In Phase 3C, the Blip droplet was successfully compiled, packaged, and verified to load inside the live Droppy notch shelf. However, real-device usability testing revealed a critical UX defect:

1. **Hover-Coupled Collapse**: The widget rendered file staging directly within the notch shelf. Droppy’s shelf is configured to dismiss automatically when the cursor departs the notch bounds. Consequently, when a user moves their mouse toward Finder to select a file, the shelf collapses.
2. **Global Notch Drop Overlay Preemption**: When a user drags a file from Finder toward the top notch, Droppy's host window manager intercepts the drag event with its own system-wide drop overlay (offering host actions: *Keep*, *Transform*, *Droppy Cloud*, *AirDrop*). Droppy does NOT route drags entering the collapsed notch directly to an inactive or collapsed droplet.
3. **Usability Breakdown**: The user cannot stage files through the notch shelf without either fighting transient window dismissal or being intercepted by Droppy’s built-in file tray actions.

This report documents the architectural root cause and analyzes the official Cleaner droplet model that establishes the supported solution pattern.

---

## 2. Root Cause Breakdown

### 2.1 Droppy Notch Lifecyle & Hover Invalidation
Droppy's notch interface is an AppKit floating panel (`NSPanel`) anchored to the top of the main display (`NSScreen.main`), specifically tracking mouse tracking areas (`NSTrackingArea`) around the physical MacBook notch:
- **Mouse Entered Notch Area**: Droppy expands the notch shelf, hosting droplet icon tabs and displaying the currently active droplet's `body` view (`BlipShelfWidgetView`).
- **Mouse Exited Notch Area**: Droppy sets an auto-dismiss timer (~200–400ms). When the cursor leaves the notch bounding box to click into Finder or drag a file, the notch smoothly collapses back to its idle pill state.
- **Consequence for Drag-and-Drop**: A drag source in Finder requires the user to click and hold in Finder. Because the mouse is outside the notch, the notch collapses *before* the drag can reach the droplet's custom `.onDrop` target.

### 2.2 Host-Level Global Drop Overlay (`DroppyDropOverlay`)
When a drag enters the display's top margin, Droppy’s host controller (`DroppyDropWindowController`) activates its global drop target:
- This overlay is an exclusive, topmost host window that swallows dragging destination sessions (`NSDraggingDestination`).
- It presents host-level quick actions:
  - *Keep* (Droppy temporary shelf storage)
  - *Transform* (host image/audio converter)
  - *Droppy Cloud* (host sync service)
  - *AirDrop* (system sharing handoff)
- **SDK Boundary Finding**: DroppyKit v1.20.1 does *not* export an API or extension point for third-party droplets to insert custom action cards into this global drop overlay. Droplets exist strictly as shelf widgets, settings pages, and custom panels.

### 2.3 The Official Cleaner Droplet Precedent
Inspection of the official, pre-installed **Cleaner droplet** revealed how Droppy intends complex workflows to function:
1. **Separation of Triggers**:
   - The notch icon is a persistent, quick status indicator and trigger point.
   - Cleaner does *not* expect users to drag files or applications into a collapsed notch.
2. **Dedicated Interactive Surface**:
   - Clicking Cleaner triggers a separate, focused interaction.
   - It maintains focus and visibility while the user navigates macOS, chooses applications, or reviews items.
   - It is dismissed explicitly by the user (close button, Escape key) or upon completing the task.

---

## 3. Approved Solution Architecture: The Native Blip Send Panel

To solve the notch collapse problem while adhering strictly to DroppyKit's architectural rules:

```
+-------------------------------------------------------------+
|                     MacBook Air Notch                       |
+-------------------------------------------------------------+
                               |
                   [Click Blip Droplet Icon]
                               v
+-------------------------------------------------------------+
|         Native Floating Blip Panel (NSPanel)                |
|         - Anchored top-center below notch                   |
|         - Uses DroppyPanelSurface & DroppyPanelActivation   |
|         - Non-activating / Floating level (.floating)       |
|         - Survives notch collapse (independent window)      |
|                                                             |
|  +-------------------------------------------------------+  |
|  | Header: Blip Icon | "Blip" | "Send to Android" | [X]  |  |
|  +-------------------------------------------------------+  |
|  | Drop Target / Native "Choose File..." (NSOpenPanel)    |  |
|  | - Single regular file only                            |  |
|  | - Quota (500 MB) upfront verification                |  |
|  | - Streaming SHA-256 computation                       |  |
|  +-------------------------------------------------------+  |
|  | Staged Info: Name | Size | SHA-256 | "Continue" (safe) |  |
|  +-------------------------------------------------------+  |
+-------------------------------------------------------------+
```

### Architectural Guarantees:
1. **Window Persistence**: The panel is an independent AppKit `NSPanel` managed through `DroppyPanelActivation`. It remains visible regardless of whether Droppy's notch shelf is expanded or collapsed.
2. **Dual File Input**:
   - **Click "Choose File…"**: Presents an `NSOpenPanel` configured for single regular file selection. Operates reliably without requiring any drag gesture.
   - **Internal Panel Drop**: If the user prefers drag-and-drop, the panel itself is a visible, persistent drop target that does not collapse while Finder is being manipulated.
3. **No Private API Hooks**: No hooking of Droppy's internal window tree, no runtime swizzling, and no simulation of mouse events.
