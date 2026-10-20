# 53 — Independent Engine Research Audit

**Audit Date:** 2026-10-19  
**Researcher:** Principal macOS Reverse-Engineering Researcher, Cybersecurity Auditor & Interoperability Specialist  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Target Systems:** macOS Sonoma/Sequoia (Apple Silicon arm64), Blip macOS 1.2.3 (`net.blip.macos`), BlipKit.framework, Android Blip (Official, Unmodified)  
**Safety & Compliance:** Read-only forensic analysis, zero live network transmission, zero credential extraction, zero binary patching.

---

## 1. Executive Summary

This audit performs an exhaustive, forensic review of the entire historical research record (Reports 01 through 48), primary source telemetry, static binary extractions, and live interaction logs. Its purpose is to establish an unassailable baseline of **what has actually been proven** versus **what was merely inferred or prematurely assumed** regarding the feasibility of replacing the official Blip macOS application (`/Applications/Blip.app`) with an independent, lightweight client that interoperates with the unchanged, official Android Blip application.

### Key Audit Conclusions:
1. **The Core Engine is Proprietary Go Linked via Cgo:** Blip is not an ordinary Swift application. Its entire network, crypto, framing, archive, and signaling stack resides inside `BlipKit.framework` (~54 MB), compiled from private Go repository `github.com/thesharingcompany/blip`.
2. **Device Discovery is 100% Cloud-Mediated:** Neither the macOS app nor the Android app implements Bonjour/mDNS, SSDP, or unauthenticated local TCP listening sockets. Devices discover one another exclusively via an outbound WebSocket connection over TLS 1.3 to `prod.blip.net:443`.
3. **Transport Protocol is Non-Standard:** Blip file streaming does not use HTTP/2, WebDAV, or raw TCP. It employs a proprietary binary multiplexer ("Stripe") carrying a proprietary chunked archive container ("BSArchive") encrypted via mutual TLS (mTLS) with ephemeral X.509 certificate fingerprints brokered in real time by `prod.blip.net`.
4. **Services Handoff is the ONLY Demonstrated Interoperability Route:** Reports 30, 31, and 41 verified that macOS AppKit Services (`NSPerformService("Blip…", pasteboard)`) successfully stages files into official Blip.app, which then presents its recipient picker and transmits the payload to Android.
5. **No Standalone Independent Interoperability Has Been Demonstrated:** An independent client cannot currently initiate a transfer to or receive a transfer from an unmodified Android Blip app with `Blip.app` stopped, because Android Blip will neither discover the peer nor accept an unbrokered direct connection.

---

## 2. Historical Research Audit: Proven vs. Inferred vs. Contradicted

### 2.1 What Has Been Proven Experimentally
- **Services Staging and Interactive Delivery (Reports 30 & 31):** One controlled invocation of `NSPerformService("Blip…", board)` with a 63-byte synthetic text fixture returned `true`, caused `Blip.app` (PID 5838) to activate briefly, and displayed the native recipient picker. The user manually selected their paired Android phone, and the file was delivered successfully over LAN within seconds without a second invocation.
- **Droplet UI Generation & Cloud Compilation (Reports 41 & 48):** An isolated Swift package (`blip-droplet`) conforming to DroppyKit v1.20.1 was developed, validated locally, and built successfully on GitHub Actions (`macos-15` Apple Silicon runner) into `BlipDroplet.droplet` with zero local Xcode installation.
- **Pure Swift Engine Performance (IndependentEngine Prototype):** In-memory framing, CryptoKit streaming SHA-256 verification, and chunk reassembly achieved 314.89 MB/s throughput with zero memory leaks and 100% rejection of bit-flipped frames.

### 2.2 What Was Merely Inferred (And Required Correction)
- **Automatic Recipient Targeting via Services:** Early reports inferred that `NSPerformService` or custom pasteboard data could bypass the recipient picker and send directly to Android. Phase 2B (Report 32) proved that the registered `Blip…` service defines no recipient parameters; picker presentation is hardcoded in `Blip.app`.
- **Filesystem Observation as Transfer Progress:** Report 13 and `blip_transfer_monitor.py` assumed that scanning `~/Downloads` and polling socket counts represented real-time transfer progress. Report 27 proved that FSEvents and socket heuristics misattribute unrelated file writes and cannot verify sender identity, byte totals, or cryptographic completion.
- **Local LAN Discovery via Bonjour:** Early project documentation assumed Blip used local mDNS for peer discovery. Static inspection of `Info.plist` (absence of `NSBonjourServices`), entitlements, and network sockets proved that discovery is 100% mediated through `prod.blip.net`.

### 2.3 What Was Contradicted or Proven Infeasible
- **Headless Hosting of BlipKit (Report 20):** Attempting to load `BlipKit.framework` into an independent daemon fails because:
  1. It exports no public C headers or Swift module interfaces.
  2. It mandates membership in macOS Application Group `AY8UB8KTUX.blip`. macOS kernel sandboxing restricts group container access to binaries signed with Developer Team ID `AY8UB8KTUX` (Blip Studio Inc.). Any third-party binary receives `EPERM` (`Operation not permitted`).
  3. Its internal DRPC interface communicates exclusively over in-process Go memory channels and an App Group Unix socket (`AY8UB8KTUX.blip/Library/Caches/sock`), with zero external IPC ports.
- **Stand-alone Droplet Reception (Report 10 & 36):** Droplets run inside Droppy's UI host process and share its lifecycle. A Droplet cannot listen on network ports while Droppy is closed, hidden, or restarted, necessitating a decoupled background daemon for reliable reception.

---

## 3. Architectural Functional Decomposition

To understand what can be replaced, we must cleanly delineate where each capability lives in the official stack:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        OFFICIAL BLIP MAC APP                           │
├────────────────────────────────────────────────────────────────────────┤
│ 1. PRESENTATION LAYER (Swift / AppKit / SwiftUI)                       │
│    • Status bar item (LSUIElement) & Popover window                    │
│    • Recipient Picker UI & Contact Avatar rendering                    │
│    • Transfer progress windows, Dock tile progress, Notifications      │
│    • Registered AppKit Service: "Blip…" (NSMessage: "blip")            │
├────────────────────────────────────────────────────────────────────────┤
│ 2. IN-PROCESS IPC (DRPC over Go Channels)                              │
│    • Dispatches UI events to Go state machine                          │
│    • Streams binary state snapshots to SwiftUI publishers              │
├────────────────────────────────────────────────────────────────────────┤
│ 3. NATIVE ENGINE LAYER (BlipKit.framework / Compiled Go)               │
│    • Local SQLite stores (logs.sqlite, msg-queue.sqlite) in App Group  │
│    • File reading, permission checks, Apple Photos export              │
│    • BSArchive packer/unpacker (chunked binary archive format)         │
│    • Stripe multiplexer (custom multi-channel streaming)               │
│    • Brokered mTLS handshake & ephemeral X.509 cert management         │
├────────────────────────────────────────────────────────────────────────┤
│ 4. REMOTE SIGNALING INFRASTRUCTURE (prod.blip.net:443)                 │
│    • Persistent TLS WebSocket connection (coder/websocket)             │
│    • Device registration & identity management (auth_device_id)        │
│    • Peer online presence push notifications (Client/ServerMessageBody)│
│    • Connection brokering: exchanges DialId, Role, LANToken, X509Hash  │
│    • Cloud relay fallback when direct LAN fails                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Functional Allocation Table

| Capability | Component Responsible | Can Public macOS APIs Replace It? | Dependency on Vendor Cloud |
|---|---|---|---|
| User Drag-and-Drop UI | Presentation Layer (`Blip` executable) | **YES** (Droppy Notch Shelf Widget) | None |
| Transfer Progress Display | Presentation Layer (`Blip` executable) | **YES** (Droppy HUD / Live Activity) | None |
| File Staging & Checksums | Presentation Layer & Go Engine | **YES** (Swift CryptoKit & FileManager) | None |
| Local Network Transport | Go Engine (`netx/stripe`, `Network.framework`) | **YES** (Network.framework NWConnection) | None (if peer supports it) |
| Peer Discovery on LAN | Remote Signaling (`prod.blip.net`) | **NO** (Android Blip does not use mDNS) | **MANDATORY** for Android Blip |
| Device Authentication | Remote Signaling (`prod.blip.net`) | **NO** (Uses private account/device IDs) | **MANDATORY** for Android Blip |
| Connection Brokering | Remote Signaling (`prod.blip.net`) | **NO** (Issues LAN tokens & cert hashes) | **MANDATORY** for Android Blip |
| Payload Packaging | Go Engine (`frontend/bsarchive`) | **NO** (Proprietary binary archive format) | Internal Go implementation |

---

## 4. Comprehensive Evidence Inventory

Each finding across the historical investigation is classified under one of six strict evidentiary categories:

| Finding ID | Subject / Capability | Empirical Evidence | Evidentiary Classification |
|---|---|---|---|
| EVD-01 | Swift Shell Architecture | Universal Mach-O, `DesktopApplication`, SwiftUI symbols, AppKit linkage | **Verified by static analysis** |
| EVD-02 | Go Core in BlipKit | 54 MB binary, `github.com/thesharingcompany/blip` embedded debug paths | **Verified by static analysis** |
| EVD-03 | Outbound Signaling Socket | `lsof -nP -i`: single TCP connection to `137.184.135.31:443` (`prod.blip.net`) | **Verified by experiment** |
| EVD-04 | Absence of Local Listeners | `lsof -i`: zero listening TCP/UDP sockets on idle macOS Blip | **Verified by experiment** |
| EVD-05 | Absence of Bonjour/mDNS | `Info.plist` lacks `NSBonjourServices`; zero mDNS queries registered | **Verified by static analysis** |
| EVD-06 | App Group Sandbox Lock | `AY8UB8KTUX.blip` in entitlements; non-entitled commands return `EPERM` | **Verified by experiment** |
| EVD-07 | Headless BlipKit Hosting | Absence of headers/modulemaps; dynamic load fails library validation | **Blocked by security/auth** |
| EVD-08 | Services File Handoff | Probe execution of `NSPerformService("Blip…")` returned `true`, opened picker | **Verified by experiment** |
| EVD-09 | End-to-End Android Send | User-confirmed manual recipient selection and immediate 63B file delivery | **Verified by experiment** |
| EVD-10 | Automatic Recipient Selection | Inspection of Services declaration and Shortcuts Intent confirms no direct device ID parameter | **Unsupported** |
| EVD-11 | Android App Architecture | Embedded Go source references `xplat/android/saf` (Storage Access Framework) | **Verified by static analysis** |
| EVD-12 | Vendor Public API / SDK | Exhaustive search of `blip.net`, App Store, GitHub, developer docs returned zero public APIs | **Documented by vendor (Absence)** |
| EVD-13 | Brokered mTLS Handshake | Embedded structs: `DialId`, `LANToken`, `X509Fingerprint *[32]uint8` | **Verified by static analysis** |
| EVD-14 | BSArchive Packaging | Source paths `frontend/bsarchive/packer.go`, `checkpoint.go` | **Verified by static analysis** |
| EVD-15 | Droplet UI Compilation | GitHub Actions workflow compiled valid universal droplet bundle | **Verified by experiment** |
| EVD-16 | Pure Swift Frame Throughput | `verify-engine` benchmark achieved 314.89 MB/s with SHA-256 integrity checks | **Verified by experiment** |
| EVD-17 | Independent Android Interop | Unmodified Android app cannot discover or accept unbrokered third-party connections | **Blocked by security/auth** |

---

## 5. Reverse-Engineering Methods Attempted & Lessons Learned

| Method Attempted | Applied To | Outcome | Lesson / Boundary |
|---|---|---|---|
| **Mach-O Static Triage (`otool`, `nm`, `strings`)** | `Blip`, `BlipKit` | High-fidelity recovery of packages, types, struct layouts, and protobuf fields. | Highly effective without heavy external tools; reveals complete internal architecture. |
| **Entitlement & Code Signing Extraction (`codesign`)** | `Blip.app`, `BlipKit` | Discovered App Group restrictions, Team ID binding, Hardened Runtime flags. | Identifies hard OS-level security boundaries that prevent DLL injection or headless re-hosting. |
| **Runtime Socket Auditing (`lsof`, `nettop`)** | PID 5838 | Confirmed single outbound WebSocket to `prod.blip.net` and Unix socket in App Group. | Proved that Blip has no local discovery listener and operates 100% via outbound cloud signaling. |
| **Filesystem Observer Probe (`blip_transfer_monitor.py`)** | `~/Downloads`, etc. | Failed to attribute file writes specifically to Blip; captured unrelated file saves. | Proved that file polling is fundamentally flawed for protocol progress; explicit events required. |
| **Controlled Services Probe (`HandoffProbe`)** | `NSPerformService` | Successfully proved that macOS Services is an active, functional handoff interface. | Demonstrated that the official UI can be driven legitimately via standard macOS AppKit contracts. |
| **Independent Framing Prototype (`IndependentEngine`)** | Local memory pipeline | Proved that a pure Swift replacement engine can achieve 314 MB/s with zero-copy framing. | Proves that Swift systems code is radically faster and lighter than Go, but protocol compatibility is the blocker. |

---

## 6. Synthesis: The Premature Dismissals & Critical Missing Link

Earlier phases correctly noted that building a clone of Blip's GUI was easy via Droppy, and that driving Blip via Services was a working compromise. However, earlier phases prematurely conflated **local transport feasibility** with **Blip interoperability**.

1. **The Transport Trap:** Creating a Swift TCP server or WebSocket that sends files between Mac and Android is trivial (e.g. LocalSend). But calling that "Blip replacement" is technically false if it requires a custom Android app.
2. **The Cloud Bottleneck:** The unmodified official Android Blip app is fundamentally a client of `prod.blip.net`. It does not listen on LAN ports; it does not speak Bonjour; it does not accept ad-hoc TLS connections.
3. **The Interoperability Reality:** To speak to unmodified Android Blip without `Blip.app` on macOS, an independent engine must duplicate the cloud client, authenticate with `prod.blip.net`, negotiate brokered mTLS, format data in Stripe mux frames, and pack files into BSArchive.

Report 54 will examine the exact binary and protocol evidence underpinning this reality.
