# 17 — Droppy Build Evidence & Artifact Verification

## Purpose of this Report

This report provides forensic verification of the proof-of-concept Droplet (`BridgeFlow.droplet`) referenced in Report 15. In accordance with Phase 1C instructions, this audit distinguishes verified build artifacts from unverified runtime claims, documents exact filesystem timestamps, inspects implemented vs. mock functionality, and confirms whether the bundle has ever been loaded into the host Droppy runtime.

---

## 1. Verified Artifact Location & Physical Attributes

The bundle evaluated during this investigation is located at:
- **Canonical Path**: `/Users/nilambarbehera/Projects/BridgeFlow-Droplet/work/verified-artifact/BridgeFlow.droplet`
- **Mach-O Binary**: `/Users/nilambarbehera/Projects/BridgeFlow-Droplet/work/verified-artifact/BridgeFlow.droplet/Contents/MacOS/Bridgeflow`

### Exact Command Output: Filesystem Metadata
```bash
$ stat -f "%N: %Sm (modified: %m)" .../Bridgeflow && ls -lT .../Bridgeflow
/Users/nilambarbehera/Projects/BridgeFlow-Droplet/work/verified-artifact/BridgeFlow.droplet/Contents/MacOS/Bridgeflow: Oct 17 17:02:23 2026 (modified: 1792236743)
-rwxr-xr-x@ 1 nilambarbehera  staff  2067256 Oct 17 17:02:23 2026 .../Bridgeflow

$ du -sh /Users/nilambarbehera/Projects/BridgeFlow-Droplet/work/verified-artifact/BridgeFlow.droplet
3.4M    /Users/nilambarbehera/Projects/BridgeFlow-Droplet/work/verified-artifact/BridgeFlow.droplet
```

| Property | Value | Evidence / Command |
|---|---|---|
| **Bundle Footprint** | 3.4 MB | `du -sh` |
| **Mach-O Binary Size** | 2,067,256 bytes (~1.97 MB) | `ls -lT` |
| **Mach-O Type** | Universal binary (`arm64` + `x86_64`) | `lipo -info` |
| **Binary Build Timestamp** | `2026-10-17 17:02:23` | `stat -f "%Sm"` |
| **Framework Linkage** | `@rpath/DroppyKit.framework` | `otool -L` |

---

## 2. Source Files & Build Timestamp Audit

The droplet was built from sources located in `~/Projects/BridgeFlow-Droplet/bridgeflow/Sources/Bridgeflow/`. A comparison between source file modification times and the compiled binary timestamp confirms chronology:

### Source Files Timestamps (`ls -lT`)
```
-rw-r--r--@ 1 nilambarbehera staff  5783 Oct 17 11:00:07 2026 AudioPlayer.swift
-rw-r--r--@ 1 nilambarbehera staff 22649 Oct 17 11:07:44 2026 BluetoothLink.swift
-rw-r--r--@ 1 nilambarbehera staff 17235 Oct 17 16:50:32 2026 BridgeflowDroplet.swift
-rw-r--r--@ 1 nilambarbehera staff  6550 Oct 17 11:00:07 2026 H264Player.swift
-rw-r--r--@ 1 nilambarbehera staff  2633 Oct 17 11:11:37 2026 Keychain.swift
-rw-r--r--@ 1 nilambarbehera staff  2895 Oct 17 11:00:07 2026 MacTwins.swift
-rw-r--r--@ 1 nilambarbehera staff 17946 Oct 17 11:05:03 2026 PhoneFiles.swift
-rw-r--r--@ 1 nilambarbehera staff   842 Oct 17 11:14:32 2026 PhoneNotification.swift
-rw-r--r--@ 1 nilambarbehera staff  5418 Oct 17 11:00:07 2026 ScrcpyProtocol.swift
-rw-r--r--@ 1 nilambarbehera staff 11463 Oct 17 11:00:07 2026 Session.swift
-rw-r--r--@ 1 nilambarbehera staff 18355 Oct 17 11:00:07 2026 SessionWindow.swift
-rw-r--r--@ 1 nilambarbehera staff  6286 Oct 17 11:08:35 2026 TCPStream.swift
-rw-r--r--@ 1 nilambarbehera staff  9769 Oct 17 16:50:32 2026 Views.swift
```

- **Most Recent Source Modification**: `BridgeflowDroplet.swift` and `Views.swift` at **16:50:32** on Oct 17, 2026.
- **Binary Generation**: Binary built at **17:02:23** on Oct 17, 2026 (~12 minutes post source edit).
- **Compilation Log**: Corroborated by `~/Projects/BridgeFlow-Droplet/work/universal-success.log` timestamped at **17:03:00**.

---

## 3. Actual Functionality vs. Mock Functionality

Inspection of `droplet.json`, `BridgeflowDroplet.swift`, and `PhoneFiles.swift` reveals the true scope of the project:

### Manifest Intent (`droplet.json`)
```json
{
  "id": "bridgeflow",
  "name": "BridgeFlow — Android Continuity",
  "version": "0.1.0",
  "description": "Native Android continuity using the Bridge 0.3.1 protocol. Requires explicit pairing and device verification. Blip remains the official file receiver."
}
```

### Analysis of Implemented vs. Mock Features
1. **Scope**: BridgeFlow is an **Android continuity and phone mirroring droplet**, not an independent peer-to-peer file transfer engine.
2. **Explicit Reliance on Blip**: The manifest explicitly states: *"Blip remains the official file receiver."* In `BridgeflowDroplet.swift` line 43, it includes `@Published var blipRunning = false` to monitor whether Blip is active.
3. **File Handling (`PhoneFiles.swift`)**:
   - Implements ad-hoc PUSH/PULL helpers over an active video mirroring tunnel (`ScrcpyProtocol` + `Daemon.kt`).
   - Requires an active screen-mirroring session to move files.
   - It does **not** implement autonomous background file reception, signaling, LAN token exchange, or resume checkpointing.
4. **Mock / Stub Surfaces**:
   - Transfer progress cards in UI are placeholders or tied to video buffer lag metrics (`noteVideoBacklog`).
   - Bluetooth pairing is implemented via CoreBluetooth; direct Wi-Fi P2P file transport is absent.

---

## 4. Compilation Toolchain & Xcode Independence

The compilation pipeline operates entirely through Apple Command Line Tools without requiring the Xcode application:

```bash
$ xcrun -sdk macosx swiftc --version
swift-driver version: 1.168.6 Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
Target: arm64-apple-macosx27.2.0
```

`Scripts/build-droplet.sh` executes:
1. `swift build -Xswiftc -enable-library-evolution -Xswiftc -emit-module-interface` for each slice (`arm64`, `x86_64`).
2. `lipo -create` to merge the slices into a universal binary.
3. Packages the resulting binary and `droplet.json` into a standard bundle hierarchy.
This conclusively proves that **Droplet compilation does not require Xcode**.

---

## 5. Official DroppyKit Validation Results

Running the official intake validator produces clean verification:

```bash
$ bash ~/Projects/BridgeFlow-Droplet/work/droppykit/Scripts/validate-droplet.sh \
    --bundle /Users/nilambarbehera/Projects/BridgeFlow-Droplet/work/verified-artifact/BridgeFlow.droplet \
    --no-submission

Manifest
  ✓ droplet.json, icon document and creator avatar
Live activity
  ✓ no controls in the unmounted live activity card
  ✓ no glass button in the compact row
Linkage
  ✓ no direct-access imports
  ✓ links DroppyKit.framework
API
  ✓ kit.minAPI 1.20.1 covers every DroppyKit API it calls (newest: 1.9.0)
Architectures
  ✓ universal (x86_64 arm64)

Ready to submit.
```

---

## 6. Runtime Loading Verification Inside Real Droppy

### Forensic Inspection of Running Droppy Process
To determine whether `BridgeFlow.droplet` has ever been loaded into the host Droppy application (`pid 37218`):

```bash
$ lsof -p 37218 | grep -i "Bridgeflow"
# Returns code 1 (EMPTY - No matching files mapped)
```

Furthermore, the project's own automated verification file (`~/Projects/BridgeFlow-Droplet/work/local-bundle-verification.json`, lines 39–40) records:
```json
  "hardwareVerified": false,
  "hostLoadVerified": false
```

### Definitive Runtime Verdict
> [!CAUTION]
> **`BridgeFlow.droplet` has NOT been loaded into Droppy at runtime.**
> - The binary exists and passed static package intake validation.
> - However, it is not installed in Droppy's active container or mapped into Droppy's memory.
> - **Any claims that this droplet was runtime-validated or measured live inside Droppy are unsupported and formally retracted.**
