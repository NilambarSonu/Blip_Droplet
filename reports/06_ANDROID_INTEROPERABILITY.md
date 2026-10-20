# 06 — Android Interoperability

## Core Question
Can an independently developed macOS client communicate with the existing Android Blip application without bypassing authentication or copying protected components?

## Evidence: Cross-Platform Architecture

### Shared Go Engine
The BlipKit framework contains **cross-platform Go code** that is shared between macOS and Android:

```
go/frontend/xplat/android/saf/    # Android Storage Access Framework integration
go/frontend/xplat/android/saf/access.go
go/frontend/xplat/android/saf/destination.go
go/frontend/xplat/android/saf/file.go
go/frontend/xplat/android/saf/jni_noop.go   # JNI stubs (compiled but noop on macOS)
go/frontend/xplat/android/saf/permissions.go
go/frontend/xplat/android/saf/stat.go
go/frontend/xplat/android/saf/tree.go
go/frontend/xplat/android/saf/write.go
```

**Implication**: The same Go module (`github.com/thesharingcompany/blip`) powers both the macOS and Android apps. The transfer protocol, messaging format, and authentication flow are identical at the Go level.

### Protocol Compatibility Factors

| Factor | Assessment | Evidence |
|---|---|---|
| **Protocol format** | Identical protobuf schemas on both platforms | Same `.pb.go` files compiled into macOS binary |
| **Transport** | Same Go networking stack | Cross-platform Go net/http, WebSocket, TLS |
| **Auth model** | Per-device auth, same backend | `auth_device_id`, same `prod.blip.net` server |
| **Transfer format** | Same BSArchive packer/unpacker | Go `bsarchive/` package, platform-independent |
| **Connection brokering** | Server-mediated, platform-agnostic | `broker/connect.go`, no platform-specific code |
| **Encryption** | Standard TLS/mTLS | Go `crypto/tls`, no platform-specific crypto |

## Interoperability Barriers

### Barrier 1: Proprietary Protocol (CRITICAL)
| Aspect | Detail |
|---|---|
| **Protocol** | Blip uses a proprietary binary protocol built on Protobuf + custom framing |
| **Wire format** | `wire.pb.go` — not a standard publicly documented protocol |
| **Stripe mux** | Custom multiplexing layer, not HTTP/2 or QUIC |
| **BSArchive** | Custom archive format, not ZIP/TAR |
| **Severity** | **BLOCKING** — without the protocol specification, an independent client cannot participate |

### Barrier 2: Server-Mediated Authentication (CRITICAL)
| Aspect | Detail |
|---|---|
| **Auth flow** | Devices register with `prod.blip.net` using `auth_device_id` |
| **Token system** | Relay tokens, notification tokens |
| **Registration** | `backend/http/registration.go` — server-side registration required |
| **Severity** | **BLOCKING** — a new client would need to authenticate with Blip's servers using their API |

### Barrier 3: Server-Mediated Discovery (MAJOR)
| Aspect | Detail |
|---|---|
| **Discovery** | No Bonjour/mDNS — peers discovered through cloud server |
| **LAN tokens** | LAN discovery tokens exchanged via WebSocket |
| **Implication** | Even LAN transfers require cloud connectivity for initial peer signaling |
| **Severity** | **BLOCKING** for offline/LAN-only operation |

### Barrier 4: Server-Brokered Connection Establishment (MAJOR)
| Aspect | Detail |
|---|---|
| **Broker** | Connection parameters (DialId, Role, Methods, X509Fingerprint) negotiated via server |
| **mTLS** | Mutual TLS certificates provisioned through server |
| **Relay** | Cloud relay for NAT traversal requires relay tokens from server |
| **Severity** | **BLOCKING** — cannot establish connections without server cooperation |

### Barrier 5: No Public API or Documentation
| Aspect | Detail |
|---|---|
| **Documentation** | No public API specification found |
| **SDK** | No public SDK or protocol documentation |
| **Open Source** | Not open source (private repository at `github.com/thesharingcompany/blip`) |
| **Severity** | **BLOCKING** — protocol would need to be reverse-engineered from binary |

## Compatibility Verdict

### ❌ Direct Interoperability: BLOCKED

An independently developed macOS client **cannot** communicate with the existing Android Blip application because:

1. **The protocol is proprietary**: Custom protobuf schemas, custom framing (Stripe mux), custom archive format (BSArchive)
2. **Authentication is server-dependent**: Must register with `prod.blip.net`
3. **Discovery is server-mediated**: No local broadcast discovery
4. **Connections are server-brokered**: Cannot establish peer connections independently
5. **No public API**: No documented interface for third-party clients

### Would Reverse-Engineering Help?
Even if the protocol were fully reverse-engineered:
- A new client would need to register as a **device** with Blip's servers
- This would require either:
  - Using Blip's undocumented registration API (fragile, may violate ToS)
  - Server-side cooperation from Blip Studio Inc. (unlikely for third-party clients)
- Protocol changes on the server side would break the independent client
- The server could detect and block unrecognized clients

### Alternative: Relay Through Existing Blip
The existing Blip macOS app could potentially be used as a **relay**:
- User initiates transfer on Android → arrives at macOS Blip → file available on disk
- A separate tool monitors Blip's download directory and processes files
- **Verdict**: Technically possible but indirect, not a replacement

## Confidence Assessment
- **Method**: Binary analysis of shared Go engine, cross-platform source paths, protocol structure analysis
- **Confidence**: ★★★★★ — The barriers are structural and clearly evidenced
- **Limitation**: Cannot rule out undisclosed public APIs or protocol documentation
- **Implication**: Direct interoperability with Android Blip from an independent client is **impractical** without cooperation from Blip Studio Inc.
