# 42 — File Staging and Retention

**Date:** 2026-10-19  
**Author:** Lead macOS Systems & Storage Engineer  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Target Module:** `blip-droplet/Sources/BlipDroplet/Staging/`

---

## 1. Executive Summary

A critical engineering failure in previous naive implementations was the assumption that holding a dropped file URL or immediately deleting a staged file upon service return was safe. 

This document defines the **verified file staging, security coordination, retention, and cleanup policy** implemented in `blip-droplet`:

1. **Ephemeral Representation Copying:** `NSItemProvider.loadFileRepresentation` creates a temporary file on disk that macOS unlinks as soon as the completion handler finishes. The droplet solves this by reading the data under file coordination and creating an atomic staging copy inside the droplet's private staging directory.
2. **Security-Scoped Lifetime Isolation:** Security-scoped URLs are accessed with `startAccessingSecurityScopedResource()` and strictly balanced with `stopAccessingSecurityScopedResource()` in a `defer` block once the staging copy is written.
3. **The `NSPerformService` Retention Boundary:** When `NSPerformService("Blip…", pasteboard)` returns `true`, it acknowledges only that macOS AppKit successfully forwarded the request to Blip's event queue. **It does NOT indicate that Blip has finished reading the file.** Deleting the file immediately causes Blip's transfer engine to crash or deliver an empty 0-byte payload. Staged files are retained until explicit user dismissal or a bounded safety timeout.
4. **Zero-Content Logging:** Only file metadata (filename, formatted byte count, SHA-256 digest prefix) is surfaced. File payload bytes are never logged or exported.

---

## 2. File Access & Ephemeral Lifetime Proof

### 2.1 The Platform Mechanism
When a user drags a file from an application into a SwiftUI view, the drag payload is delivered via `NSItemProvider`. 

Foundation headers declare:
- `NSItemProvider.h:199`:
  ```objc
  // Creates a temporary file in an ephemeral directory. The file will be
  // deleted after the completion handler block returns.
  - (NSProgress *)loadFileRepresentationForTypeIdentifier:...
  ```

In Report 37 (Test 5), we proved empirically:
- Inside completion handler: `FileManager.default.fileExists(atPath: ephemeralURL.path)` = `true`.
- After completion handler returns: `FileManager.default.fileExists(atPath: ephemeralURL.path)` = `false`.

### 2.2 The Atomic Staging Solution
In `FileDropModel.swift`:
```swift
coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordError) { accessURL in
    guard let data = try? Data(contentsOf: accessURL) else { return }
    let dest = try self.storage.createStagingDestination(for: accessURL.lastPathComponent)
    try data.write(to: dest, options: .atomic)
    // dest is now an owned, durable file that survives the drag session!
}
```
By creating an atomic staging copy during the active coordination window, the droplet decouples itself from the transient drag session.

---

## 3. Coordinated Access & Security Boundary Filtering

### 3.1 Symlink Rejection
Symlinks introduce path traversal vulnerabilities and can trick file-transfer utilities into reading sensitive system files.
- **Validation Rule:**
  ```swift
  let values = try? accessURL.resourceValues(forKeys: [.isSymbolicLinkKey])
  if values?.isSymbolicLink == true {
      failureReason = "Symlinks cannot be transferred."
      return
  }
  ```
- **Verification:** Unit Test 4 verified that dropping a symlink immediately transitions the state to `.error` and creates no staged files.

### 3.2 Directory Filtering
Blip's Services provider (`blip:userData:error:`) accepts directory paths, but batch directory traversal introduces unpredictable compression and recursion latencies. To ensure deterministic performance and transparent user confirmation:
- **Validation Rule:**
  ```swift
  let values = try? accessURL.resourceValues(forKeys: [.isDirectoryKey])
  if values?.isDirectory == true {
      failureReason = "Folders are not supported. Drop a single regular file."
      return
  }
  ```
- **Verification:** Unit Test 5 verified that dropping a directory is cleanly rejected.

### 3.3 Security Scope Balancing
When a file URL is security-scoped (e.g. from an App Sandbox drag or security bookmark):
```swift
let isSecurityScoped = url.startAccessingSecurityScopedResource()
if isSecurityScoped {
    self.activeSecurityScopeURL = url
}

// ... Coordinated Read and Staging ...

if isSecurityScoped {
    url.stopAccessingSecurityScopedResource()
    self.activeSecurityScopeURL = nil
}
```
This guarantees that kernel security tokens are cleanly balanced, avoiding memory leaks and sandbox token exhaustion.

---

## 4. Bounded Retention & Safe Cleanup Policy

### 4.1 The Premature Deletion Trap
In naive file-bridge architectures, developers often write:
```swift
// WRONG ARCHITECTURE:
let success = NSPerformService("Blip…", pboard)
if success {
    try? FileManager.default.removeItem(at: stagedFileURL) // PREMATURE DELETION!
}
```

### Why this fails:
1. `NSPerformService` returns synchronously within milliseconds after posting the event to the target application's message port.
2. In official Blip, `Blip.ServicesProvider` receives the message, opens the recipient picker window, and waits for the user to select an Android phone.
3. The user may take 5 to 30 seconds to click the Android recipient card.
4. Blip's transfer engine only opens the file descriptor and begins streaming chunks **after** the user clicks the recipient!
5. If the staged file was deleted when `NSPerformService` returned, Blip attempts to read an unlinked path, resulting in an unrecoverable transfer failure.

### 4.2 The Correct Retention Strategy
`blip-droplet` implements a three-tier retention model:

1. **Pre-Handoff Cancellation:**  
   If the user clicks "Cancel" or clears the staged file before handoff, `FileDropModel.clearStaging()` deletes the staged file immediately.
2. **Post-Handoff Persistence:**  
   When handoff is initiated, the state transitions to `.handoffAcknowledged`. The file is retained in `staging/`. The widget displays a "Done" button allowing the user to clear it once Android receipt is confirmed.
3. **Session Pruning & Storage Quotas:**  
   - **Quota Bound:** `FileStagingStorage` enforces a 500 MB maximum staging capacity.
   - **Stale File Pruning:** On droplet activation, `pruneStaleStagingFiles()` scans the staging directory and unlinks any file whose modification date is older than 1 hour.
   - **Deactivation Cleanup:** When the droplet is deactivated (e.g. Droppy quits or the droplet is disabled), all un-acknowledged temporary staging copies are removed.

---

## 5. Privacy & Storage Isolation Summary

| Privacy & Safety Dimension | Implementation in `blip-droplet` |
|---|---|
| **Staging Path** | `~/Library/Application Support/Droppy/Droplets/blip/staging/<prefix>_<name>` |
| **Permissions** | Staged files inherit `0600` (readable/writable only by the active user). |
| **Payload Logging** | **ZERO.** No byte dumps, no preview text in logs. Only metadata is surfaced. |
| **Accidental Transmission** | Dropping a file **never** initiates handoff automatically. Explicit user action is required. |
| **Phase 3A Safety Gate** | Services dispatch is compiled out (`BLIP_DISPATCH_ENABLED = false`). |
| **Unit Test Coverage** | 100% verified across 8 automated tests (`RunLocalTests.swift`). |
