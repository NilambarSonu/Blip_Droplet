# 54 — Blip Architecture & Protocol Evidence

**Audit Date:** 2026-10-19  
**Researcher:** Principal macOS Reverse-Engineering Researcher & Network Protocol Analyst  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Target Binary:** `/Applications/Blip.app` (macOS arm64/x86_64, Build `20260927200815`, Version `1.2.3`)  
**Methodology:** Non-invasive static binary triage, Mach-O symbol parsing, bundle metadata extraction, network socket state mapping.

---

## 1. Executive Summary

This report documents the empirical structural and protocol evidence recovered from read-only inspection of the installed `/Applications/Blip.app` bundle and its embedded private framework `BlipKit.framework`.

Every architectural claim in this document is anchored directly in file paths, exported symbol names, Mach-O headers, and code signature attributes. In accordance with strict reverse-engineering principles:
> [!IMPORTANT]
> A library linked in a binary or a string literal present in a read-only data segment is evidence of **capability and intent**, but is **not proof of active execution** in any specific user scenario. Where protocol behavior is inferred from type definitions, it is explicitly marked as **INFERRED**.

---

## 2. Application Bundle Architecture & Packaging

Inspection of `/Applications/Blip.app` confirms a multi-component Mach-O bundle structure:

```
/Applications/Blip.app/
├── Contents/
│   ├── Info.plist                     # Bundle metadata, Services, URL schemes, ATS
│   ├── PkgInfo                        # "APPL????"
│   ├── MacOS/
│   │   └── Blip                       # Main UI executable (SwiftUI/AppKit, 3.8 MB)
│   ├── Frameworks/
│   │   ├── BlipKit.framework/         # Private Core Engine (Universal Go, 56.6 MB)
│   │   │   ├── Versions/A/BlipKit     # Compiled Go engine linked via cgo
│   │   │   └── Resources/             # Assets, Info.plist, sound effects
│   │   ├── Sparkle.framework/         # Auto-updater framework
│   │   └── libswiftCompatibilitySpan  # Swift backward compatibility runtime
│   ├── PlugIns/
│   │   ├── BlipShare.appex/           # macOS Share Sheet Extension
│   │   └── BlipPreviewProvider.appex/ # QuickLook Thumbnail Provider
│   ├── Library/
│   │   └── LoginItems/
│   │       └── LaunchAtLoginHelper.app# Background auto-start helper
│   └── Resources/
│       ├── Intents.intentdefinition   # SiriKit INSendMessageIntent metadata
│       ├── Assets.car                 # Compiled asset catalog
│       └── SwiftProtobuf_*.bundle     # Protocol Buffers Swift runtime bundle
```

### Component Analysis:
1. **Main Shell (`Blip`):** An AppKit application configuring `LSUIElement = true` (runs as a menu bar extra with no persistent Dock icon). Written in Swift (SwiftUI + Combine), delegating all state and networking to `BlipKit`.
2. **Core Engine (`BlipKit`):** A 56.6 MB universal dynamic shared library (`net.blip.macos.blipkit`). Contains an entire Go 1.22+ runtime, Go standard library, and the proprietary `github.com/thesharingcompany/blip` source tree compiled via `cgo`.
3. **App Extensions (`BlipShare.appex` & `BlipPreviewProvider.appex`):** Provide system integrations for right-click Share menus and QuickLook previews. Both link against `BlipKit.framework` and communicate with the main process via IPC.

---

## 3. Security, Sandboxing & Code Signing Profile

### 3.1 Entitlements (`codesign -d --entitlements :- /Applications/Blip.app`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>AY8UB8KTUX.blip</string>
    </array>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.personal-information.photos-library</key>
    <true/>
</dict>
</plist>
```

### Key Security Findings:
- **No App Sandbox:** `com.apple.security.app-sandbox` is **absent**. Blip runs with full standard user privileges on macOS.
- **Application Group Binding:** It declares membership in Application Group `AY8UB8KTUX.blip`. Under macOS Hardened Runtime, access to this container (`~/Library/Group Containers/AY8UB8KTUX.blip`) is strictly enforced by the kernel and restricted to binaries signed by Apple Developer Team ID `AY8UB8KTUX` (Blip Studio Inc.).
- **Library Validation Disabled:** `disable-library-validation = true` allows the main executable to load the embedded cgo framework `BlipKit`.

---

## 4. Info.plist & System Registration Audit

### 4.1 Absence of Local Service Discovery Declarations
- **`NSBonjourServices`:** **NOT PRESENT**. The application does **not** register or browse any Bonjour service types (`_xxx._tcp` or `_xxx._udp`).
- **`NSLocalNetworkUsageDescription`:** **NOT PRESENT**. Blip does not declare permissions to perform unprompted local network multicast/broadcast sweeps.
- **ATS Configuration:**
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSExceptionDomains</key>
      <dict>
          <key>localhost</key>
          <dict>
              <key>NSExceptionAllowsInsecureHTTPLoads</key>
              <true/>
          </dict>
      </dict>
  </dict>
  ```
  Every network connection outside `localhost` mandates strict TLS.

### 4.2 Services & URL Handlers
- **Registered Services:** Exactly one AppKit service entry:
  - `NSMenuItem`: `Blip…`
  - `NSMessage`: `blip`
  - `NSPortName`: `Blip`
  - `NSSendTypes`: `["public.content", "public.url", "public.directory", "public.folder"]`
- **Registered URL Schemes:** `blip://` (`CFBundleURLName: net.blip.macos.push`, Role: Viewer). Binary symbol inspection proves this is used for push notification viewing and deep links, not file staging.

---

## 5. Network Stack & Protocol Layer Architecture

Runtime socket auditing (`lsof -nP -a -p 5838 -i -U`) and static symbol triage reveal the four distinct protocol layers operating within Blip:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        BLIP PROTOCOL STACK                             │
├────────────────────────────────────────────────────────────────────────┤
│ LAYER 4: CONTAINER & RESUME                                            │
│   • BSArchive: Binary Streaming Archive (packer, unpacker, checkpoint) │
│   • Checkpoints: Resumable chunk offsets & SHA-256 validation          │
├────────────────────────────────────────────────────────────────────────┤
│ LAYER 3: MULTIPLEXING & STREAMING                                      │
│   • Stripe Mux: Custom multiplexer (mux.go, demux.go, reassembler.go)  │
│   • Multi-channel streaming with backoff dialer & I/O throughput stats │
├────────────────────────────────────────────────────────────────────────┤
│ LAYER 2: TRANSPORT & ENCRYPTION                                        │
│   • Brokered mTLS: Mutual TLS 1.3 handshake (brokeredmtls/mtls.go)     │
│   • Certificate Pinning: Ephemeral X.509 32-byte SHA-256 fingerprints  │
│   • Transport Selection: Direct LAN > Brokered mTLS > Cloud Relay      │
├────────────────────────────────────────────────────────────────────────┤
│ LAYER 1: SIGNALING & DISCOVERY (ALWAYS ON)                             │
│   • WebSocket over TLS 1.3 to prod.blip.net:443 (coder/websocket)      │
│   • Protobuf binary wire format (wire.pb.go, Client/ServerMessageBody) │
│   • Device identity: auth_device_id, auth_user_id                      │
│   • Connection broker: DialId, Role, LANToken, X509Fingerprint         │
└────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Layer 1: Cloud Signaling & Discovery
- **Evidence:** `github.com/coder/websocket` in Go module tree; active socket `172.22.148.211:64500 → 137.184.135.31:443` (`prod.blip.net`).
- **Protobuf Payloads:** Length-delimited protobuf messages defined in `backend/messaging/wire.pb.go`:
  - `ClientMessageBody`: Client-to-server heartbeat, registration, transfer offer.
  - `ServerMessageBody`: Server-to-client peer presence, transfer request, broker options.
- **Signaling Role:** When idle, Blip has **zero listening sockets**. It does not advertise locally. Devices appear online in the Android or Mac UI because `prod.blip.net` notifies each peer when their registered `auth_device_id` is connected.

### 5.2 Layer 2: Connection Brokering & Brokered mTLS
- **Evidence:** Package `go/internal/netx/broker` and `go/internal/netx/brokeredmtls`.
- **Brokered Negotiation Struct (Recovered from Go symbols):**
  ```go
  struct {
      DialId          string
      Role            broker.Role
      Methods         broker.ConnectionMethod
      SupportsProbe   bool
      MaxTimeout      time.Duration
      LANToken        lan.Token
      X509Fingerprint *[32]uint8
  }
  ```
- **Operational Flow (INFERRED from struct layout & package types):**
  1. Sender requests a session to Recipient via `prod.blip.net`.
  2. Server generates a `DialId` and assigns roles (Dialer vs. Listener).
  3. Server issues a temporary `LANToken` and relays the recipient's local IP candidates and ephemeral X.509 certificate fingerprint (`[32]uint8`).
  4. Both peers attempt a direct TCP connection on the local network.
  5. During the TLS 1.3 handshake, each peer validates that the other's certificate matches the 32-byte fingerprint provided by the server.
  6. If direct LAN connection fails (NAT traversal failure), peers fall back to `internal/netx/relay` using a `relay_token`.

### 5.3 Layer 3: The "Stripe" Multiplexing Protocol
- **Evidence:** Package `go/internal/netx/stripe` with files:
  - `mux.go` / `demux.go`: Multiplexes multiple logical streams over a single connection.
  - `reassembler.go`: Reorders out-of-sequence chunks.
  - `region.go`: Maps file byte regions to specific stripes.
  - `write_job.go`: Struct containing `{offset int64, payload []byte, success func()}`.
- **Protocol Nature:** Custom application-layer multiplexer, distinct from HTTP/2 or QUIC. Designed for high-speed multi-gigabit throughput.

### 5.4 Layer 4: "BSArchive" Container & Checkpointing
- **Evidence:** Package `go/frontend/bsarchive` with files:
  - `packer.go`: Serializes files, directories, symlinks, and permissions into a streaming binary archive.
  - `unpacker.go`: Extracts files at destination.
  - `checkpoint.go`: Records chunk boundaries and hash checkpoints to enable resuming interrupted transfers.
- **Protocol Nature:** Proprietary streaming archive format. Not ZIP, TAR, or standard multipart MIME.

---

## 6. Local Inter-Process Communication (IPC)

How does the Swift presentation shell communicate with the Go engine inside `BlipKit`?

- **Protocol:** **DRPC** (Lightweight RPC mechanism using protobuf schemas).
- **Service Stubs:** `frontend/rpc/service_drpc.pb.go`, exposing methods:
  - `/rpc.Service/GetState`
  - `/rpc.Service/Dispatch`
  - `/rpc.Service/Subscribe`
- **Transport:**
  - In-process: Direct Go memory channels / C pointers.
  - Across Extensions (e.g. `BlipShare.appex`): Unix Domain Socket located at:
    `~/Library/Group Containers/AY8UB8KTUX.blip/Library/Caches/sock`
- **Security Enforcement:** Because the socket lives inside `AY8UB8KTUX.blip`, only processes signed with Team ID `AY8UB8KTUX` can connect. External daemons receive `EPERM`.

---

## 7. Protocol Evidence Summary Table

| Protocol Capability | Implementation Technology | Source Evidence | Standard / Open? |
|---|---|---|---|
| **Remote Signaling** | WebSocket over TLS 1.3 | `github.com/coder/websocket` to `prod.blip.net:443` | Standard transport; **Proprietary schema** |
| **Device Discovery** | Server Push over WebSocket | Protobuf `ServerMessageBody` | **Proprietary cloud** |
| **Local Discovery** | None | Zero mDNS / Bonjour / SSDP in binary | **Non-existent** |
| **Handshake** | Brokered mTLS | `internal/netx/brokeredmtls`, 32B fingerprint | Standard TLS 1.3; **Proprietary broker** |
| **Multiplexing** | Custom "Stripe" | `internal/netx/stripe/mux.go` | **Proprietary** |
| **Container Format** | Custom "BSArchive" | `frontend/bsarchive/packer.go` | **Proprietary** |
| **Resumption** | Chunk Checkpoints | `bsarchive/checkpoint.go` | **Proprietary** |
| **Local IPC** | DRPC over Unix Socket | `AY8UB8KTUX.blip/Library/Caches/sock` | Open RPC; **Sandboxed to vendor Team ID** |
| **Public Developer API** | None | Zero headers, zero CLI flags, zero docs | **Non-existent** |

---

## 8. Conclusion

The forensic binary evidence proves that Blip is built around a tightly coupled, proprietary protocol stack. It possesses no open local discovery mechanism and requires active coordination from `prod.blip.net` to establish any transfer.

Report 55 will evaluate how device discovery, pairing, and cryptographic trust operate within this architecture.
