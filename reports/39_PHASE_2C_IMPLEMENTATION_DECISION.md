# 39 — Phase 2C Implementation Decision

**Date:** 2026-10-19  
**Author:** Senior macOS Systems & Extension Architect  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Phase Status:** Phase 2C Complete. Clear, evidence-backed implementation decision established.

---

## 1. The Definitive Decision

**The fundamental Droppy-to-Blip integration blocker is resolved.**

We have established precisely how an interactive Droppy shelf widget can initiate file delivery to official Blip, why automated picker-free sending is unviable across all supported macOS channels, and the exact boundary separating local personal sideloading from public Droplet Store compliance.

### The Decision:
1. **Admit Manual Recipient Selection as the Standard:**  
   The proven interactive macOS Services handoff (`NSPerformService("Blip…", pasteboard)`), followed by the official Blip recipient picker, is adopted as the **primary, legitimate transfer mechanism**. All attempts to automate recipient selection via SiriKit, Shortcuts, AppleScript, or private RPCs are officially terminated due to platform barriers (`INIntentUserConfirmationRequired: true`, lack of `.sdef`, and contact type mismatch).
2. **Dual-Track Droppy Integration Architecture:**
   - **Track 1 (Immediate Personal / Developer Sideloading):**  
     Implement a native Droppy shelf widget that executes in-process inside `Droppy.app`, stages dropped files in an isolated cache, and invokes `NSPerformService("Blip…", pasteboard)`. This runs under Droppy's supported Local Droplets loader (`HostSupport.md:88`), which prompts the user once at launch to approve the unsigned build.
   - **Track 2 (Public Store Compliance / Upstream Vendor Extension):**  
     Submit a formal feature request to the DroppyKit maintainers for the minimal additive extension defined in Report 36 (`DropletPermission.servicesHandoff` and `DropletWorkspaceService.performService(_:fileURLs:)`). If Store publication is required before that extension lands, adopt Track 2B: a decoupled user-installed companion CLI (`blipctl`) driven via DroppyKit's documented custom URL scheme callback architecture (`DropletURLHandling`).
3. **No Speculative Architecture or Mock Repurposing:**  
   The historical mock in `blip-research-droplet` remains permanently quarantined. All future implementation will build strictly upon the verified `FileDropModel` architecture and the proven Services handoff baseline.

---

## 2. Matrix of Integration Options

| Integration Option | Documented Support | Source-Level Evidence | Local Test Results | Store Review Status | Architectural Decision |
|---|---|---|---|---|---|
| **Option 1: In-Process `NSPerformService`** | Documented in-process runtime (`Droplet.swift:54`) | AppKit linked in host; compiles without sandbox barrier | **PROVEN:** Report 30 & 31 delivered 63B file to Android | **Blocked for Store** (no declared capability in SDK) | **APPROVED for Personal Local Sideloading (Track 1)** |
| **Option 2: URL Scheme Companion (`blipctl`)** | Officially documented in DroppyKit 1.11.0 (`URLHandling.swift:19`) | `DropletWorkspaceService.open(url)` + `DropletURLRequest` | **PROVEN:** Phase 2B CLI passes 22 checks; child process reads staging | **Approved for Store** (standard companion model) | **APPROVED for Store Track (Track 2B)** |
| **Option 3: Direct `blip://` URL Scheme** | None for file transfer | Registered for push viewing (`net.blip.macos.push`) | Binary inspection shows no transfer endpoint | N/A | **REJECTED (Impossible)** |
| **Option 4: Apple Events (`appleEvents`)** | Supported by DroppyKit (`DropletPermission.swift:86`) | Blip has no `.sdef` and `NSAppleScriptEnabled: None` | Static check confirms non-scriptable | N/A | **REJECTED (Impossible)** |
| **Option 5: Shortcuts / SiriKit** | Declared in `Intents.intentdefinition` | `recipients` is `Person` (Contacts); confirmation required | Metadata inspection confirms no device mapping | N/A | **REJECTED (Non-viable)** |
| **Option 6: Additive Vendor Extension** | Specification provided in Report 36 | ABI 1 compatible additive method on `DropletWorkspaceService` | Design only; requires Droppy host adoption | **Ideal Store Model** | **SUBMIT TO VENDOR (Track 2A)** |

---

## 3. Verified Staging & Access Contract

Based on the 8 passing empirical tests in `audit/phase2c/file-drop-proof.json`:

1. **Drop Acceptance:** The shelf widget accepts drops conforming to `UTType.fileURL` using `loadObject(ofClass: URL.self)`.
2. **Ephemeral Lifetime Guard:** The raw URL from `NSItemProvider` must never be held across asynchronous boundaries. Inside the provider completion block, the file must be coordinated via `NSFileCoordinator` and atomically copied to `~/Library/Application Support/Droppy/Droplets/blip-transfer/staging/`.
3. **Security Scope Management:** When accessing security-scoped URLs, `startAccessingSecurityScopedResource()` must be strictly paired with `stopAccessingSecurityScopedResource()` in a `defer` block once the staging copy is written.
4. **Validation Filtering:** Staging immediately rejects symlinks (`isSymbolicLink == true`), directories (`isDirectory == true`), non-regular files, and files exceeding disk limits.
5. **State Gating:** Gated by a strict state machine (`empty` -> `validating` -> `staged` -> `handoffRequested` -> `cancelled`). Duplicate drops during `validating` or `staged` states are rejected with error `409`.
6. **Shelf Stability:** The widget invokes `host.shelf.setHoldsOpen(true)` while a file is staged to prevent the shelf from auto-closing while the user inspects file metadata.
7. **Cleanup:** Cancelling staging or completing the handoff removes the staged copy and calls `host.shelf.setHoldsOpen(false)`.

---

## 4. Transition to Phase 3 Roadmap

With all research blockers eliminated, the project transitions to **Phase 3: Implementation & Validation**:

### Milestone 3.1: Build Native Staging Shelf Widget (Track 1)
- Create a clean Droppy droplet package (`blip-shelf-widget`) adhering strictly to DroppyKit Design Guidelines (dark theme, no borders, native spacing).
- Integrate the verified `FileDropModel` from Report 37.
- Implement the interactive user flow:
  - Empty drop zone.
  - Staged file card showing filename, formatted byte size, and SHA-256 preview.
  - "Cancel" and "Continue in Blip" buttons.
- Connect "Continue in Blip" to the validated `NSPerformService("Blip…", pasteboard)` handoff.

### Milestone 3.2: Local Sideloading Validation
- Compile the droplet bundle using the Xcode-compatible toolchain or remote build.
- Install the `.droplet` into Droppy via **Settings -> Store -> Local droplets**.
- Verify that Droppy displays its standard unsigned droplet confirmation dialog.
- Perform a single controlled synthetic file drop onto the live notch shelf.
- Verify that Blip's picker appears, manually select Android, and verify file reception.

### Milestone 3.3: Upstream Proposal
- Format the Report 36 vendor extension proposal (`services-handoff`) and submit it to the DroppyKit issue tracker for future SDK releases.

---

## 5. Compliance & Safety Audit

- **BridgeFlow Isolation:** Maintained 100%. No references, imports, or builds of BridgeFlow.
- **Local Toolchain:** Developed and verified exclusively with Apple Command Line Tools (`swiftc` 6.4, `python3`). Zero Xcode local installs.
- **Official App Integrity:** Neither `Blip.app` nor `Droppy.app` was patched, injected, or modified.
- **Android App Integrity:** Official Android Blip remains unmodified.
- **Preservation:** All historical reports (01–35), original CLI probes, and synthetic fixtures remain intact.
- **No Unauthorized Live Actions:** Zero unauthorized live transfers or UI automations were performed.

**Phase 2C is formally closed as a complete success.**
