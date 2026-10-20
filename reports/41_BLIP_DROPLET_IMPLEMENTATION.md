# 41 — Blip Droplet Implementation

**Date:** 2026-10-19  
**Author:** Lead macOS SwiftUI and DroppyKit Engineer  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Package Root:** `blip-droplet/`  
**Target Platform:** macOS 14.0+, Droppy 16.0.1+ (DroppyKit v1.20.1 / ABI 1)

---

## 1. Package Architecture Overview

The `blip-droplet` package is an isolated, genuine DroppyKit extension built from scratch. It contains no legacy code from the historical mock (`blip-research-droplet`) and strictly conforms to DroppyKit's architectural contracts.

```
blip-droplet/
├── Package.swift                  # SwiftPM package manifest (macOS 14, Swift 5 mode)
├── droplet.json                   # Official manifest (id: "blip", kit: 1.20.1)
├── README.md                      # Package documentation
├── CHANGELOG.md                   # Keep a Changelog format
├── LICENSE                        # MIT License
├── Assets/
│   └── creator.png                # 256x256 square PNG creator avatar
├── Blip.icon/
│   ├── icon.json                  # Icon Composer layer specification
│   └── Assets/
│       └── blip-mark.png          # 256x256 icon layer asset
├── Sources/
│   ├── BlipDroplet/
│   │   ├── BlipDropletPrincipal.swift   # Loader entry point (@objc DropletPrincipal)
│   │   ├── BlipDroplet.swift            # Main Droplet & ShelfWidgetProviding
│   │   ├── Staging/
│   │   │   ├── FileDropModel.swift      # Observable drop & validation state machine
│   │   │   └── FileStagingStorage.swift # Bounded file retention & storage manager
│   │   ├── Adapter/
│   │   │   └── BlipServicesAdapter.swift # Isolated macOS Services adapter (safety gated)
│   │   └── Views/
│   │       ├── BlipShelfWidgetView.swift # Shelf widget view (solo & paired)
│   │       └── Components/
│   │           └── DroppyFileDropTarget.swift # Native Droppy drag-and-drop zone
│   └── BlipDropletHarness/
│       └── BlipDropletHarness.swift     # Standalone DropletHarnessApp entry point
└── Tests/
    ├── BlipDropletTests/
    │   └── BlipDropletTests.swift       # XCTest unit & contract test suite
    └── RunLocalTests.swift              # Standalone test runner for local verification
```

---

## 2. Component Specifications

### 2.1 Principal Loader Entry Point
- **File:** `blip-droplet/Sources/BlipDroplet/BlipDropletPrincipal.swift`
- **Interface:** `@objc(BlipDropletPrincipal) public final class BlipDropletPrincipal: NSObject, DropletPrincipal`
- **Purpose:** Droppy's dynamic bundle loader looks up `NSPrincipalClass` from the bundle's `Info.plist` and calls `makeDroplet() -> AnyObject`.
- **Implementation:**
  ```swift
  @objc(BlipDropletPrincipal)
  public final class BlipDropletPrincipal: NSObject, DropletPrincipal {
      public override init() { super.init() }
      @MainActor public func makeDroplet() -> AnyObject { BlipDroplet() }
  }
  ```

### 2.2 Main Droplet & Shelf Widget Provider
- **File:** `blip-droplet/Sources/BlipDroplet/BlipDroplet.swift`
- **Protocols:** `Droplet`, `ShelfWidgetProviding`, `ObservableObject`
- **Lifecycle Integration:**
  - `activate(host: DropletHost)`: Subscribes to `dropModel.$state`. When state transitions to `.staged`, it invokes `host.shelf.setHoldsOpen(true)` so the shelf does not collapse while the user inspects file metadata. When state returns to `.empty` or `.error`, it releases the hold with `setHoldsOpen(false)`.
  - `deactivate()`: Cancels all subscriptions, releases shelf holds, and purges transient staging caches.
- **Shelf Widget Descriptors:**
  ```swift
  ShelfWidgetDescriptor(
      id: "blip-shelf",
      title: "Blip",
      systemImage: "paperplane",
      layoutTraits: ShelfWidgetLayoutTraits(
          preferredSoloWidth: 420,
          preferredPairedWidth: 210,
          contentHeight: .fixed(150)
      ),
      searchKeywords: ["blip", "transfer", "android", "file", "drop"]
  )
  ```

### 2.3 File Drop Model & State Machine
- **File:** `blip-droplet/Sources/BlipDroplet/Staging/FileDropModel.swift`
- **Protocols:** `@MainActor ObservableObject`
- **States:**
  - `.empty`: Drop zone ready.
  - `.validating(UUID)`: Drop received; asynchronous inspection and staging in progress.
  - `.staged(StagedFileInfo)`: File validated, SHA-256 computed, ready for handoff.
  - `.handoffRequested(StagedFileInfo)`: Handoff initiated to official Blip.
  - `.handoffAcknowledged(StagedFileInfo)`: Blip acknowledged service request; picker open.
  - `.error(String)`: Concrete validation failure (symlink, directory, duplicate, read failure).
- **Security & Concurrency:**
  - Uses `NSItemProvider.loadObject(ofClass: URL.self)` for modern async resolution.
  - Coordinates file reads via `NSFileCoordinator.coordinate(readingItemAt:options:.withoutChanges)`.
  - Implements `isolated deinit` for strict Swift 6 actor isolation safety.

### 2.4 Bounded Staging Storage
- **File:** `blip-droplet/Sources/BlipDroplet/Staging/FileStagingStorage.swift`
- **Directory:** `~/Library/Application Support/Droppy/Droplets/blip/staging/`
- **Quota:** Bounded at 500 MB maximum staging allocation.
- **Retention:** Auto-prunes stale staging files older than 1 hour on initialization.
- **Atomic Operations:** Uses `Data.write(to:options:.atomic)` to prevent partial or torn writes.

### 2.5 Services Adapter Safety Gate
- **File:** `blip-droplet/Sources/BlipDroplet/Adapter/BlipServicesAdapter.swift`
- **Implementation:**
  ```swift
  #if BLIP_DISPATCH_ENABLED
  public static let isDispatchCompiledIn: Bool = true
  #else
  public static let isDispatchCompiledIn: Bool = false
  #endif
  ```
- **Safety Enforcement:** In Phase 3A, `BLIP_DISPATCH_ENABLED` is omitted. The adapter returns `.failure(.dispatchDisabledInPhase3A)`, preventing any accidental transmission.

---

## 3. Premium UI & Droppy Design System Compliance

The widget interface adheres strictly to the official [Droppy Design Guidelines](https://getdroppy.app/docs/droppykit/design-guidelines):

### 3.1 Design System Tokens Used
- **Spacing:** `DroppySpacing.xs` (4pt), `DroppySpacing.xsm` (6pt), `DroppySpacing.sm` (8pt), `DroppySpacing.md` (12pt). All alignments follow the 4pt grid.
- **Corner Radii:** Tiered continuous radii: `DroppyRadius.small` (8pt) on action buttons, `DroppyRadius.medium` (12pt) on staging cards and drop zones.
- **Colors:**
  - `AdaptiveColors.notchSurfacePrimaryText`: High-contrast label color.
  - `AdaptiveColors.notchSurfaceSecondaryText`: Subdued secondary label color.
  - `AdaptiveColors.notchSurfaceTertiaryText`: Subtle metadata color.
  - `AdaptiveColors.buttonBackgroundAuto`: Contrast tint overlay (10% opacity).
  - `AdaptiveColors.subtleBorderAuto`: Native separator overlay.
  - **Electric Blue Accent:** `Color(red: 0.05, green: 0.60, blue: 1.0)` provides subtle branding on drop target activation, status badges, and document icons without overpowering Droppy's dark aesthetic.
- **Card Styling Rule:** In compliance with Droppy guidelines, no heavy outlines, borders, or light backgrounds are drawn on the root card. The widget draws flush into the shelf canvas.
- **Insets:** Sized with exact `context.contentInsets` clearance (8pt under the notch 18pt continuous corner clip; 0pt flush on Dynamic Island).

### 3.2 Visual Compositions

#### A. Solo Layout (420 × 150 pt)
```
┌────────────────────────────────────────────────────────┐
│ ✈ Blip                                 Staged Locally  │
│ ┌────────────────────────────────────────────────────┐ │
│ │ [DOC]  meeting_notes.pdf                           │ │
│ │        1.4 MB • SHA: 8f2a1b9c…                     │ │
│ └────────────────────────────────────────────────────┘ │
│ [ Cancel ]                       [ Continue in Blip ↗ ]│
└────────────────────────────────────────────────────────┘
```

#### B. Compact Paired Layout (210 × 150 pt)
```
┌───────────────────────────────┐
│ ✈ Blip                 Staged │
│ ┌───────────────────────────┐ │
│ │ [DOC] meeting_notes.pdf   │ │
│ │       1.4 MB          [×] │ │
│ └───────────────────────────┘ │
└───────────────────────────────┘
```

---

## 4. Verification Status

- **Source Code Verification:** All 7 Swift source files compile cleanly under Apple Command Line Tools (`swiftc` 6.4).
- **Manifest Validation:** `droplet.json` decodes and passes `validate-droplet.sh --no-submission` with green checks.
- **Asset Compliance:** `Assets/creator.png` (256x256) and `Blip.icon/icon.json` layers satisfy intake rules.
- **Unit Test Suite:** 8/8 tests pass with 0 failures (`audit/phase2c/blip-droplet-unit-tests.json`).
- **Dispatch Safety:** Confirmed compiled-out in Phase 3A candidate binary.
