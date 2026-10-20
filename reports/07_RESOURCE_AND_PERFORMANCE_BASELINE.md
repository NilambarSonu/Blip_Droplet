# 07 — Resource & Performance Baseline

## Measurement Methodology

All measurements taken from a running Blip instance on the investigation machine using standard macOS tools (`ps`, `top`, `lsof`, `du`). The application was in its normal idle state (menu bar present, WebSocket connected, no active transfers).

> [!WARNING]
> Active transfer measurements were NOT performed during this investigation because no Android transfer was initiated. The idle measurements below are real; active-transfer values are **estimated** from architecture analysis and marked accordingly.

## Idle Baseline (Measured)

| Metric | Value | Tool | Notes |
|---|---|---|---|
| **Processes** | 1 | `ps aux \| grep Blip` | Single process, PID 5838 |
| **Idle RAM** | 77 MB | `top -l 1` (MEM column) | Includes Go runtime, Swift UI, WebSocket |
| **Idle CPU** | 0.0% | `top -l 1` (CPU column) | Effectively zero when not transferring |
| **Network Connections** | 1 | `lsof -i \| grep Blip` | Single persistent WebSocket to 137.184.135.31:443 |
| **Uptime** | 1+ day | `ps` start time: `Sat05PM` | Stable, no crashes observed |

## Disk Footprint (Measured)

| Component | Size |
|---|---|
| **App Bundle** | 67 MB |
| **User Preferences** | 4 KB |
| **Cache** | 136 KB |
| **HTTP Storage** | 60 KB |
| **Crash Data** | 4 KB |
| **Share Container** | 36 KB |
| **Preview Container** | 4 KB |
| **Total User Data** | ≈244 KB |
| **Total Installed Footprint** | ≈67.2 MB |

### App Bundle Breakdown
| Component | Size | Percentage |
|---|---|---|
| BlipKit.framework | ~54 MB | 80.6% |
| Sparkle.framework | ~1.6 MB | 2.4% |
| Blip executable | ~5 MB (est. per arch × 2) | 14.9% |
| Resources (icons, sounds, nibs) | ~3.5 MB | 5.2% |
| Extensions + Login Item | ~1.4 MB | 2.1% |
| libswiftCompatibilitySpan | 184 KB | 0.3% |

> [!NOTE]
> **BlipKit.framework dominates at 80.6%** of the bundle. This is because it contains a compiled Go binary (with the Go runtime, standard library, and all dependencies statically linked). Universal binary (x86_64 + arm64) roughly doubles this.

## Estimated Active Transfer Performance

> [!CAUTION]
> The following are **estimates** based on architectural analysis. They have NOT been measured.

| Metric | Estimated Range | Basis |
|---|---|---|
| **Active RAM** | 100–200 MB | Go runtime with BSArchive packing, Stripe multiplexing buffers, file I/O buffers |
| **Active CPU** | 10–30% | TLS encryption, file I/O, archive packing, protobuf serialization. M5 efficiency would be high. |
| **Transfer Speed (LAN)** | Near wire speed (100+ Mbps) | Stripe multiplexing over direct TLS. Go's net/http and TLS are efficient. |
| **Transfer Speed (Relay)** | Server-limited | Relay through DigitalOcean (137.184.x.x IP range) |
| **Energy Impact** | Medium during transfer | CryptoKit hardware acceleration on M5, but sustained I/O and network |

## Comparison Framework

### What Makes Blip 67 MB?
1. **Go runtime** (~10 MB per architecture): garbage collector, scheduler, reflection
2. **Go standard library** (crypto, net, compress): statically linked
3. **Protobuf runtime** (~2 MB): full google.golang.org/protobuf
4. **Third-party Go deps** (~5 MB): websocket, chi router, xxhash, hdrhistogram, etc.
5. **Universal binary**: x86_64 + arm64 ≈ 2× the above
6. **Swift runtime** + SwiftUI: system-provided, not counted in bundle
7. **Sparkle**: 1.6 MB for auto-update

### Where Could a Replacement Save?
| Area | Current | Potential Saving |
|---|---|---|
| **Go runtime overhead** | ~20 MB (universal) | Swift or Rust has no GC runtime |
| **Universal binary** | ~2× native | arm64-only ≈ 50% |
| **Unused Go dependencies** | ~10 MB | A focused replacement wouldn't need chi, hdrhistogram, etc. |
| **Sparkle** | 1.6 MB | Could use macOS built-in update or simpler check |
| **Realistic minimum** | — | 5–15 MB for a native arm64 Swift app |

### RAM Comparison
| Factor | Blip | Potential Replacement |
|---|---|---|
| **Go runtime** | ~15 MB baseline | 0 (native Swift/Rust) |
| **UI layer** | ~20 MB (SwiftUI) | ~10 MB (minimal SwiftUI or AppKit) |
| **Network stack** | ~10 MB | ~5 MB (URLSession or NWConnection) |
| **Transfer buffers** | Variable | Similar (I/O buffers are I/O buffers) |
| **Estimated idle** | 77 MB | 20–40 MB (achievable but speculative) |

> [!IMPORTANT]
> A smaller binary does **not** automatically mean less RAM. The Go runtime's baseline is a factor, but active-transfer memory depends on buffer sizes and file counts, which would be similar in any implementation. The 77 MB idle measurement includes the full Go runtime and GC heap.

## Confidence Assessment
- **Idle measurements**: ★★★★★ — Direct observation with system tools
- **Active estimates**: ★★☆☆☆ — Educated guesses based on architecture, not measured
- **Comparison**: ★★★☆☆ — General industry knowledge, specific savings unverified
- **Limitation**: No active transfer was performed; no energy measurements via `powermetrics`
