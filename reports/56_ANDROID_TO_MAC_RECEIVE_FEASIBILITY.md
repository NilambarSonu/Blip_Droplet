# 56 — Android to Mac Receive Feasibility

**Audit Date:** 2026-10-19  
**Researcher:** Principal macOS Reverse-Engineering Researcher & Systems Engineer  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Direction:** Inbound to macOS from Unmodified Official Android Blip App  
**Core Question:** Can an independent macOS daemon or Droppy component receive files sent from an unmodified Android Blip app while the official Blip Mac application is completely stopped?

---

## 1. Executive Summary

This report delivers a rigorous directional feasibility analysis of receiving files on macOS from the unmodified Android Blip application without running any component of `/Applications/Blip.app`.

### Definitive Feasibility Verdict: STRUCTURALLY BLOCKED
> [!CAUTION]
> **Receiving files on macOS from an unmodified official Android Blip app without official `Blip.app` running is technically impossible under authorized boundaries.**
> The blocking failure occurs at **Step 0 (Peer Presence)**: The Android app will never initiate a connection to a local Mac IP address unless Blip Studio's cloud server (`prod.blip.net`) explicitly instructs it to do so. With `Blip.app` stopped, the server reports the Mac as offline, preventing the Android user from selecting the Mac or initiating a transfer.

---

## 2. Inbound Transfer Lifecycle (Official Flow)

To understand why independent reception fails, we trace the mandatory sequence of events that occurs when an Android user attempts to send a file to a Mac:

```
Android User                Android App                 prod.blip.net                 macOS Blip.app
     │                           │                            │                              │
     │ 1. Opens Share Sheet      │                            │                              │
     ├──────────────────────────►│                            │                              │
     │                           │ 2. Queries Peer Presence   │                              │
     │                           ├───────────────────────────►│                              │
     │                           │    (WebSocket TLS 1.3)     │ 3. Pushes Presence           │
     │                           │                            │    ("Mac is Online")         │
     │                           │◄───────────────────────────┤◄─────────────────────────────┤
     │                           │                            │   (Maintained by PID 5838)   │
     │ 4. Renders "Mac" Avatar   │                            │                              │
     │◄──────────────────────────┤                            │                              │
     │                           │                            │                              │
     │ 5. Taps "Mac" & Selects   │                            │                              │
     ├──────────────────────────►│                            │                              │
     │                           │ 6. Send Transfer Offer     │                              │
     │                           ├───────────────────────────►│                              │
     │                           │    (filename, size, proto) │ 7. Relays Offer via WebSocket│
     │                           │                            ├─────────────────────────────►│
     │                           │                            │                              │ 8. Auto-Accept /
     │                           │                            │◄─────────────────────────────┤    Shows Prompt
     │                           │ 9. Connection Brokering    │ 9. Connection Brokering      │
     │                           │    (DialId, LANToken,      │    (DialId, LANToken,        │
     │                           │     Mac LAN IP, CertHash)  │     Android IP, CertHash)    │
     │                           │◄───────────────────────────┼─────────────────────────────►│
     │                           │                            │                              │
     │                           │ 10. Direct TCP Connect (LAN)                              │
     │                           ├──────────────────────────────────────────────────────────►│
     │                           │ 11. Brokered mTLS Handshake (Validates Cert SHA-256)      │
     │                           │◄═════════════════════════════════════════════════════════►│
     │                           │ 12. Stripe Mux Stream (BSArchive Container Chunks)        │
     │                           ├──────────────────────────────────────────────────────────►│
     │                           │ 13. Delivery Acknowledgement (Stripe / Cloud)             │
     │                           │◄──────────────────────────────────────────────────────────┤
     │ 14. "Sent" Confirmation   │                            │                              │
     │◄──────────────────────────┤                            │                              │
```

---

## 3. Dissecting the Failure Modes of an Independent Receiver

Now consider what happens when `/Applications/Blip.app` is quit, and an independent clean-room daemon (e.g. `transferd` in Swift) is running on macOS.

### Failure Mode 1: The Peer Presence Black Hole (Fatal)
- **Condition:** Official `Blip.app` is stopped.
- **Result:** The persistent WebSocket connection to `prod.blip.net:443` is closed.
- **Server State:** `prod.blip.net` updates its presence database: the Mac's `auth_device_id` is marked **Offline**.
- **Android UI Impact:**
  - When the user opens Blip on Android, the Mac does not appear in the recipient list, or appears grayed out with status "Offline".
  - The Android app provides **no manual override** (no "Enter IP" or "Send to LAN Address" option).
  - **Outcome:** The user on Android cannot tap or select the Mac. The transfer cannot even be initiated.

### Failure Mode 2: The Brokerless Connection Dilemma (Fatal)
- **Hypothetical Workaround:** Suppose the Android app cached the Mac's local IP from a previous session and attempted to dial the Mac directly over Wi-Fi.
- **Result:**
  - Android Blip does **not** dial ad-hoc local IP addresses on its own. All dials are strictly governed by broker commands received over its cloud WebSocket (`internal/netx/broker/connect.go`).
  - Even if an independent Swift receiver listened on port 443, 8080, or 64500, Android Blip would never initiate a TCP socket connection to it without a broker directive from `prod.blip.net`.

### Failure Mode 3: The Brokered mTLS Authentication Barrier (Fatal)
- **Hypothetical Workaround:** Suppose Android Blip *did* connect to the independent Swift receiver on LAN.
- **Handshake Requirements:**
  - Android Blip initiates a TLS 1.3 handshake expecting a mutual TLS peer.
  - The Android client checks the presented X.509 certificate's SHA-256 digest against the 32-byte `X509Fingerprint` it expects from the broker.
  - An independent receiver has no access to the broker exchange, so it cannot know what fingerprint the Android app expects.
  - **Outcome:** The Android client terminates the TLS connection immediately with an untrusted certificate alert.

### Failure Mode 4: The Proprietary De-Framing Barrier (Critical)
- **Protocol Requirements:**
  - Even if mTLS were bypassed, data arrives as multiplexed binary frames via Blip's proprietary **Stripe** protocol (`internal/netx/stripe/mux.go`).
  - Inside Stripe, files and metadata are packed in the **BSArchive** streaming container format (`frontend/bsarchive/packer.go`).
  - To receive and write files to disk, the independent receiver would need a complete, byte-for-byte reverse-engineered implementation of Stripe demuxing and BSArchive decompression.
  - Any framing mismatch aborts the transfer and causes Android Blip to report "Transfer Failed".

### Failure Mode 5: The Cloud Delivery Confirmation Barrier (Major)
- **Delivery Semantics:**
  - Upon receiving all chunks, the recipient must send a delivery acknowledgement back to the sender and to `prod.blip.net` to update the transfer record.
  - If the cloud server does not receive this acknowledgement, Android Blip flags the transfer as interrupted or failed and attempts an exponential-backoff retry via cloud relay.

---

## 4. What Persists on macOS When Blip.app is Stopped?

When `/Applications/Blip.app` is completely terminated (`killall Blip`):

| Component / Resource | State When Blip.app is Stopped | Impact on Inbound Transfers |
|---|---|---|
| Main Executable (`Blip`) | Terminated (PID destroyed) | Zero UI, zero menu bar icon |
| In-Process Go Engine (`BlipKit`) | Unloaded from memory | Zero DRPC, zero Stripe mux, zero BSArchive unpacker |
| Signaling WebSocket Socket | Closed (`FIN/ACK`) | `prod.blip.net` marks Mac **Offline** immediately |
| App Group Unix Socket | Closed & unlinked (`sock`) | Share extensions and helpers cannot connect |
| SQLite Databases (`AY8UB8KTUX.blip`)| On disk, locked by macOS sandbox | Inaccessible to non-entitled third-party binaries |
| Registered macOS Services | Registered in Launch Services database | Invocable only by user action on Mac; **useless for inbound** |
| Background Daemons / Helpers | None (LaunchAtLoginHelper is inactive) | **Zero listening processes** on macOS |

**Conclusion:** Nothing remains active on macOS to receive inbound transfer notifications or network streams.

---

## 5. Can a Droppy Droplet Act as an Incoming Receiver?

A core question in the user's requirements: **Can Droppy receive files while the official Blip Mac application is completely stopped?**

### Technical Reality: NO.
1. **Droplet Lifecycle Constraints:**
   - Droppy droplets built with DroppyKit run inside `Droppy.app`'s main process.
   - Droplets are UI extensions (Shelf widgets, HUD presenters). They have no background persistence independent of Droppy.
   - If Droppy is quit or hidden, droplet code does not execute.
2. **Network Capability Constraints:**
   - Droppy's capability ledger (`DropletPermission.swift`) provides `network-client` (outbound URLSession/HTTP requests).
   - It exposes **zero server capability** (`NWListener` or TCP socket binding is not a sanctioned Droplet permission).
3. **The Android Discovery Block:**
   - Even if Droppy hosted an `NWListener` in-process, unmodified Android Blip would never connect to it (Failure Modes 1–3).

---

## 6. Directional Feasibility Summary

| Requirement for Android-to-Mac Inbound | Official Blip.app | Independent Clean-Room Engine | Feasibility Status |
|---|---|---|---|
| Maintain online presence on `prod.blip.net` | Built-in WebSocket | Blocked (Requires unauthorized auth) | **BLOCKED** |
| Receive incoming transfer offer | Built-in WebSocket | Blocked (Android routes offer via cloud) | **BLOCKED** |
| Negotiate session broker parameters | Built-in Go broker | Blocked (Server-brokered) | **BLOCKED** |
| Direct LAN mTLS handshake | Ephemeral cert pinning | Blocked (Requires server fingerprint sync) | **BLOCKED** |
| Stripe multiplexer demuxing | `netx/stripe` | Proprietary, undocumented wire format | **INCOMPLETE** |
| BSArchive container extraction | `frontend/bsarchive` | Proprietary archive format | **INCOMPLETE** |
| Delivery acknowledgement | Protobuf wire protocol | Blocked (Requires cloud signaling) | **BLOCKED** |

### Final Directional Verdict:
**INBOUND INTEROPERABILITY IS COMPLETELY BLOCKED.** An independent macOS client cannot receive transfers from the unmodified official Android Blip app while official `Blip.app` is stopped.

Report 57 evaluates the reverse direction: sending files from Mac to Android.
