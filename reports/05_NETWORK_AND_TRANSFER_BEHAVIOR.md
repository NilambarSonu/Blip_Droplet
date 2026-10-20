# 05 — Network & Transfer Behavior

## Active Network Connections (Observed)

At idle, Blip maintains a single persistent connection:

```
Blip  5838  nilambarbehera  24u  IPv4  TCP  172.22.148.211:64500 → 137.184.135.31:443 (ESTABLISHED)
```

| Property | Value | Evidence |
|---|---|---|
| **Server IP** | 137.184.135.31 | `lsof -i` output |
| **Server Domain** | prod.blip.net | Info.plist `ServerURL` |
| **Port** | 443 (TLS) | `lsof -i` |
| **Protocol** | WebSocket over TLS | `github.com/coder/websocket` in Go dependencies |
| **Connection Count** | 1 (idle) | `lsof -i` |
| **Direction** | Client → Server (outbound only) | TCP socket state |

> [!NOTE]
> **Observation**: A single persistent WebSocket connection to the Blip cloud server. No listening sockets. This means Blip does **not** run a local server for LAN discovery — it uses outbound connections only.

## Network Protocol Stack

### Layer 1: Cloud Messaging (Always Active)
| Property | Detail | Evidence |
|---|---|---|
| **Transport** | WebSocket over TLS 1.2/1.3 | `coder/websocket` module, TLS strings |
| **Server** | `prod.blip.net:443` | Info.plist, lsof |
| **Encoding** | Protobuf binary, length-delimited | `SwiftProtobuf` bundle, `wire.pb.go` |
| **Message Types** | `ClientMessageBody` / `ServerMessageBody` | Symbol extraction |
| **Heartbeat** | Present (hbeat package) | `internal/netx/hbeat/conn.go` |
| **Auth** | Device-based (`auth_device_id`, `auth_user_id`) | Protobuf field tags |
| **Purpose** | Device registration, contact management, transfer signaling, notifications | Source paths |

### Layer 2: Transfer Connection Brokering
When a transfer is initiated, the cloud server **brokers** a direct connection:

```
Sender → prod.blip.net: "I want to send to PeerID X"
Server → Recipient: "PeerID Y wants to send to you"
Server: Provides connection method negotiation
Both peers: Establish direct connection via best available method
```

**Connection methods** (from broker struct):
1. **LAN Direct** — same network, discovered via LAN tokens
2. **Brokered mTLS** — server-mediated mutual TLS handshake
3. **Cloud Relay** — packets relayed through server (fallback)

### Layer 3: Transfer Data Protocol
| Property | Detail | Evidence |
|---|---|---|
| **Multiplexing** | Custom "Stripe" protocol | `netx/stripe/` (mux, demux, reassembler) |
| **Encryption** | mTLS with X.509 fingerprint verification | `brokeredmtls/mtls.go`, `X509Fingerprint *[32]uint8` |
| **Archive Format** | "BSArchive" — binary streaming archive | `frontend/bsarchive/` (packer, unpacker) |
| **Checkpointing** | Resumable transfers with checkpoints | `bsarchive/checkpoint.go` |
| **Compression** | libz linked, likely zlib/deflate | `libz.1.dylib` dependency |
| **Speed Monitoring** | Real-time Mbps tracking | `internal/iostats/kbps.go` |

## Transfer Lifecycle (Inferred)

```
1. CREATION     → User selects files and recipient
2. PREFLIGHT    → Transfer plan created (plan.pb.go)
3. SIGNALING    → Server brokers connection between peers
4. NEGOTIATION  → Broker exchange: DialId, Role, Methods, LANToken, X509Fingerprint
5. CONNECTION   → Best transport selected (LAN > mTLS > Relay)
6. STREAMING    → Files packed into BSArchive, streamed via Stripe mux
7. PROGRESS     → Real-time progress via iostats
8. COMPLETION   → Unpacker extracts files at destination
   OR PAUSE     → Checkpoint saved for resume
   OR CANCEL    → Transfer cancelled, cleanup
   OR ERROR     → Retry with backoff
```

### Evidence for Each Stage
| Stage | Evidence |
|---|---|
| Creation | `TransferCreationToolbar`, `TransferFilePickerButton`, `TransferPeerPickerView` |
| Preflight | `*event.TransferPreflightComplete`, `plan.pb.go` |
| Signaling | `backend/messaging/wire.pb.go`, WebSocket messages |
| Negotiation | Broker struct with DialId/Methods/LANToken/X509Fingerprint |
| Connection | `netx/broker/connect.go`, `brokeredmtls/mtls.go`, `relay/client.go` |
| Streaming | `bsarchive/packer.go`, `stripe/mux.go`, `stripe/dial.go` |
| Progress | `TransferProgressToolbar`, `iostats/kbps.go` |
| Completion | `TransferCompletionToolbar`, `bsarchive/unpacker.go` |
| Pause/Resume | `handler/transfer_resume.go`, `bsarchive/checkpoint.go` |
| Cancel | `TransferCancellationToolbar`, `"Cancel this transfer"` |

## Authentication & Security

### Device Authentication
| Property | Detail |
|---|---|
| **Model** | Device-based auth, not session-based |
| **Identifiers** | `auth_device_id`, `auth_user_id`, `PeerId` |
| **Registration** | `backend/http/registration.go` |
| **Tokens** | `relay_token.go`, `notification_token.go` |
| **Notification** | `NotificationToken_ServiceKind` (APNS/FCM) |

### Transport Security
| Property | Detail |
|---|---|
| **TLS** | Standard TLS with X.509 certificates |
| **mTLS** | Mutual TLS for peer connections |
| **Certificate Pinning** | X.509 fingerprint exchange during broker negotiation |
| **Crypto** | CryptoKit framework, X25519 key exchange, AES, ChaCha20Poly1305, HMAC-SHA256, HKDF |
| **Localhost Exception** | `NSExceptionAllowsInsecureHTTPLoads` for localhost only |

### Evidence for Crypto
- Strings: `X25519`, `AES-NI`, `ChaCha8`, `chacha20poly1305`, `HMAC-SHA2-256`, `HKDF-SHA2-256`
- Framework: `CryptoKit.framework`, `Security.framework`
- Go: `crypto/tls`, `crypto/x509`, `crypto/ecdh`, `crypto/sha256`

## DNS / Network Discovery

### LAN Discovery
- **Package**: `internal/netx/lan/`
- **Method**: LAN session tokens exchanged through server, then direct connection attempted
- **No Bonjour/mDNS**: Blip does NOT use Apple's Bonjour for discovery (no `_tcp` service types in Blip's entitlements or Info.plist)
- **No MultipeerConnectivity**: No MultipeerConnectivity framework linked

> [!IMPORTANT]
> Blip's LAN discovery is **server-mediated**, not peer-to-peer broadcast. Both devices must be registered with `prod.blip.net` and exchange LAN tokens through the WebSocket. This means LAN transfers still require cloud connectivity for initial signaling.

## ATS (App Transport Security)
```
NSAppTransportSecurity: {
    NSExceptionDomains: {
        localhost: {
            NSExceptionAllowsInsecureHTTPLoads: true
        }
    }
}
```
Only localhost is exempted; all other connections require TLS.

## Confidence Assessment
- **Method**: `lsof -i`, `otool -L`, `strings`, embedded Go paths, protobuf field tags
- **Confidence**: ★★★★☆ — Network architecture clearly established. Exact protocol wire format requires packet capture or disassembly.
- **Limitation**: No network traffic was captured during an actual transfer. Transfer protocol behavior is inferred from binary analysis.
- **Implication**: Reproducing the transfer protocol requires reverse-engineering protobuf schemas and the Stripe multiplexing format.
