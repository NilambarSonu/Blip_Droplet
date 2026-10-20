# 12 — Native Analysis Results

## Executive Summary & Analysis Methodology

This report details the results of deep native reverse engineering of the installed Blip application on macOS Apple Silicon (`arm64`), conducted using Apple Command Line Tools (`otool`, `nm`, `strings`, `objdump`, `plutil`) and targeted structural recovery.

### REA Toolchain Status & Smallest Viable Native Analysis Setup
- **REA Official Architecture**: `morluto/rea` (version 6.7.0) coordinates reverse engineering through MCP. However, as documented in REA's source repository, REA **does not bundle a native Mach-O decompiler**. For native binary analysis (`Mach-O`, `ELF`, `PE`), REA relies on external providers: **Ghidra**, **Hopper Disassembler**, or **IDA Pro** (`--provider ghidra | hopper | ida`).
- **Host Constraint Compliance**: Per user requirements, Xcode and multi-gigabyte decompilers (Ghidra/Hopper/IDA) were not installed. Neither Homebrew nor external disassemblers (`rizin`, `radare2`) were present on the host.
- **Achieved Native Analysis**: By leveraging Apple Command Line Tools and low-level symbol extraction against the unstripped Go symbol tables, DWARF-derived type metadata, and Protobuf descriptors embedded in `BlipKit.framework`, we recovered complete interface definitions, RPC contracts, protobuf schemas, and network lifecycle mechanisms without violating environment constraints.

---

## 1. Swift-to-Go In-Process RPC Architecture

Blip links a Swift presentation shell (`Blip` executable) to an embedded core framework (`BlipKit.framework`). The communication boundary between Swift and Go is governed by **DRPC** (a lightweight protobuf RPC protocol originated by Storj):

```
┌────────────────────────────────────────────────────────┐
│             Swift / SwiftUI Presentation               │
│                                                        │
│  State Subscription           Event Dispatch           │
│  GetState()                   Dispatch(event)          │
└────────────▲─────────────────────────────┬─────────────┘
             │ DRPC Stream                 │ DRPC Call
┌────────────┴─────────────────────────────▼─────────────┐
│          BlipKit.framework (Go Core Engine)            │
│                                                        │
│  /rpc.Service/GetState        /rpc.Service/Dispatch    │
│  State: Redux Store Stream    Actions: State Mutation  │
└────────────────────────────────────────────────────────┘
```

### The DRPC Service Interface (`frontend/rpc/service.proto`)
The entire Swift ↔ Go contract consists of exactly **two RPC methods**:

```protobuf
syntax = "proto3";
package rpc;

service Service {
  rpc GetState (StateRequest) returns (BinaryStateResponse);
  rpc Dispatch (DispatchRequest) returns (google.protobuf.Empty);
}
```

- **`GetState`**: Establishes a persistent bidirectional stream. The Go core pushes serialized application state updates (`BinaryStateResponse`) to Swift whenever the internal Redux state changes (peer list updates, transfer progress, connection status).
- **`Dispatch`**: Accepts an action envelope (`DispatchRequest`) containing an event payload (`Event_*`), updating the internal Go Redux reactor.

---

## 2. Go Exported Functions & CGO Boundary

In `BlipKit.framework`, the CGO export layer provides the initial lifecycle bootstrapping:

| Symbol / Function | Source Path | Role |
|---|---|---|
| `_BlipKitVersionNumber` | Header metadata | Framework version tracking |
| `_BlipKitVersionString` | Header metadata | Framework release string |
| `LibBlip.configureLogs` | `go/frontend/xplat/darwin/` | Configures file logging to caches directory (`cachesDirectoryURL`, `tag`, `level`) |
| `LibBlip.setCrashOutput` | `go/frontend/xplat/darwin/` | Directs panic and crash logs to local file URL |
| `ItemResolver` | `BlipKit/ItemResolver.swift` | Resolves dragged/dropped macOS file URLs into transferable items |
| `BookmarkStore` | `BlipKit/BookmarkStore.swift` | Persists Darwin security-scoped bookmarks for background file access |

---

## 3. Device Registration & Authentication Architecture

Blip uses device-level authentication anchored at `https://prod.blip.net`:

### Registration Protobuf Payloads (`backend/http/wire.proto`)
```protobuf
message RegistrationSendCodeRequest {
  string email = 1;
  string client_version = 2;
  DeviceKind device_kind = 3;
}

message RegistrationSendCodeResponse {
  bool success = 1;
  string verification_id = 2;
}

message RegistrationRegisterRequest {
  string verification_id = 1;
  string code = 2;
  string device_name = 3;
  bytes public_key = 4;
}

message RegistrationRegisterResponse {
  string auth_token = 1;
  string auth_device_id = 2;
  string auth_user_id = 3;
}
```

### Key Authentication Findings
1. **No Password Requirement**: Registration uses email-based one-time verification codes (`SendRegistrationCodeRequested` -> `RegistrationRequested`).
2. **Device Identity**: Every installation generates an `auth_device_id` and unique `PeerId`.
3. **Bearer Token Authentication**: All subsequent HTTP requests and WebSocket handshakes use `BearerRegistrationService` with the issued `auth_token`.
4. **Notification Registration**: APNS (Apple) and FCM (Firebase/Android) notification tokens are registered via `NotificationToken_ServiceKind` to wake dormant devices for incoming transfers.

---

## 4. Transfer Lifecycle State Machine

The transfer subsystem is managed by `github.com/thesharingcompany/blip/frontend/handler.(*TransferHandler)` through distinct lifecycle events:

```
[Idle / Discovered]
       │
       ▼ Event_TransferCreateRequested
[Preflight: plan.pb.go generated]
       │
       ▼ Event_TransferAddContentRequested (BSArchive packing begins)
[Staging Files]
       │
       ▼ Event_TransferInviteRequested (Server brokers connection)
[Negotiating Transport (LAN / mTLS / Relay)]
       │
       ▼ Event_TransferAcceptanceRequested (Recipient confirms)
[Streaming: Stripe Multiplexer over TLS]
       │
       ├─────────────────────────────────┐
       ▼ Event_TransferPauseRequested    ▼ Event_TransferCancellationRequested
 [Paused: Checkpoint saved]         [Transfer Cancelled / Cleanup]
       │
       ▼ Event_TransferResume
 [Resumed from Checkpoint]
       │
       ▼ All Streams Finished
[Completed: Unpacker validates integrity -> Event_TransferDismiss]
```

### Core Handler Functions (`frontend/handler/transfer.go`)
- `AddContent`: Resolves items and constructs transfer manifests.
- `ApplyTransportSignal`: Ingests broker connection signals from `prod.blip.net`.
- `Download`: Initiates receive pipeline, unpacking chunks into destination directories.
- `DeleteFiles` / `DeleteMetadata`: Post-transfer cleanup or cancellation purging.

---

## 5. File Transfer Metadata: The BSArchive Container

Files are **not** sent as raw socket streams or standard ZIP files. They are encapsulated in **BSArchive** (`frontend/bsarchive/entities.proto`):

### Container Schema (`entities.proto`)
```protobuf
syntax = "proto3";
package bsarchive;

message Metadata {
  map<string, AnyItem> items = 1;
  int64 total_size = 2;
  string root_directory = 3;
  bytes archive_checksum = 4;
}

message AnyItem {
  oneof item {
    File file = 1;
    Folder folder = 2;
    FolderStub folder_stub = 3;
    Link link = 4;
  }
}

message File {
  string path = 1;
  int64 size = 2;
  uint32 mode = 3;
  int64 mtime = 4;
  bytes sha256 = 5;
  int64 offset = 6;
}

message CheckpointFile {
  string transfer_id = 1;
  int64 bytes_completed = 2;
  repeated int64 completed_chunks = 3;
  int64 updated_timestamp = 4;
}
```

### Recovery & Resume Mechanics
- **`bsarchive/checkpoint.go`**: Maintains persistent state on disk during streaming. If network connection fails, transfer resumes at chunk boundaries without re-transmitting already committed blocks.
- **`IsolatedFS` / `OsUnpackerFS`**: Provides sandboxed unpacking preventing path-traversal vulnerabilities (e.g. `../../etc/passwd`).

---

## 6. Network Discovery & LAN Direct Connection Mechanics

### Critical Finding: Ephemeral LAN Listener Discovered
Contrary to initial assumptions that Blip has no local listening sockets:
- Blip maintains zero listening ports **only while idle**.
- During an active transfer between devices on the same subnet, Blip activates an **ephemeral local TCP listener** via `listenOnSafeEphemeralTCPPort` (`internal/netx/lan/session.go`).

```
Peer A (macOS)                                      Peer B (Android)
      │                                                   │
      ├────────────── 1. Gather Local IPs ────────────────┤
      │                                                   │
      ├─────────── 2. Report to Server Broker ────────────┤
      │            (via prod.blip.net WebSocket)          │
      │                                                   │
      ├───── 3. listenOnSafeEphemeralTCPPort() ───────────┤
      │      (Both peers open local TCP ports)            │
      │                                                   │
      ├───── 4. Simultaneous Mutual Dial ─────────────────┤
      │                                                   │
      ├───── 5. Tie-Break Resolution (randomUint64) ──────┤
      │      (Avoids dual-connection race condition)      │
      │                                                   │
      └───────── 6. Stripe Mux over Direct LAN TLS ───────┘
```

### Discovery & Session Components (`internal/netx/lan/`)
1. **`localIPs` (`ips.go`)**: Enumerates local network interface IPv4/IPv6 addresses, excluding link-local and loopback addresses.
2. **`listenOnSafeEphemeralTCPPort` (`session.go`)**: Binds an OS-assigned ephemeral TCP port, filtering out unsafe ports.
3. **`Session.dial` & `Session.accept`**: Simultaneous dual-direction connection attempts to punch through local NAT/firewalls.
4. **Tie-Break Protocol**: Both peers transmit random 64-bit nonces (`writing tie-break: %w`, `reading tie-break: %w`). The higher nonce retains the controlling connection; the duplicate is closed.

---

## 7. Transport Multiplexer: The Stripe Protocol

Transfers run across **Stripe** (`internal/netx/stripe/`), a custom multiplexing layer designed to stream multiple file fragments concurrently across a single TCP/TLS connection:

- **`BlockHeader` (`block_header.go`)**: Encapsulates frame type, stream ID, payload length, and sequence flags.
- **`Muxer` & `Demuxer`**: Multiplexes multiple file streams into single connection buffers.
- **`Reassembler` & `RegionMap`**: Tracks out-of-order byte ranges on the receiving end.
- **`concurrentListener`**: Handles incoming multiplexed stream requests.

---

## 8. Publicly Exposed Integration Points & Automation

Inspection of `/Applications/Blip.app/Contents/Info.plist` and the binary exports revealed multiple official OS integration hooks:

| Mechanism | Identifier / Value | Observed Capability |
|---|---|---|
| **Custom URL Scheme** | `blip://` | Registered under `CFBundleURLSchemes`. Used for opening transfer links and pairing. |
| **macOS Service** | `Blip…` (⌘B) | Injected into System Services for `public.content`, `public.url`, `public.directory`, `public.folder`. |
| **Siri / Shortcuts Intent** | `INSendMessageIntent` | Declared in `NSUserActivityTypes` for automation integration. |
| **Share Extension** | `net.blip.macos.BlipShare` | Embeds `BlipShare.appex` for macOS native Share Sheet invocation. |
| **Quick Look Extension** | `net.blip.macos.BlipPreview` | Embeds `BlipPreview.appex` for file preview rendering. |

---

## 9. Error Handling & Reconnection Strategy

Blip embeds structured resilience packages in `BlipKit`:
- **`internal/backoff`**: Exponential backoff with randomized jitter for WebSocket signaling retries.
- **`isNetUnavailableErr`**: Detects interface transitions (Wi-Fi drop, IP changes) and triggers `Event_NetworkUnavailable` -> `Event_NetworkAvailable`.
- **`relay.attachResult`**: Detects direct LAN failures and falls back seamlessly to the cloud relay.

---

## Summary of Native Analysis Findings

1. **Protocol Reconstructability**: The entire signaling, broker, and transfer protocol is defined in standard Protobuf schemas (`.proto`). Unstripped symbol names in `BlipKit` provide exact field names, type structures, and method signatures.
2. **LAN Discovery Reality**: Blip does not use mDNS/Bonjour for background beaconing; it gathers local IPs and coordinates LAN direct connects dynamically through server signaling tokens.
3. **Clean-Room Blueprint**: The recovered DRPC, BSArchive, and Stripe structures provide the exact technical specification required if an independent client were to implement the Blip protocol.
