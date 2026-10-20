# 09 — Lightweight Replacement Architectures

## Executive Architectural Framing

The objective of this architectural evaluation is to determine whether and how an independently developed, substantially lighter personal-use macOS file-transfer companion can be constructed. The design goals are:

1. **Drastic Footprint Reduction**: Minimize disk footprint (Blip installed: 67.2 MB) and idle memory footprint (Blip measured idle: 77 MB RSS).
2. **Droppy Ecosystem Integration**: Integrate seamlessly with Droppy's notch shelf, live activities, or menu bar surfaces via DroppyKit.
3. **Android Interoperability**: Evaluate direct compatibility with the existing proprietary Android Blip app versus alternative peer-to-peer protocols.
4. **Native Apple Silicon Efficiency**: Built purely for Apple Silicon (`arm64`), leveraging macOS `Network.framework` and modern Swift concurrency without legacy universal binary or Go runtime overhead.

---

## Architectural Candidates

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CANDIDATE ARCHITECTURE OVERVIEW                       │
├───────────────────────────────┬─────────────────────────────────────────────┤
│ Option 1: Standalone Native   │ Menu Bar / LSUIElement Swift App            │
│           Companion           │ • Direct Network.framework engine           │
│                               │ • Droppy integrated via URL scheme/IPC      │
├───────────────────────────────┼─────────────────────────────────────────────┤
│ Option 2: Split Droplet +     │ DroppyKit Shelf Widget (UI)                 │
│           Background Helper   │   ↕ Local IPC (Unix Domain Socket / XPC)    │
│                               │ Lightweight Background Daemon (LaunchAgent) │
├───────────────────────────────┼─────────────────────────────────────────────┤
│ Option 3: Pure Droppy Droplet │ In-process Droplet running inside Droppy    │
│           (No Daemon)         │ • No external processes                     │
├───────────────────────────────┼─────────────────────────────────────────────┤
│ Option 4: Open Protocol       │ Native Companion / Droplet speaking         │
│           Bridge (LocalSend)  │ LocalSend or Iroh protocol to Android       │
└───────────────────────────────┴─────────────────────────────────────────────┘
```

---

## Option 1: Standalone Native macOS Companion (Swift / AppKit / Network.framework)

### Topology & Design
- **Process Model**: Single independent `LSUIElement` (menu bar extra / status bar item) written in Swift.
- **Networking Engine**: Apple's native `Network.framework` (`NWListener`, `NWConnection`, `NWBrowser`).
- **Droppy Integration**: Exposes an IPC endpoint (URL scheme or local Unix domain socket) so that Droppy can trigger file transfers or display status via a companion droplet.
- **Crypto & Serialization**: Native `CryptoKit` for TLS/SHA-256; Apple's `SwiftProtobuf` (or standard JSON/CBOR).

### Resource Projections
| Metric | Blip (Measured) | Option 1 Projection | Justification |
|---|---|---|---|
| **Binary Footprint** | 67.2 MB (Universal) | **4–8 MB** (arm64-only) | No 54 MB Go runtime/framework, single architecture, native dynamic linking |
| **Idle Memory (RSS)** | 77 MB | **14–22 MB** | Standard AppKit/SwiftUI menu bar app without Go runtime heap |
| **Idle CPU** | 0.0% | **0.0%** | Event-driven kernel socket polling (`kqueue` under `NWConnection`) |
| **Background Persistence** | LaunchAgent / Login Item | Native LaunchAgent / SMLoginItem | Always reachable for inbound transfers |

### Substantive Finding: Runtime Overhead Elimination
- **Observation**: Blip's 67.2 MB footprint and 77 MB idle RAM are overwhelmingly driven by `BlipKit.framework` (54 MB, Go runtime + statically linked deps) and redundant architectures (`x86_64` + `arm64`).
- **Evidence**: `otool -L` and `nm` confirm Go runtime, Go standard library, and Go third-party packages statically linked into a universal dylib.
- **Tool Used**: `lipo -info`, `otool -L`, `top -l 1`
- **Confidence Level**: ★★★★★ (Verified fact)
- **Limitation**: Real-world memory under sustained active multi-gigabyte transfer will depend on buffer allocation strategies.
- **Implication for Replacement**: Re-implementing purely in native Swift eliminates ~60 MB of disk footprint and ~50 MB of idle memory.

---

## Option 2: Split Droplet + Native Background Helper Daemon (LaunchAgent + DroppyKit)

### Topology & Design
This architecture separates the **User Experience** (Droppy notch shelf, HUD, settings) from the **Network & Transfer Engine** (persistent background daemon):

```
┌────────────────────────────────────────────────────────┐
│                      Droppy.app                        │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │               Blip/Droplet Plugin                │  │
│  │  • ShelfWidgetProviding (drag-drop notch shelf)  │  │
│  │  • HUDPresenting (transfer toasts & progress)    │  │
│  │  • SettingsPaneProviding (preferences)           │  │
│  └──────────────────────────┬───────────────────────┘  │
└─────────────────────────────┼──────────────────────────┘
                              │ IPC: Unix Domain Socket
                              │ /var/run/user/.../transfer.sock
┌─────────────────────────────┼──────────────────────────┐
│                             ▼                          │
│               transferd (LaunchAgent Daemon)           │
│                                                        │
│  • NWListener (inbound transfer listener)              │
│  • Persistent signaling connection                     │
│  • File I/O & integrity verification                   │
│  • Sandbox-free or scoped filesystem access            │
└────────────────────────────────────────────────────────┘
                              │ Network.framework
                              ▼
                        Peer Devices
```

### DroppyKit Surfaces Used
1. **Shelf Widget (`ShelfWidgetProviding`)**:
   - Displays paired Android device state in the MacBook Air notch shelf.
   - Accepts dropped files directly from Finder, instantly signaling `transferd` to start the stream.
2. **HUD (`HUDPresenting`)**:
   - Presents transient non-intrusive notification cards when an inbound transfer arrives or finishes.
3. **Expanded Takeover (`ExpandedSurfaceProviding`)**:
   - Detailed transfer manager showing file lists, speeds, and resume checkpoints.

### Resource Projections
| Component | Binary Footprint | Idle RAM (RSS) | Lifecycle |
|---|---|---|---|
| **Droppy Droplet** | ~1.5–3 MB | ~0 MB (dormant in Droppy) / ~8 MB (active) | Managed by Droppy process |
| **`transferd` Daemon** | ~3–6 MB (Swift/Rust) | **8–15 MB** (Swift) / **3–6 MB** (Rust) | Managed by `launchd` |
| **Combined Total** | **~5–9 MB** | **~15–25 MB** total | Continuous background readiness |

### Substantive Finding: Process Decoupling Requirement
- **Observation**: Droppy droplets run strictly within Droppy's process space and cannot independently maintain background daemons or survive Droppy quit/crash events.
- **Evidence**: DroppyKit framework headers and documentation define surface providers, not background services or daemons.
- **Tool Used**: Static analysis of `DroppyKit.framework` and `~/Projects/BridgeFlow-Droplet/work/droppykit/`
- **Confidence Level**: ★★★★★ (Verified architectural constraint)
- **Limitation**: IPC adds serialization overhead (though negligible over local Unix domain socket).
- **Implication for Replacement**: Droppy can provide an exceptional notch UI, but MUST be backed by a lightweight background daemon to receive files when Droppy is not actively focused or during sleep/wake cycles.

---

## Option 3: Pure Droppy Droplet (In-Process Only — Infeasible for Full Replacement)

### Topology & Evaluation
A pure droplet attempts to perform discovery, signaling, file transfers, and UI entirely inside Droppy without an external helper.

### Fatal Deficiencies
1. **No Inbound Background Service**: When Droppy is suspended, hidden, or terminated, all transfer listening ceases. Inbound transfers from Android would fail with connection refused or timeout.
2. **Sandboxing / Permissions**: Droplets operate under Droppy's entitlement envelope. Droppy's capabilities catalog (`DropletStoreCatalog`) grants `network-client` and `downloads`, but does not provide root network binding or arbitrary filesystem write capabilities.
3. **Process Fragility**: If Droppy is restarted, updated, or crashes, any active multi-gigabyte file transfer is instantly killed.

### Substantive Finding: Pure Droplet Infeasibility
- **Observation**: A pure droplet cannot fulfill the requirement of an autonomous background file receiver.
- **Evidence**: Droppy capability list restricts capabilities to `network-client` (outbound only) without `network-server` daemon entitlements; Droplet lifecycle is tied to Droppy UI runtime.
- **Tool Used**: Review of `DroppyKit` capability catalog and SDK documentation in `08_DROPPY_INTEGRATION_FEASIBILITY.md`
- **Confidence Level**: ★★★★★ (Definitive)
- **Limitation**: A pure droplet *could* perform one-way *outbound* transfers (drop file on shelf -> send to Android), but cannot reliably *receive* unannounced incoming transfers from Android.
- **Implication for Replacement**: Discard Option 3 as a complete standalone replacement.

---

## Option 4: Open Protocol Peer-to-Peer Bridge (LocalSend / Iroh / BridgeFlow)

### The Interoperability Dilemma
The investigation into Blip's internals (documented in `05_NETWORK_AND_TRANSFER_BEHAVIOR.md` and `06_ANDROID_INTEROPERABILITY.md`) established:
- Blip uses a proprietary, server-brokered protocol with mandatory registration at `prod.blip.net`.
- No local direct transfer can occur without signaling through Blip's private servers and obtaining `relay_token` and broker credentials.
- Direct reverse-engineering of Blip's cloud API for third-party client registration violates service integrity, is fragile, and carries high maintenance risk.

### Alternative Protocol Architecture: LocalSend Protocol
Instead of simulating the proprietary Blip cloud protocol, the companion app can utilize the established, fully open, peer-to-peer **LocalSend protocol** (or the user's existing **BridgeFlow/iroh** QUIC-based architecture):

```
┌────────────────────────────────────────────────────────┐
│                  LocalSend / Open P2P                  │
│                                                        │
│  macOS: Droplet UI + Swift Helper Daemon               │
│         • mDNS / Bonjour local discovery               │
│         • Direct LAN HTTPS / TLS REST API              │
│         • Zero cloud servers, 100% offline             │
│                                                        │
│  Android: Official LocalSend Android App (or custom)   │
│         • Available on F-Droid / Play Store            │
│         • Open source protocol                         │
└────────────────────────────────────────────────────────┘
```

### Precedent in Droppy
- **Observation**: Droppy itself already possesses string references and port handling for LocalSend (`"The LocalSend app is probably running, quit it or give Droppy a different port below"`).
- **Evidence**: String extracted from `/Applications/Droppy.app/Contents/MacOS/Droppy` at binary inspection.
- **Tool Used**: `strings /Applications/Droppy.app/Contents/MacOS/Droppy | grep -i localsend`
- **Confidence Level**: ★★★★★
- **Limitation**: The exact LocalSend droplet package was not present in Droppy's default bundle; it was developed or planned as an external droplet.

---

## Architecture Comparison Matrix

| Evaluation Dimension | Installed Blip macOS | Option 1: Standalone Swift App | Option 2: Droplet + Swift Daemon | Option 3: Pure Droplet | Option 4: LocalSend Bridge |
|---|---|---|---|---|---|
| **Binary Footprint** | 67.2 MB | **5–8 MB** | **6–10 MB** | 2–4 MB | **5–9 MB** |
| **Idle Memory (RSS)** | 77 MB | **15–20 MB** | **18–25 MB** | ~8 MB (in Droppy) | **15–22 MB** |
| **Idle CPU** | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| **Droppy Notch Shelf** | ❌ No | ⚠️ Via custom IPC | ✅ **Native DroppyKit** | ✅ Native | ✅ **Native DroppyKit** |
| **Menu Bar Support** | ✅ Yes | ✅ Native AppKit | ✅ Droplet surface | ⚠️ Limited | ✅ Yes |
| **Background Persistence** | ✅ Login Item | ✅ LaunchAgent | ✅ LaunchAgent | ❌ Dead if Droppy quits | ✅ LaunchAgent |
| **LAN-Only / Offline** | ❌ Requires Cloud | ❌ Cloud-dependent | ❌ Cloud-dependent | ❌ Infeasible | ✅ **100% Offline LAN** |
| **Android Compatibility** | ✅ Native Android Blip | ⚠️ Proprietary Blip* | ⚠️ Proprietary Blip* | ❌ Infeasible | ✅ Standard Android App |
| **Maintenance Burden** | High (Third party) | Extreme (API drift) | Extreme (API drift) | Impossible | **Very Low (Open Spec)** |

*\*Subject to the severe proprietary protocol and server-authentication barriers detailed in Report 06.*

---

## Architectural Recommendation

### Recommended Architecture: **Option 2 paired with an Open Protocol (Option 4)**

1. **User Interface**: A native **DroppyKit Droplet** leveraging:
   - `ShelfWidgetProviding` for notch drag-and-drop file staging.
   - `HUDPresenting` for native macOS Sonoma/Sequoia style transfer progress cards.
   - `SettingsPaneProviding` for device pairing and transfer paths.
2. **Transfer Engine**: A lightweight **Swift Daemon (`transferd`)**:
   - Installed as a `LaunchAgent` (`~/Library/LaunchAgents/com.user.transferd.plist`).
   - Communicates with the Droplet over a local Unix domain socket (`/tmp/transferd.sock`).
   - Uses `Network.framework` for asynchronous, zero-copy socket I/O.
   - Operates with an idle memory footprint under **15 MB RSS** and zero background CPU.
3. **Protocol Layer**:
   - For complete independence, adopt an open local-network protocol (LocalSend specification or Iroh QUIC) paired with the corresponding Android client.
   - If strict Blip Android compatibility is pursued, implement a protocol proxy that isolates the proprietary wire formats into a discrete plug-in module.
