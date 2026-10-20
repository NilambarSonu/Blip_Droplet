# 57 — Mac to Android Send Feasibility

**Audit Date:** 2026-10-19  
**Researcher:** Principal macOS Systems Engineer & Network Protocol Analyst  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Direction:** Outbound from macOS to Unmodified Official Android Blip App  
**Core Question:** Can an independent macOS client send files directly to the unchanged official Android Blip application while the official Blip Mac application is completely stopped?

---

## 1. Executive Summary

This report delivers a forensic protocol analysis of sending files from macOS to the unmodified official Android Blip application.

We distinguish sharply between two fundamentally different engineering approaches:
1. **The Services Handoff Route (Phase 2/3):** An independent UI (e.g. Droppy Droplet) stages files and invokes macOS Services (`NSPerformService("Blip…")`) to delegate the transfer to official `Blip.app`. **This is VERIFIED and FUNCTIONAL**, but fails the requirement of working with official `Blip.app` stopped.
2. **The Standalone Engine Route (Phase 4):** A pure Swift engine running independently of `Blip.app`, attempting to dial and deliver files directly to Android Blip. **This route is STRUCTURALLY BLOCKED.**

---

## 2. Protocol Requirements for Standalone Outbound Transfer

For an independent Mac engine to send a file to the unmodified Android Blip app, it must satisfy nine distinct, sequential protocol requirements:

```
┌────────────────────────────────────────────────────────────────────────┐
│             OUTBOUND PROTOCOL SEQUENCE TO ANDROID BLIP                 │
├────────────────────────────────────────────────────────────────────────┤
│ 1. LOCATE ANDROID RECEIVER                                             │
│    • Requirement: Discover Android device IP, port, and online status  │
│    • Reality: Android Blip does not broadcast mDNS / Bonjour / SSDP    │
│    • Feasibility: BLOCKED (Android presence is only known via cloud)   │
├────────────────────────────────────────────────────────────────────────┤
│ 2. ESTABLISH TRUSTED PEER RELATIONSHIP                                 │
│    • Requirement: Exchange authentication credentials & trust tokens   │
│    • Reality: Android Blip expects cloud-authenticated auth_user_id    │
│    • Feasibility: BLOCKED (No local pairing protocol in Android app)   │
├────────────────────────────────────────────────────────────────────────┤
│ 3. NEGOTIATE TRANSFER SESSION                                          │
│    • Requirement: Agree on DialId, Role, LANToken, and Port            │
│    • Reality: Negotiation is mediated by prod.blip.net broker          │
│    • Feasibility: BLOCKED (Android ignores unbrokered session requests)│
├────────────────────────────────────────────────────────────────────────┤
│ 4. ANNOUNCE METADATA (FILENAME & SIZE)                                 │
│    • Requirement: Send protobuf transfer plan (plan.pb.go)             │
│    • Reality: Transmitted over cloud broker or active Stripe control   │
│    • Feasibility: INCOMPLETE (Schema undocumented)                     │
├────────────────────────────────────────────────────────────────────────┤
│ 5. ESTABLISH TRANSPORT CONNECTION                                      │
│    • Requirement: TCP connect to Android LAN IP & handshake            │
│    • Reality: Android opens TCP listener ONLY when commanded by cloud  │
│    • Feasibility: BLOCKED (Android has no open listening port)         │
├────────────────────────────────────────────────────────────────────────┤
│ 6. MUTUAL TLS HANDSHAKE & CERTIFICATE PINNING                          │
│    • Requirement: Complete TLS 1.3 with matching X509Fingerprint       │
│    • Reality: Android checks peer cert hash against broker directive   │
│    • Feasibility: BLOCKED (Requires cloud-brokered fingerprint match)  │
├────────────────────────────────────────────────────────────────────────┤
│ 7. MULTIPLEXED FILE STREAMING (STRIPE)                                 │
│    • Requirement: Pack bytes in BSArchive and stream via Stripe mux    │
│    • Reality: Custom Go multiplexer and archive packer                 │
│    • Feasibility: INCOMPLETE (Reverse-engineered Go logic required)    │
├────────────────────────────────────────────────────────────────────────┤
│ 8. INTEGRITY VERIFICATION & RECEIPT                                    │
│    • Requirement: Validate chunk hashes and overall file SHA-256       │
│    • Reality: Internal checkpoint verification in bsarchive            │
│    • Feasibility: INCOMPLETE (Proprietary checkpoint format)           │
├────────────────────────────────────────────────────────────────────────┤
│ 9. DELIVERY ACKNOWLEDGEMENT & ERROR RECOVERY                           │
│    • Requirement: Receive authoritative delivery confirmation          │
│    • Reality: Android updates cloud database and returns ACK via mux   │
│    • Feasibility: BLOCKED (Requires cloud state update)                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Deep-Dive into the Critical Blockers

### Blocker 1: Android Has No Open Listening Port
- In a standard peer-to-peer system (like HTTP or LocalSend), the receiver runs an HTTP server on a known port (e.g., port 53317).
- In Blip, **Android does not run a persistent listening server**.
- When idle or waiting for files, Android's `netstat` shows zero listening TCP sockets.
- The Android app binds a local port **only after** it receives a push notification or broker message from `prod.blip.net` instructing it to act as `broker.RoleListener` for a specific `DialId`.
- **Consequence:** An independent Mac client cannot simply dial the Android phone's IP address on Wi-Fi, because there is no port listening to accept the connection!

### Blocker 2: Brokered mTLS Fingerprint Verification
- Even if Android were actively listening:
- The Android Blip TLS configuration (`brokeredmtls/mtls.go`) uses a custom `VerifyPeerCertificate` callback:
  ```go
  // Inferred Go verification logic:
  func verifyPeerCertificate(rawCerts [][]byte, verifiedChains [][]*x509.Certificate) error {
      fingerprint := sha256.Sum256(rawCerts[0])
      if fingerprint != expectedFingerprintFromBroker {
          return errors.New("certificate fingerprint mismatch")
      }
      return nil
  }
  ```
- Because an independent client cannot inject its certificate fingerprint into `prod.blip.net`'s broker message to Android, the Android app will immediately reject the TLS handshake and terminate the connection.

### Blocker 3: Proprietary Stripe Framing & BSArchive Packaging
- Raw file bytes sent over a TCP/TLS socket will not be recognized by Android Blip.
- The data stream must be encoded in the proprietary **BSArchive** format (`frontend/bsarchive/packer.go`) and framed across **Stripe** multiplex channels (`internal/netx/stripe/mux.go`).
- While this could theoretically be reverse-engineered given sufficient time, it is irrelevant as long as Blockers 1 and 2 permanently prevent connection establishment.

---

## 4. Comparing the Two Outbound Routes

| Architectural Dimension | Route 1: Services Bridge (Droppy + Blip.app) | Route 2: Standalone Swift Engine |
|---|---|---|
| **Official `Blip.app` Running?** | **REQUIRED** (Must be running in background) | **STOPPED** (Eliminated) |
| **Android Device Discovery** | Handled natively by official Blip | Structurally impossible without cloud |
| **Android Pairing & Trust** | Handled natively by official Blip | Structurally impossible without cloud |
| **Connection Brokering** | Handled natively by official Blip | Blocked (Requires `prod.blip.net`) |
| **Transport Encryption** | Handled natively by official Blip | Blocked (Requires cert fingerprint match)|
| **Stripe Mux & BSArchive** | Handled natively by official Blip | Requires complete clean-room clone |
| **macOS User Experience** | Drag-and-drop into Droppy Shelf Widget | Native Droppy Notch integration |
| **Picker Experience** | Presents official recipient picker | Pure background (hypothetical) |
| **Demonstrated Working?** | **YES** (Verified in Reports 30, 31, 41) | **NO** (Structurally Blocked) |
| **Security / Terms Risks** | **ZERO** (Uses public AppKit API) | High (Requires cloud impersonation) |

---

## 5. Why Outgoing Feasibility Does Not Imply Standalone Feasibility

In Phase 3, we successfully built and demonstrated the Droppy Droplet (`BlipDroplet.droplet`). That droplet allows users to drop a file on the MacBook notch, computes its SHA-256 digest, and prepares it for handoff via `NSPerformService("Blip…")`.

It is tempting to look at that successful UI and conclude: *"We have solved sending!"*

**This is a critical architectural fallacy:**
1. Droppy Droplet is **not** an engine. It is a presentation shell.
2. The actual file delivery to Android was performed by `Blip.app` (PID 5838), which connected to `prod.blip.net`, negotiated with Android, established the mTLS tunnel, and streamed the file.
3. If `Blip.app` is stopped or uninstalled, the Services bridge immediately fails with `NSPerformService returned false`.
4. Therefore, the existence of an interactive Services handoff does **not** prove that an independent engine can send files to Android Blip.

---

## 6. Directional Feasibility Summary

| Outbound Capability | Supported via Services Bridge? | Supported via Standalone Engine? |
|---|---|---|
| Locate Android Blip Device | YES (Delegated to Blip.app) | **NO (BLOCKED)** |
| Negotiate Transfer Session | YES (Delegated to Blip.app) | **NO (BLOCKED)** |
| Direct LAN TCP Connection | YES (Delegated to Blip.app) | **NO (BLOCKED)** |
| mTLS Handshake | YES (Delegated to Blip.app) | **NO (BLOCKED)** |
| Stream File Data | YES (Delegated to Blip.app) | **NO (BLOCKED)** |
| Confirm Delivery | YES (Delegated to Blip.app) | **NO (BLOCKED)** |
| Work with Blip.app Stopped | **NO (Fails User Constraint)** | **NO (BLOCKED)** |

### Final Directional Verdict:
**OUTBOUND INTEROPERABILITY FROM AN INDEPENDENT STANDALONE ENGINE IS COMPLETELY BLOCKED.**  
An independent macOS client cannot send files directly to the unmodified official Android Blip application without official `Blip.app` running.

Report 58 presents the clean-room engine design for local transfers and evaluates the minimal architecture required if an open protocol were adopted.
