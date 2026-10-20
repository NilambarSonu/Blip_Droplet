# 03 — Static Binary Analysis

## Executive Summary
Blip is a **hybrid Swift + Go application** with a unique architecture: a native Swift/SwiftUI macOS shell (the `Blip` executable) that loads `BlipKit.framework`, a 54 MB universal framework containing a **compiled Go binary linked via cgo**. The Go code is the core engine built from `github.com/thesharingcompany/blip`.

## Main Executable: `Blip`

### Architecture
- **Format**: Mach-O universal (x86_64 + arm64)
- **Language**: Swift (SwiftUI + AppKit)
- **Role**: UI shell — menu bar, transfer windows, settings, notifications
- **Evidence**: Swift mangled symbols (`$s4Blip*`), SwiftUI/AppKit framework links, `.swift` source paths

### Key System Framework Dependencies
| Framework | Purpose |
|---|---|
| AppKit | Native macOS UI |
| SwiftUI | Declarative UI for transfer views |
| Combine | Reactive data binding |
| Photos / PhotosUI | Photo Library direct access |
| QuickLookThumbnailing / QuickLookUI | File preview thumbnails |
| ServiceManagement | Login item registration |
| IOKit | Hardware/device information |
| CoreFoundation / Foundation | Base system services |

### Key Swift Types (from symbols and strings)
| Type | Purpose | Evidence |
|---|---|---|
| `DesktopApplication` | NSPrincipalClass — app delegate | Info.plist |
| `MenuBarPresenter` | Menu bar icon management | Strings: `Blip.MenuBarPresenter` |
| `MenuBarPopoverView` | Popover UI | Strings |
| `TransferPresenter` | Transfer lifecycle coordinator | Strings: `Blip.TransferPresenter` |
| `TransferWindow` | Transfer window management | Strings: `_TtC4Blip14TransferWindow` |
| `TransferSplitViewController` | Split view for transfer UI | Strings |
| `TransferView` | Main transfer view | Source path: `Blip/TransferView.swift` |
| `TransferDockTile` | Dock tile progress display | Strings |
| `SparkleUpdater` | Auto-update integration | Source path |
| `ServicesProvider` | macOS Services handler | Source path |

### Build Source Paths (from debug strings)
```
/Users/runner/_work/push/push/darwin/macOS/DesktopApp.swift
/Users/runner/_work/push/push/darwin/macOS/SparkleUpdater.swift
/Users/runner/_work/push/push/darwin/macOS/ServicesProvider.swift
/Users/runner/_work/push/push/darwin/macOS/Settings/GeneralSettingsView.swift
/Users/runner/_work/push/push/darwin/macOS/Transfers/TransferView.swift
/Users/runner/_work/push/push/darwin/macOS/Transfers/TransferPresenter.swift
/Users/runner/_work/push/push/darwin/macOS/Peers/EditAvatarView.swift
```

> [!IMPORTANT]
> The internal project name is **"push"**, built in a CI runner (`/Users/runner/_work/push/push/`). The macOS-specific Swift code lives under `darwin/macOS/`.

---

## BlipKit Framework: The Go Core Engine

### Overview
- **Size**: 54 MB (universal x86_64 + arm64)
- **Language**: Go (compiled via cgo), with Swift interop layer
- **Go Module**: `github.com/thesharingcompany/blip`
- **Role**: Core transfer engine, networking, authentication, state management, protobuf serialization

### Framework Dependencies
| Dependency | Purpose |
|---|---|
| Network.framework | Apple Network.framework for transport |
| CryptoKit | Cryptographic operations |
| Security | Certificate/key management |
| CoreData | Persistent storage (linked but sqlite actually used) |
| AVFAudio / AVFoundation | Sound effects, media handling |
| Contacts | Contact lookup for peer display |
| Intents | Siri integration (INSendMessageIntent) |
| MapKit | Location-related features |
| MetricKit | Performance metrics |
| LinkPresentation | Rich URL previews |
| SystemConfiguration | Network reachability |
| libz | Compression |
| libresolv | DNS resolution |

### Go Source Architecture (from embedded debug paths)

```
github.com/thesharingcompany/blip/
├── go/
│   ├── backend/
│   │   ├── http/           # HTTP API client (device, messaging, registration, relay_token, user)
│   │   ├── messaging/      # WebSocket messaging (client, contact, device, encoding, wire)
│   │   └── sqlite/         # Local SQLite database
│   ├── frontend/
│   │   ├── handler/        # Transfer handlers (content, in_progress, metadata, resume, session)
│   │   ├── redux/          # Redux-pattern state management
│   │   ├── rpc/            # DRPC server/client for Swift↔Go IPC
│   │   ├── bsarchive/      # Binary archive format (packer, unpacker, checkpoint)
│   │   ├── monitor/        # Crash reporting, logging
│   │   ├── xplat/          # Cross-platform abstractions
│   │   │   ├── android/saf/    # Android Storage Access Framework
│   │   │   ├── darwin/         # macOS bookmarks, photo library
│   │   │   ├── destination/    # File destination handling
│   │   │   ├── ipc/           # Inter-process communication
│   │   │   └── sem/           # Semaphores
│   │   ├── state.go        # Application state
│   │   ├── transfer.go     # Transfer logic
│   │   └── message.go      # Message definitions
│   ├── internal/
│   │   ├── netx/
│   │   │   ├── broker/     # Connection brokering (connect, token, opts)
│   │   │   ├── brokeredmtls/  # Mutual TLS via broker
│   │   │   ├── lan/        # LAN session discovery
│   │   │   ├── relay/      # Cloud relay fallback
│   │   │   ├── stripe/     # Multiplexed streaming (mux, demux, reassembler)
│   │   │   ├── probe/      # Network probing
│   │   │   ├── hbeat/      # Heartbeat connections
│   │   │   ├── speedtest/  # Speed test client
│   │   │   ├── nethost/    # Host address management
│   │   │   ├── sockopt/    # Socket options (Apple Network Service Type)
│   │   │   └── tiebreak/   # Connection tiebreaking
│   │   ├── backoff/        # Exponential backoff dialer
│   │   ├── iostats/        # I/O throughput stats
│   │   ├── iox/            # I/O utilities
│   │   ├── message_queue/  # Persistent message queue
│   │   ├── observable/     # Observable pattern
│   │   ├── rcmap/          # Reference-counted map
│   │   ├── search/         # Contact search
│   │   └── single_runner/  # Single-instance runner
│   ├── *.pb.go files       # Protocol Buffer definitions
│   └── *.go files          # Core types (device, user, peerid, log, relay_token)
└── darwin/macOS/           # Swift UI layer
```

### Third-Party Go Dependencies
| Module | Purpose |
|---|---|
| `github.com/coder/websocket` | WebSocket client for backend messaging |
| `github.com/go-chi/chi/v5` | HTTP router (internal web UI/diagnostics) |
| `github.com/HdrHistogram/hdrhistogram-go` | Latency histograms |
| `github.com/alitto/pond` | Worker pool |
| `github.com/cespare/xxhash/v2` | Fast hashing |
| `github.com/clipperhouse/jargon` | Text tokenization (for search) |
| `github.com/alextanhongpin/stringdist` | String distance (Jaro-Winkler, contact matching) |
| `google.golang.org/protobuf` | Protocol Buffers runtime |
| `golang.org/x/text` | Unicode text processing |
| Sentry SDK (Swift) | Crash reporting |

### Protobuf Definitions (from embedded proto paths)
| Proto File | Content |
|---|---|
| `device.proto` | Device registration, settings, updates |
| `peerid.proto` | Peer identification |
| `frontend/rpc/service.proto` | DRPC service definition (Swift↔Go) |
| `frontend/rpc/service_drpc.pb.go` | Generated DRPC stubs |
| `frontend/bsarchive/entities.proto` | Archive entity definitions |
| `frontend/auth.pb.go` | Authentication messages |
| `frontend/message.pb.go` | Inter-component messages |
| `frontend/onboarding.pb.go` | Onboarding flow |
| `frontend/search.pb.go` | Search queries |
| `frontend/state.pb.go` | Application state |
| `frontend/state_inner.pb.go` | Internal state |
| `frontend/transfer.pb.go` | Transfer protocol |
| `notification.pb.go` | Notification tokens |
| `plan.pb.go` | Transfer plan |
| `user.pb.go` | User data |
| `user_agent.pb.go` | User agent info |
| `backend/http/wire.pb.go` | HTTP wire format |
| `backend/messaging/wire.pb.go` | Messaging wire format |

### Key Protobuf Fields Extracted
```
auth_device_id, auth_user_id
download_mbps, upload (implied)
is_executable, is_searchable
sender_peer_id
shutting_down
subscribed_at
device_model, service_kind, service_type
relay_token
transfer_id
```

### Swift↔Go IPC Mechanism
**DRPC** (a lightweight RPC protocol, not gRPC) is used for communication between the Swift UI and the Go engine:
- `rpc.DRPCServiceDescription` / `rpc.DRPCServiceServer`
- `rpc.DispatchRequest` / `rpc.StateRequest` / `rpc.BinaryStateResponse`
- Evidence: `service_drpc.pb.go`, DRPC types in symbol table

### Connection Broker Architecture (from embedded struct types)
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
This reveals the **connection negotiation** protocol: peers exchange dial IDs, roles, supported connection methods, LAN tokens, and X.509 certificate fingerprints for mutual TLS.

### Stripe Multiplexer
The `stripe` package implements a custom **multiplexed streaming** protocol:
- `stripe.Mux` / `stripe.Demux` — multiplexer/demultiplexer
- `stripe.Conn` — multiplexed connection
- `stripe.Listen` / `stripe.Dial` — listen/dial interfaces
- Write jobs with `{offset int64, payload []byte, success func()}`
- Region mapping for multi-path striping

## Confidence Assessment
- **Method**: `strings`, `nm -g`, `otool -L`, embedded debug paths
- **Confidence**: ★★★★☆ — Architecture is clearly established from Go module paths, proto definitions, and type information. Exact protocol details require disassembly.
- **Limitation**: Without a disassembler, function logic is inferred from names and types, not from decompiled code. Go runtime strings include many false positives from the Go standard library.
