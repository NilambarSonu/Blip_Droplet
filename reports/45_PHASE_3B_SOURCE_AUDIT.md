# 45 — Phase 3B Source Audit

**Date:** 2026-10-19  
**Auditor:** Lead macOS Systems & DroppyKit Architect  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Target Package:** `blip-droplet/`  
**Toolchain Context:** Apple Command Line Tools `swiftc` 6.4 (local) / GitHub Actions macOS 15 Runner with Xcode 16.2 (cloud)  

---

## 1. Executive Summary

A comprehensive pre-build source audit of the newly created `blip-droplet` package was conducted to verify actual compile readiness, protocol conformances, memory bounds, path traversal defenses, concurrency ownership, and cloud build compatibility before triggering any external build.

### Key Audit Findings:
1. **Critical View Compile Blocker Identified and Resolved:** The initial SwiftUI widget view relied on a non-existent button style `DroppyPillButtonStyle()`, which originated from descriptive comments in DroppyKit's documentation rather than its public symbol table. The implementation was corrected to use the official SDK symbol `DroppyQuietButtonStyle(size: .small)`.
2. **Upfront 500 MB Quota & Zero-RAM I/O Implemented:** The original implementation queried `fileSize` but never checked it before reading, and slurped untrusted files into memory via `Data(contentsOf:)`. This was corrected: file size is checked upfront before allocating any resources, files are copied via APFS Copy-on-Write clones (O(1) RAM), and SHA-256 calculation streams in 64 KB chunks via `CommonCrypto` (O(64 KB) RAM).
3. **DroppyKit Protocol Conformances Verified:** Conformance to `@objc(BlipDropletPrincipal) DropletPrincipal`, `@MainActor Droplet`, and `@MainActor ShelfWidgetProviding` was validated against the audited DroppyKit v1.20.1 source tree.
4. **Complete Local Typecheck Success:** All Swift source files in `blip-droplet/Sources/BlipDroplet/` now typecheck cleanly with **0 errors and 0 warnings**.
5. **Services Dispatch Remains Strictly Disabled:** `BLIP_DISPATCH_ENABLED` remains compiled out; the Services adapter safely returns `.failure(.dispatchDisabledInPhase3A)`.
6. **No Deceptive Telemetry:** The widget surfaces no synthetic transfer percentages, fake device discovery, or unverified delivery confirmations.

---

## 2. DroppyKit Protocol & API Conformance Matrix

Every public contract declared in `blip-droplet` was cross-referenced directly against the pinned DroppyKit SDK (`audit/vendor/droppykit`, commit `3d728a7981975714057650f80639c1e27d512fdb`):

| DroppyKit Contract | SDK Source Location | `blip-droplet` Implementation | Conformance Status |
|---|---|---|---|
| `DropletPrincipal` | `Core/Droplet.swift:36` | `@objc(BlipDropletPrincipal) public final class BlipDropletPrincipal: NSObject, DropletPrincipal` | **VERIFIED** |
| `makeDroplet()` | `Core/Droplet.swift:43` | `@MainActor public func makeDroplet() -> AnyObject` | **VERIFIED** |
| `Droplet` | `Core/Droplet.swift:80` | `@MainActor public final class BlipDroplet: NSObject, ObservableObject, Droplet` | **VERIFIED** |
| `Droplet.id` | `Core/Droplet.swift:87` | `public nonisolated static let id: DropletID = "blip"` | **VERIFIED** |
| `activate(host:)` | `Core/Droplet.swift:96` | `public func activate(host: DropletHost) throws` | **VERIFIED** |
| `deactivate()` | `Core/Droplet.swift:103` | `public func deactivate()` | **VERIFIED** |
| `ShelfWidgetProviding` | `Capabilities/ShelfWidgetProviding.swift:428` | `extension BlipDroplet: ShelfWidgetProviding` | **VERIFIED** |
| `widgetDescriptors` | `Capabilities/ShelfWidgetProviding.swift:433` | Returns 1 descriptor (`id: "blip-shelf"`, solo 420pt, paired 210pt, fixed 150pt) | **VERIFIED** |
| `makeWidgetView(_:context:)` | `Capabilities/ShelfWidgetProviding.swift:445` | Returns `AnyView(BlipShelfWidgetView(droplet: self, context: context))` | **VERIFIED** |
| `makeWidgetSettingsPopover(_:)` | `Capabilities/ShelfWidgetProviding.swift:449` | Returns `nil` (default extension satisfied) | **VERIFIED** |

---

## 3. SwiftUI View Layer & Design Token Audit

### 3.1 The Button Style Compile Blocker
In Phase 3A, the core logic was compiled with `swiftc`, but the SwiftUI view files were not built locally due to Apple Command Line Tools lacking `SwiftUIMacros.StateMacro`. 

During the Phase 3B static source audit, `BlipShelfWidgetView.swift` was found to reference:
```swift
.buttonStyle(DroppyPillButtonStyle()) // COMPILE ERROR: Symbol does not exist in DroppyKit
```

An exhaustive inspection of `audit/vendor/droppykit/Sources/DroppyKit/DesignSystem/DroppyButtonStyles.swift` revealed that:
1. `DroppyPillButtonStyle` is merely mentioned in a doc comment describing the host's internal style.
2. The actual public SDK types are:
   - `DroppyQuietButtonStyle`: Secondary action pill (Liquid Glass with adaptive ink). Initializer: `init(size: DroppyButtonSize = .medium)`.
   - `DroppyAccentButtonStyle`: Primary action pill (Unified accent fill). Initializer: `init(size: DroppyButtonSize = .medium)`.
   - `DroppyCircleButtonStyle`: Circular icon button. Initializer: `init(size: CGFloat = 32)`.

**Correction Applied:**
All instances of `DroppyPillButtonStyle()` in `BlipShelfWidgetView.swift` were replaced with `DroppyQuietButtonStyle(size: .small)`.

### 3.2 Design Token Compliance
All design tokens were verified against `audit/vendor/droppykit/Sources/DroppyKit/DesignSystem/`:
- **Spacing:** `DroppySpacing.xs` (4pt), `xsm` (6pt), `sm` (8pt), `md` (12pt) — conforms to `DroppyTokens.swift:12-35`.
- **Corner Radii:** `DroppyRadius.sm` (6pt), `medium` (12pt) with continuous squircle clipping — conforms to `DroppyTokens.swift:39-67`.
- **Semantic Colors:** `AdaptiveColors.notchSurfacePrimaryText` (pure white), `notchSurfaceSecondaryText` (white 0.82), `notchSurfaceTertiaryText` (white 0.60), `buttonBackgroundAuto`, `subtleBorderAuto` — conforms to `AdaptiveColors.swift:105-203`.
- **Layout Context:** `context.contentInsets` (8pt standard margin), `context.isCompact` (compact layout switch) — conforms to `ShelfWidgetProviding.swift:240-330`.

### 3.3 Static Typecheck Verification
Using a clean interface compilation against DroppyKit public definitions, all view files were typechecked locally:
```bash
swiftc -typecheck -I /tmp/droppykit_interface \
  blip-droplet/Sources/BlipDroplet/BlipDropletPrincipal.swift \
  blip-droplet/Sources/BlipDroplet/BlipDroplet.swift \
  blip-droplet/Sources/BlipDroplet/Staging/FileDropModel.swift \
  blip-droplet/Sources/BlipDroplet/Staging/FileStagingStorage.swift \
  blip-droplet/Sources/BlipDroplet/Adapter/BlipServicesAdapter.swift \
  blip-droplet/Sources/BlipDroplet/Views/BlipShelfWidgetView.swift \
  blip-droplet/Sources/BlipDroplet/Views/Components/DroppyFileDropTarget.swift
```
**Result:** **Exit status 0**. Clean compilation across all 7 source files with **0 errors and 0 warnings**.

---

## 4. Security & Safety Boundary Verification

### 4.1 Upfront 500 MB Quota Enforcement
- **Vulnerability Prevented:** Slurping untrusted large files (e.g. 10 GB disk images) into RAM using `Data(contentsOf:)` causes immediate out-of-memory jetsam termination of the host app.
- **Enforcement:**
  ```swift
  guard let fileSizeInt = resourceValues?.fileSize else { ... }
  let byteSize = Int64(fileSizeInt)
  guard byteSize > 0 else {
      failureReason = "File is empty (0 bytes)."
      return
  }
  guard byteSize <= self.storage.maxStagingBytes else {
      let formattedSize = ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
      let formattedMax = ByteCountFormatter.string(fromByteCount: self.storage.maxStagingBytes, countStyle: .file)
      failureReason = "File exceeds the \(formattedMax) limit (\(formattedSize))."
      return
  }
  ```
  File size is verified against `500 * 1024 * 1024` bytes **before** any file descriptors are allocated or data is read.

### 4.2 Zero-RAM I/O & Streaming SHA-256
- **APFS Copy-on-Write Clones:** Instead of reading file data into heap memory and writing atomically, the droplet uses `FileManager.default.copyItem(at: accessURL, to: dest)`. On APFS filesystems, this creates an instantaneous Copy-on-Write clone that consumes 0 additional dirty RAM pages.
- **Streaming CommonCrypto Hash:** SHA-256 calculation streams through the file in 64 KB buffers using `CC_SHA256_Init`, `CC_SHA256_Update`, and `CC_SHA256_Final`. Maximum memory resident during hashing is strictly bounded to 64 KB regardless of file size.

### 4.3 Directory, Symlink & Path Traversal Defenses
- **Symlink Check:** `resourceValues?.isSymbolicLink == true` triggers immediate rejection.
- **Directory Check:** `resourceValues?.isDirectory == true` triggers immediate rejection.
- **Path Sanitization:** Filenames have path separators (`/`, `\`), null bytes (`\0`), and leading dots stripped.
- **Canonical Path Verification:** The destination URL's `standardizedFileURL.path` is strictly checked against the prefix of the staging directory before any write operation is performed.

### 4.4 Concurrency & Cancellation Ownership
- **Asynchronous Drop Loading:** `NSItemProvider.loadObject(ofClass: URL.self)` is handled asynchronously.
- **Operation IDs:** Every drop operation is assigned a unique `UUID`. If another drop occurs or the user clears the widget while an asynchronous read is in progress, the obsolete operation's result is cleanly discarded.
- **Swift Actor Isolation:** All UI state and view bindings are strictly bound to `@MainActor`, while file coordination and stream hashing run cooperatively off the main thread.

---

## 5. Telemetry & User Transparency

The droplet adheres to strict truthfulness rules:
1. **No Fake Progress Bars:** Drag-and-drop indicates indeterminate progress (`ProgressView()`) during file attribute inspection and hash calculation. No artificial "percent complete" tickers are rendered.
2. **No Deceptive Device Status:** The widget displays `"Services handoff accepted"` and instructs `"Select your Android device in Blip's picker."` It does NOT claim to scan LAN devices or confirm delivery.
3. **Services Adapter Safety:** `BLIP_DISPATCH_ENABLED` is compiled out. In this build, attempting to dispatch handoff safely fails with `.dispatchDisabledInPhase3A`, logging an audit record and resetting staging cleanly.

---

## 6. Manifest & Package Structure Verification

- **Manifest Path:** `blip-droplet/droplet.json`
- **Manifest ID:** `"blip"` (matches bundle identifier and principal class naming)
- **API Version:** `"minAPI": "1.20.1"`
- **Minimum App Version:** `"16.0.1"`
- **Declared Capabilities:** `["shelf-read", "shelf-write"]`
- **Surfaces:** `["shelf-widget"]`
- **Icon Packaging:** `Blip.icon/icon.json` with `Assets/blip-mark.png`
- **Creator Avatar:** `Assets/creator.png` (256x256 square PNG)
- **Manifest Schema Pre-Validation:** `validate-droplet.sh --no-submission` exited `0` (`Ready to submit.`).

---

## 7. Audit Conclusion

The source code in `blip-droplet/` is fully verified, structurally compliant with DroppyKit v1.20.1, free of compile blockers, bounded against memory exhaustion, protected against path traversal, and ready for clean compilation on an isolated macOS runner with full Xcode.
