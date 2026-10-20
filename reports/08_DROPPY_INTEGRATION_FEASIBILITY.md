# 08 — Droppy Integration Feasibility

## Droppy Overview

| Property | Value | Evidence |
|---|---|---|
| **Path** | `/Applications/Droppy.app` | mdfind |
| **Bundle ID** | `iordv.Droppy` | Info.plist |
| **Version** | 16.1.2-beta.1 (build 16120001) | Info.plist |
| **Architecture** | arm64 only | `DroppyDistributionArchitecture` |
| **Bundle Size** | 182 MB | `du -sh` |
| **Min macOS** | 14.0 | Info.plist |
| **Framework** | DroppyKit.framework | Embedded in bundle |
| **Bonjour** | `_companion-link._tcp`, `_droppysync._tcp` | NSBonjourServices |
| **LocalSend** | Mentioned in Droppy strings (port conflict message) | `strings` analysis |

## DroppyKit SDK

### Architecture
DroppyKit is the official SDK for building **Droplets** — extensions that live inside Droppy. Found at:
- **Installed**: `/Applications/Droppy.app/Contents/Frameworks/DroppyKit.framework/`
- **Source**: `~/Projects/BridgeFlow-Droplet/work/droppykit/` (git repository)
- **Online**: [getdroppy.app/docs/droppykit](https://getdroppy.app/docs/droppykit)

### Current SDK Version
- **Release**: 1.20.1 (ABI 1)
- **Requires**: macOS 14+, Swift 6.2 (Xcode 26), Droppy 15.3+

### Available Surfaces
| Surface | Protocol | Description |
|---|---|---|
| **Shelf widget** | `ShelfWidgetProviding` | Notch shelf widgets, solo and paired |
| **Live activity** | `LiveActivityProviding` | Compact and expanded activities |
| **Expanded takeover** | `ExpandedSurfaceProviding` | Full takeover surface |
| **Settings pane** | `SettingsPaneProviding` | Settings inside Droppy |
| **HUD** | `HUDPresenting` | Transient heads-up display |
| **Lock screen row** | `LockScreenStatusProviding` | Lock screen status |
| **Menu bar extra** | `MenuBarExtraProviding` | Menu bar items |

### Available Capabilities (from DropletStoreCatalog)
- `network-client` — outbound network access
- `accessibility` — accessibility API access
- `apple-events` — AppleScript/Apple Events
- `clipboard-read` / `clipboard-write`
- `global-shortcuts`
- `downloads` — Downloads folder access
- `microphone`, `speech-recognition`
- `hud` — HUD presentation

### Droplet Build System
```bash
droppykit new <id> --name "Name"     # Scaffold
droppykit run                         # Test in harness
droppykit build                       # Universal .droplet bundle
droppykit validate                    # Submission checks
droppykit submit                      # Submit to Store
```

### Agent Integration
DroppyKit includes MCP server (`droppykit mcp`) for coding agents, with `AGENTS.md`, `CLAUDE.md` templates. Screenshots and JSON verdicts available.

## Can a Droplet Replace Blip's Functionality?

### Feasibility Matrix

| Blip Feature | Droplet Surface | Feasible? | Notes |
|---|---|---|---|
| **Menu bar icon** | `MenuBarExtraProviding` | ✅ Yes | Droplets can add menu bar extras |
| **Transfer notifications** | `HUDPresenting` + macOS Notifications | ✅ Yes | HUD cards for transfer alerts |
| **Transfer progress** | `ShelfWidgetProviding` | ✅ Yes | Progress bar in shelf widget |
| **Device selection** | `ShelfWidgetProviding` / `ExpandedSurfaceProviding` | ✅ Yes | Device picker in expanded view |
| **Settings** | `SettingsPaneProviding` | ✅ Yes | Configuration in Droppy Settings |
| **File drag & drop** | Shelf widget accepts drops | ⚠️ Partial | Shelf accepts drops but behavior is limited |
| **File opening/saving** | `downloads` capability | ⚠️ Partial | Downloads folder access, but general file access limited |
| **Background transfer handling** | ❌ No persistent process | ❌ No | **Droplets run inside Droppy's process, not independently** |
| **Persistent network connections** | `network-client` | ⚠️ Partial | Can make outbound requests, but WebSocket lifecycle unclear |
| **Automatic startup** | Via Droppy's own startup | ⚠️ Indirect | Droplet starts when Droppy starts |
| **Background WebSocket** | ❌ No independent daemon | ❌ No | Cannot maintain persistent background connection |
| **LAN peer discovery** | `network-client` | ⚠️ Partial | Can use network, but complex discovery may be unreliable |
| **Direct peer-to-peer transfers** | `network-client` | ⚠️ Partial | Network access available, but full transfer protocol is complex |

### Critical Limitation: No Independent Process

> [!CAUTION]
> **A Droplet is NOT an independent application.** It runs inside Droppy's process space, on Droppy's surfaces, and is subject to Droppy's lifecycle management. A Droplet:
> - Cannot run when Droppy is not running
> - Cannot fork background daemons
> - Cannot maintain persistent connections independently
> - Cannot register as a macOS Service
> - Cannot register URL schemes independently
> - Cannot have its own Dock tile

This means a **pure Droplet cannot fully replace Blip**, which requires:
1. A persistent background WebSocket to `prod.blip.net` (or equivalent server)
2. The ability to receive incoming transfer signals at any time
3. Background file operations during transfers

### What a Droplet CAN Do
A Droplet can serve as a **companion UI** to a background helper:
- Display transfer status in the notch shelf
- Show device list and connection status
- Accept drag-and-drop files for sending
- Show transfer progress with HUD notifications
- Provide settings configuration
- Trigger transfers via menu bar extra

## Existing Precedent: LocalSend in Droppy

Droppy already has **LocalSend** integration mentioned in its strings:
```
is already in use. The LocalSend app is probably running, quit it or give Droppy
a different port below.
```

This confirms that Droppy can integrate with local file-transfer protocols through its droplet system, but the actual LocalSend droplet was not found in the installed droplet catalog.

## Existing Research: BridgeFlow-Droplet Project

The user has an existing `~/Projects/BridgeFlow-Droplet/` project that:
- Contains a **DroppyKit SDK clone** (`work/droppykit/`)
- Contains the **Bridge project** (`work/Bridge/`) — a phone mirroring app using iroh/dumbpipe/QUIC
- Has conducted protocol checks (`ProtocolChecks.swift`, `protocol-results.txt`)
- Has built and verified artifacts (`verified-artifact/`)
- Has cloud evidence screenshots

### Bridge Project Architecture
Bridge uses **iroh** (QUIC-based networking with hole punching and relay fallback) — a fundamentally different approach from Blip's custom protocol.

## Droppy-Specific Constraints

### DroppyKit Build Requirements
- **Xcode 26 (Swift 6.2)**: The DroppyKit README states `macOS 14 or later, Swift 6.2 (Xcode 26)`. This conflicts with the "no Xcode" constraint. However, Swift 6.2 command-line tools may suffice.
- **Resilient framework**: Droplets must link against the resilient framework from the Droppy binary, not a local build

### Droplet Distribution
- Droplets can be loaded locally (Settings → Store → Local droplets)
- No App Store requirement
- Each new build requires user approval when Droppy opens

## Confidence Assessment
- **DroppyKit SDK analysis**: ★★★★★ — Full README and COMPATIBILITY.md reviewed
- **Droplet limitations**: ★★★★☆ — Well-documented in SDK, confirmed by architecture analysis
- **Blip integration feasibility**: ★★★★☆ — Clear structural barriers identified
- **Limitation**: Exact Droplet process lifecycle and network capabilities not tested experimentally
