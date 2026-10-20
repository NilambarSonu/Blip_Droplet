# 04 — Application Architecture

## Architecture Overview

Blip follows a **two-layer architecture**: a native Swift/SwiftUI UI shell and a Go-based core engine, communicating via DRPC (lightweight RPC over in-process channels).

```
┌─────────────────────────────────────────────────┐
│                   macOS Layer                    │
│                                                  │
│  ┌─────────────────┐  ┌──────────────────────┐  │
│  │ Blip Executable  │  │  App Extensions      │  │
│  │ (Swift/SwiftUI)  │  │  - BlipShare.appex   │  │
│  │                  │  │  - BlipPreview.appex  │  │
│  │ • MenuBarView    │  └──────────────────────┘  │
│  │ • TransferWindow │                            │
│  │ • SettingsView   │  ┌──────────────────────┐  │
│  │ • DockTile       │  │ LaunchAtLoginHelper   │  │
│  │ • ServicesProvider│  └──────────────────────┘  │
│  └────────┬─────────┘                            │
│           │ DRPC (in-process)                    │
│  ┌────────▼─────────────────────────────────────┐│
│  │           BlipKit.framework (Go + cgo)        ││
│  │                                               ││
│  │  ┌─────────┐  ┌─────────┐  ┌──────────────┐ ││
│  │  │ Frontend │  │ Backend │  │  Internal/Net │ ││
│  │  │ • State  │  │ • HTTP  │  │  • Broker    │ ││
│  │  │ • Redux  │  │ • Msg   │  │  • LAN       │ ││
│  │  │ • Handler│  │ • SQLite│  │  • Relay     │ ││
│  │  │ • RPC    │  │         │  │  • Stripe    │ ││
│  │  │ • Xplat  │  │         │  │  • mTLS      │ ││
│  │  └─────────┘  └─────────┘  └──────────────┘ ││
│  └───────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
         │                           │
         │ WebSocket + Protobuf      │ TLS + Stripe
         ▼                           ▼
┌─────────────────┐         ┌───────────────────┐
│  prod.blip.net  │         │  Peer Device      │
│  (Cloud Server) │         │  (Android/Mac/...)│
│  • Auth         │         │                   │
│  • Messaging    │         │                   │
│  • Relay        │         │                   │
│  • Device Mgmt  │         │                   │
└─────────────────┘         └───────────────────┘
```

## Layer 1: Swift UI Shell (`Blip` executable, ~5 MB per arch)

### Role
- Menu bar icon and popover (LSUIElement app — no Dock presence)
- Transfer windows with SwiftUI views
- Drag-and-drop file handling
- macOS Services integration (⌘B shortcut)
- System notifications
- Photo Library access
- Quick Look integration
- Sparkle auto-update management
- Settings UI

### Design Pattern
- **SwiftUI + Combine** for reactive UI
- **Presenter pattern**: `MenuBarPresenter`, `TransferPresenter`
- **NSHostingWindow** for SwiftUI in AppKit windows

### Evidence
- Source paths: `darwin/macOS/DesktopApp.swift`, `TransferView.swift`, `MenuBarView.swift`
- Symbols: `$s4Blip*` Swift mangled types
- Framework links: AppKit, SwiftUI, Combine, Photos, QuickLook

## Layer 2: Go Engine (`BlipKit.framework`, ~54 MB)

### Role
- All networking (LAN discovery, relay connections, WebSocket messaging)
- Transfer protocol (packing, streaming, checkpointing)
- State management (Redux-style)
- Authentication
- Local database (SQLite)
- Protobuf serialization
- Cross-platform logic shared with Android

### Internal Architecture

#### Frontend (Client-side logic)
| Component | Files | Responsibility |
|---|---|---|
| `handler/` | transfer_content, transfer_in_progress, transfer_metadata, transfer_resume, transfer_session | Transfer lifecycle management |
| `redux/` | reactor, util | Unidirectional data flow state management |
| `rpc/` | client, server, service | DRPC server providing state to Swift UI |
| `bsarchive/` | packer, unpacker, checkpoint, concat, metadata | Binary archive format for file transfers |
| `xplat/` | Platform abstractions for Darwin bookmarks, Android SAF, IPC, paths, storage |
| `state.go` | Core application state |
| `transfer.go` | Transfer coordination |
| `message.go` | Message definitions |

#### Backend (Server communication)
| Component | Files | Responsibility |
|---|---|---|
| `http/` | device, messaging, registration, relay_token, user, wire.pb | REST API client for `prod.blip.net` |
| `messaging/` | client, encoding, wire, contact, device, user, notification_token | WebSocket messaging client |
| `sqlite/` | Database operations | Local persistent storage |

#### Internal (Networking primitives)
| Component | Files | Responsibility |
|---|---|---|
| `netx/broker/` | connect, conn, token, opts | Connection brokering and negotiation |
| `netx/brokeredmtls/` | mtls | Mutual TLS via broker-provided certificates |
| `netx/lan/` | session, ips | LAN peer discovery |
| `netx/relay/` | client, packet, token | Cloud relay for NAT traversal |
| `netx/stripe/` | mux, demux, conn, dial, listen, reassembler | Multiplexed streaming protocol |
| `netx/probe/` | probe | Network path probing |
| `netx/hbeat/` | conn | Heartbeat keep-alive |
| `netx/speedtest/` | client, hello | Connection speed testing |
| `backoff/` | dialer, strategy | Exponential backoff reconnection |
| `iostats/` | kbps, stats | Throughput measurement |
| `message_queue/` | queue, packet, file_store, storage | Persistent message queue |

## IPC: Swift ↔ Go Communication

### Mechanism: DRPC
DRPC is a lightweight RPC protocol (by Storj Labs) that avoids the complexity of gRPC. It uses protobuf encoding over raw byte streams.

**Service Definition** (from `service_drpc.pb.go`):
- `DRPCServiceServer` — Go implements the service
- `DRPCServiceDescription` — Service metadata
- `DispatchRequest` — UI action dispatch to Go
- `StateRequest` / `BinaryStateResponse` — State queries

**Data Flow**:
1. Swift UI dispatches user actions via `DispatchRequest`
2. Go processes actions through Redux-style `reactor`
3. State changes flow back as `BinaryStateResponse` (protobuf-encoded)
4. Swift UI subscribes to state via Combine publishers

### Evidence
- Symbol: `_$s13SwiftProtobuf*` symbols in both Blip and BlipKit
- Types: `*rpc.DRPCServiceServer`, `*rpc.DispatchRequest`
- Source paths: `frontend/rpc/service.pb.go`, `frontend/rpc/service_drpc.pb.go`

## Network Architecture

### Connection Strategy (3-tier)

1. **LAN Direct** (preferred)
   - Package: `netx/lan/`
   - Uses LAN session tokens
   - Direct TLS connection

2. **Brokered mTLS** (NAT traversal)
   - Package: `netx/brokeredmtls/`
   - Server-brokered mutual TLS
   - X.509 fingerprint verification

3. **Cloud Relay** (fallback)
   - Package: `netx/relay/`
   - Relay tokens from `prod.blip.net`
   - Packet-based relaying through server

### Connection Broker Protocol
```
Peer A → Server: {DialId, Role, Methods, SupportsProbe, MaxTimeout, LANToken, X509Fingerprint}
Server → Peer B: (forwards connection request)
Peer B → Server: {DialId, Role, Methods, SupportsProbe, MaxTimeout, LANToken, X509Fingerprint}
Server → Both: broker connection
Peers: establish Stripe-multiplexed TLS connection
```

### Messaging Protocol
- **Transport**: WebSocket (`github.com/coder/websocket`)
- **Server**: `prod.blip.net` (IP: 137.184.135.31, port 443)
- **Encoding**: Protobuf binary, length-delimited
- **Message Types**: `ClientMessageBody` → `ServerMessageBody`
  - Device updates, contact management, user updates
  - Transfer notifications, plan updates

## Background Processes

### Login Item
`LaunchAtLoginHelper.app` — Standard macOS login item that launches Blip at login.

### Persistent Background Behavior
- **LSUIElement = true**: Runs as menu-bar-only app
- Maintains WebSocket connection to `prod.blip.net`
- Heartbeat connections for LAN discovery
- Auto-update checks every 8 hours (SUScheduledCheckInterval = 28800)

## Error Handling & Resilience
- **Backoff**: `internal/backoff/` with dialer and strategy
- **Reconnection**: Automatic with exponential backoff
- **Transfer Resume**: `handler/transfer_resume.go` — transfers can be paused and resumed
- **Crash Reporting**: Sentry SDK integration
- **Metrics**: MetricKit framework for performance data

## Confidence Assessment
- **Method**: Symbol analysis, strings extraction, library dependency analysis, embedded Go source paths
- **Confidence**: ★★★★☆ — Architecture is well-established. Internal protocols are inferred from type names and struct layouts.
- **Limitation**: Exact message formats and handshake sequences require protocol-level analysis or disassembly.
