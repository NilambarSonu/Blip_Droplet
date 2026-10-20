# 11 — Evidence & Claims Audit

## Purpose & Scope of Audit

This audit conducts a rigorous, critical re-evaluation of all findings, conclusions, and architectural assertions made across Reports 01 through 10. Every substantive claim has been reviewed to strictly categorize whether it was:
1. **Directly Observed** (measured on live system with reproducible command output)
2. **Inferred from Static Evidence** (derived from symbols, strings, headers, or structure, but not run dynamically)
3. **Hypothetical** (engineering projection or design speculation)
4. **Not Tested** (scenario or behavior not executed during Phase 1)
5. **Contradicted or Unsupported** (statements that exceeded available evidence or presented assumptions as verified facts)

---

## Detailed Audit of Critical Claims

### 1. Claim: "Blip never uses local discovery / No local server for LAN discovery"
- **Found In**: `05_NETWORK_AND_TRANSFER_BEHAVIOR.md` (lines 20–22), `06_ANDROID_INTEROPERABILITY.md` (lines 58–61), `10_FEASIBILITY_VERDICT.md` (Question 3).
- **Classification**: **INFERRED & PARTIALLY CONTRADICTED / NOT TESTED**.
- **Audit Findings**:
  - *What was actually observed*: At idle, Blip had exactly one established TCP socket to `137.184.135.31:443` and zero listening TCP/UDP sockets (`lsof -i`).
  - *Where the claim went too far*: Concluding that Blip *never* uses local discovery was an overstatement.
  - *Counter-evidence in the binary*: The Go binary explicitly contains `internal/netx/broker/connect.go` with references to `LANToken` and `Methods` that include LAN direct connection.
  - *The unexamined gap*: Does Blip dynamically open a local UDP multicast or TCP listener *when a transfer is initiated* between two devices on the same Wi-Fi? This was never tested because no live transfer was initiated in Phase 1.
  - *Correct Statement*: At idle, Blip does not listen on any local port and maintains only an outbound cloud connection. Whether it opens ephemeral local listeners during an active transfer remains **untested**.

---

### 2. Claim: "macOS and Android implement identical protocols"
- **Found In**: `06_ANDROID_INTEROPERABILITY.md` (lines 23, 29–35).
- **Classification**: **INFERRED FROM STATIC EVIDENCE / NOT TESTED ON ANDROID**.
- **Audit Findings**:
  - *What was actually observed*: The macOS `BlipKit.framework` contains Go source paths referencing `go/frontend/xplat/android/saf/` (access, destination, file, jni_noop, permissions, stat, tree, write).
  - *Where the claim went too far*: Declaring the protocols "identical at the Go level" on Android without inspecting the Android APK or capturing live Android traffic.
  - *The unexamined gap*: While the source repository `github.com/thesharingcompany/blip` compiles a shared cross-platform core, the Android app might incorporate platform-specific discovery (e.g., Wi-Fi Direct, NSD/mDNS, Google Nearby Connections, or different API endpoints) not used or compiled as no-ops on macOS.
  - *Correct Statement*: The macOS binary embeds cross-platform Go code designed for both Darwin and Android SAF, indicating high architectural overlap in the core transfer engine, but actual protocol parity on Android is an inference that has not been directly validated against an Android APK.

---

### 3. Claim: "A background helper daemon is strictly necessary"
- **Found In**: `08_DROPPY_INTEGRATION_FEASIBILITY.md` (lines 75–85), `10_FEASIBILITY_VERDICT.md` (Question 7).
- **Classification**: **HYPOTHETICAL / OVERSIMPLIFIED**.
- **Audit Findings**:
  - *What was actually observed*: DroppyKit provides UI surface protocols (`ShelfWidgetProviding`, `HUDPresenting`, etc.) designed for extension-style integration within Droppy's process.
  - *Where the claim went too far*: Asserting that a separate LaunchAgent daemon is an absolute technical requirement.
  - *Counter-possibility*: Droppy is designed as an always-running macOS utility that lives in the notch/menu bar. Droplets have the `network-client` capability. If Droppy is kept running continuously by the user, a Droplet could maintain an outbound WebSocket connection in-process without an external daemon, provided Droppy's runtime does not aggressively suspend droplet background threads.
  - *Correct Statement*: A separate background helper daemon is an architectural *best practice* for ensuring transfers survive Droppy restarts or UI glitches, but it is **not strictly proven to be the only viable architecture** until Droppy's internal droplet execution lifecycle and threading policies are experimentally profiled.

---

### 4. Claim: "Droppy cannot maintain persistent network connections"
- **Found In**: `08_DROPPY_INTEGRATION_FEASIBILITY.md` (lines 76–81).
- **Classification**: **NOT TESTED / UNSUPPORTED**.
- **Audit Findings**:
  - *What was actually observed*: The Droplet capability catalog lists `network-client` (outbound networking).
  - *Where the claim went too far*: Stating categorically that a Droplet cannot maintain a persistent WebSocket connection.
  - *The unexamined gap*: No experimental droplet was compiled or executed inside Droppy to evaluate socket persistence, connection lifetime, or sleep/wake handling.
  - *Correct Statement*: Droppy allows outbound network access, but whether an in-droplet WebSocket connection remains open indefinitely during normal macOS desktop usage has not been tested.

---

### 5. Claim: "Direct Android interoperability is impossible / blocked"
- **Found In**: `06_ANDROID_INTEROPERABILITY.md` (lines 81–89), `10_FEASIBILITY_VERDICT.md` (Question 4).
- **Classification**: **PREMATURE CONCLUSION / CONFUSING DIFFICULTY WITH IMPOSSIBILITY**.
- **Audit Findings**:
  - *What was actually observed*: Blip uses custom Protobuf messages (`wire.pb.go`), a custom multiplexer (`stripe`), and server brokering via `prod.blip.net`.
  - *Where the claim went too far*: Declaring interoperability flatly "BLOCKED" and "impossible without cooperation from Blip Studio Inc."
  - *The unexamined gap*: The Go binary contains unstripped symbol names, protobuf schemas, and clear struct layouts. If legitimate client credentials can be provisioned through the official registration flow, and if the wire protocol can be decoded through dynamic capture or disassembly, an independent client could theoretically implement the same wire format.
  - *Correct Statement*: Interoperability with the official Android Blip app requires implementing Blip's private signaling and wire protocols. It is technically challenging and requires reverse engineering, but has not been proven mathematically or cryptographically impossible (e.g., no hardware security module or proprietary Apple-only attestation was found).

---

### 6. Claim: "A replacement will consume 15–20 MB RAM and be 88% smaller"
- **Found In**: `07_RESOURCE_AND_PERFORMANCE_BASELINE.md` (lines 80–87), `09_LIGHTWEIGHT_REPLACEMENT_ARCHITECTURES.md` (table), `10_FEASIBILITY_VERDICT.md` (Question 9).
- **Classification**: **HYPOTHETICAL SPECULATION (NOT TESTED / UNVERIFIED)**.
- **Audit Findings**:
  - *What was actually observed*: Blip currently consumes 77 MB idle RSS and 67.2 MB disk space.
  - *Where the claim went too far*: Presenting specific target numbers (15–20 MB RAM, 6–9 MB disk, 88% savings) as if they were established benchmarks rather than theoretical best-case estimates.
  - *The unexamined gap*: Any real-world Swift application that links SwiftUI, Combine, AppKit, and network buffers can easily consume 30–50 MB RSS. A binary with assets, localization, and protocols can exceed 15 MB.
  - *Correct Statement*: A native arm64 Swift implementation has the potential to eliminate the ~54 MB Go framework and Go runtime heap overhead, but exact memory and disk footprints cannot be stated as facts until a proof-of-concept binary is compiled and measured under macOS `top` / `footprint`.

---

## Comprehensive Report-by-Report Audit Table

| Report | Claim / Topic | Audit Status | Forensic Correction |
|---|---|---|---|
| **01** | Inventory & 67.2 MB footprint | ✅ **Directly Observed** | Accurately verified via `plutil`, `du`, `codesign`, `lipo`. |
| **02** | REA requires external disassembler | ✅ **Directly Observed** | Confirmed by official docs: REA orchestrates Ghidra/Hopper/IDA for native Mach-O. |
| **03** | Go runtime in `BlipKit.framework` | ✅ **Directly Observed** | Verified via `otool -L`, Mach-O load commands, and embedded Go symbols. |
| **04** | DRPC in-process bridge | 🔍 **Inferred from Symbols** | DRPC packages exist in Go symbols; live IPC message tracing was not captured. |
| **05** | Single outbound WebSocket at idle | ✅ **Directly Observed** | Measured via `lsof -i` (137.184.135.31:443). |
| **05** | "No local LAN discovery ever" | ⚠️ **Unsupported Extension** | Only true at idle. Active transfer discovery mechanisms remain untested. |
| **06** | Android shares Go codebase | 🔍 **Inferred from Symbols** | Cross-platform Go source paths present in binary; Android APK was not inspected. |
| **06** | "Direct Android interop is impossible" | ❌ **Premature / Unsupported** | It is proprietary and unmapped, not provably impossible. |
| **07** | 77 MB idle RAM, 0% CPU | ✅ **Directly Observed** | Measured accurately on running instance PID 5838. |
| **07** | Active transfer RAM (100–200 MB) | ⚠️ **Hypothetical Estimate** | Must be clearly labeled as an unmeasured theoretical estimate. |
| **08** | Droplet surfaces & capabilities | 🔍 **Inferred from SDK** | Accurately reflects SDK docs, but in-process network endurance was not tested. |
| **09** | Architecture trade-offs | ⚠️ **Design Proposals** | Architectural hypotheses, not verified runtime facts. |
| **10** | Final feasibility verdict | ⚠️ **Mixed** | Prematurely dismissed Blip Android compatibility in favor of LocalSend. |

---

## Action Plan for Phase 1B

Based on this audit, Phase 1B will:
1. **Never substitute LocalSend** or change the project goal: focus strictly on understanding and enabling compatibility with the official Android Blip app.
2. **Conduct deep native analysis** of the Swift-to-Go RPC interface, exported symbols, device registration, and transfer lifecycle in `BlipKit` (Report 12).
3. **Execute live transfer tests** (with user participation) to observe actual socket behavior, active RAM, bandwidth, and LAN vs. cloud routing (Report 13).
4. **Evaluate official Blip Android integration points** (APIs, share intents, URL schemes, automation) without defeating authentication (Report 14).
5. **Test Droppy compilation with native tools** without Xcode, building a verifiable mock droplet to measure real incremental memory (Report 15).
6. **Deliver an evidence-based Phase 2 Go/No-Go decision** strictly adhering to verified facts (Report 16).
