# 20 — BlipKit Headless Feasibility & Boundary Verification

## Executive Summary

This report establishes the forensic technical boundaries of the installed `BlipKit.framework` (`/Applications/Blip.app/Contents/Frameworks/BlipKit.framework`), answering whether an independent, third-party headless host executable can legally and technically load and control the official Blip engine on macOS Apple Silicon.

### Definitive Technical Verdict: UNSUPPORTED & STRUCTURALLY INFEASIBLE
> [!CAUTION]
> **A third-party headless executable CANNOT successfully host or execute `BlipKit.framework` without Blip Studio's proprietary Developer ID Team signature and provisioning profile.**
> 1. `BlipKit` has no public C headers, module maps (`.swiftmodule`), or documented public APIs.
> 2. It mandates macOS Application Group sandboxing (`AY8UB8KTUX.blip`), which macOS kernel security binds strictly to Developer Team ID `AY8UB8KTUX`.
> 3. The internal DRPC interface operates exclusively over in-process Go memory channels, exposing zero external inter-process communication (IPC) ports.

---

## 1. Boundary Inspection & Framework Structure

### Bundle Layout (`find .../BlipKit.framework`)
```
/Applications/Blip.app/Contents/Frameworks/BlipKit.framework/
├── Versions/
│   └── A/
│       ├── BlipKit (56,590,256 bytes universal Mach-O shared library)
│       ├── Resources/ (Assets.car, Info.plist, sound files)
│       └── _CodeSignature/ (CodeResources)
└── BlipKit -> Versions/Current/BlipKit
```

### Critical Missing Components
- **No `Headers/` directory**: No Objective-C or C bridging headers are exported.
- **No `Modules/` directory**: No `module.modulemap` or Swift `.swiftmodule` interface files exist.
- **Classification**: `BlipKit.framework` is a **strictly private embedded dynamic library**, architected solely for internal bundling inside `Blip.app`.

---

## 2. Public vs. Private Symbol Inventory

Inspection via `nm -gU` and `otool -L` demonstrates that every substantive symbol within `BlipKit` is private:

| Symbol / Component | Export Visibility | Architectural Role | Third-Party Viability |
|---|---|---|---|
| `_BlipKitVersionNumber` | Public C Global | Version tracking | Read-only constant |
| `_BlipKitVersionString` | Public C Global | Version string | Read-only constant |
| `LibBlip.configureLogs` | Private Swift mangled (`$s7BlipKit...`) | Logger path initialization | Internal Darwin setup |
| `LibBlip.setCrashOutput` | Private Swift mangled (`$s7BlipKit...`) | Crash logging redirection | Internal Darwin setup |
| `ItemResolver` | Private Swift Class | Drag-and-drop URL resolution | Internal SwiftUI helper |
| `BookmarkStore` | Private Swift Class | Security-scoped bookmark store | Internal Darwin storage |
| `frontend/rpc.Service` | Private Go DRPC struct | In-process Redux state bridge | Internal memory channel only |
| `netx/broker` | Private Go package | Signaling & LAN connection | Internal networking engine |

There are **zero documented, public, or stable developer-facing APIs**.

---

## 3. Mandatory Initialization & Lifecycle Dependencies

To bootstrap without crashing, `BlipKit` mandates a tightly coupled environment:

1. **Darwin Application Group Container (`AY8UB8KTUX.blip`)**:
   - `BlipKit` immediately attempts to open its SQLite databases in `/Users/nilambarbehera/Library/Group Containers/AY8UB8KTUX.blip/`:
     - `logs.sqlite` (activity & event history)
     - `msg-queue.sqlite` (offline outgoing queue)
     - `Cache.db` (HTTP response and avatar cache)
   - If this directory cannot be read or locked, `BlipKit` aborts or deadlocks.
2. **AppKit RunLoop & Main Thread Binding**:
   - `BlipKit`'s Swift components instantiate Combine publishers (`ObservableObject`) and SwiftUI view controllers that require an active `NSApplication` runloop.
3. **Keychain Access Groups**:
   - Device keys and authentication bearer tokens (`auth_device_id`, `auth_user_id`) are stored in Keychain partitions scoped to `AY8UB8KTUX.blip`.

---

## 4. The Fatal Security & Sandboxing Barriers for Headless Hosting

### Barrier 1: Application Group Provisioning & Kernel Enforcement
Inspection of `/Applications/Blip.app` entitlements reveals:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>AY8UB8KTUX.blip</string>
</array>
```
On macOS:
- An executable can only access an App Group container prefixed with `AY8UB8KTUX.` if it is signed with a provisioning profile authorized by Apple for **Team ID `AY8UB8KTUX`** (Blip Studio Inc.).
- Any custom binary compiled on this machine will carry an ad-hoc signature or a different developer Team ID.
- When an unauthorized binary attempts to access `AY8UB8KTUX.blip`, macOS kernel sandbox returns `EPERM` (`Operation not permitted`).

### Barrier 2: Hardened Runtime & Code Signing Requirements
Inspection of `BlipKit` code signing requirement (`codesign -d -r-`):
```text
designated => anchor apple generic and identifier "net.blip.macos.blipkit" and ... certificate leaf[subject.OU] = AY8UB8KTUX
```
Under macOS Hardened Runtime:
- Loading a third-party framework signed with Team `AY8UB8KTUX` into an unsigned or differently signed executable will fail library validation unless `com.apple.security.cs.disable-library-validation` is granted.
- Even if library validation is disabled, Barrier 1 (App Group sandbox rejection) permanently blocks access to the database.

### Barrier 3: In-Process DRPC Architecture
- The DRPC server (`/rpc.Service/GetState`, `/rpc.Service/Dispatch`) communicates exclusively through **in-process Go channels and C memory pointers**.
- It does **not** bind to a Unix Domain Socket (e.g. `/var/run/blip.sock`) or local TCP port.
- An external daemon cannot "connect" to a running Blip instance over DRPC.

---

## 5. Distinction: Directly Verified Facts vs. Hypotheses

| Statement | Classification | Empirical Evidence |
|---|---|---|
| `BlipKit` has no public headers or Swift modules | **Verified Fact** | Filesystem inspection (`find`) confirms absence of `Headers/` and `Modules/`. |
| `BlipKit` mandates App Group `AY8UB8KTUX.blip` | **Verified Fact** | `codesign -d --entitlements` and `lsof -p 5838` confirm open file handles to `AY8UB8KTUX.blip`. |
| External process cannot access `AY8UB8KTUX.blip` | **Verified Fact** | Non-entitled terminal command `ls /Users/nilambarbehera/Library/Group Containers/AY8UB8KTUX.blip` produced `Operation not permitted`. |
| DRPC is in-process only | **Verified Fact** | Symbol search reveals no IPC socket creation; network inspection (`lsof -i`) shows zero local IPC listeners. |
| A headless wrapper could work if signed with Blip's certs | **Hypothesis** | Theoretically true, but impossible in practice because private developer keys are unavailable. |

---

## Conclusion

An independent "headless BlipKit host" is **technically blocked** by macOS kernel sandbox enforcement and Blip's internal architecture. Re-hosting `BlipKit.framework` in a custom process is not an authorized or viable path.
