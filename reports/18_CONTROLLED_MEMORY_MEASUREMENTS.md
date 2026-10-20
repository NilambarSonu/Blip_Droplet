# 18 — Controlled Memory Measurements & Comparison

## Purpose & Measurement Methodology

This report establishes a rigorous empirical baseline for host process memory consumption, adhering to the following rules:
1. **Identical Metrics**: Every comparison reports both **Resident Set Size (RSS)** via `ps -o rss=` and **Physical Footprint** via `vmmap -summary`.
2. **Repeated Sampling**: Every measured state is evaluated across 5 repeated samples at 1-second intervals, reporting median, minimum, maximum, and range.
3. **No Component-Based Estimation**: Theoretical component memory math is banned. Unmeasured states are strictly designated as **Pending User Action**.
4. **No Premature Savings Claims**: Claims of "15 MB daemon footprint" or "88% RAM reduction" from previous reports are formally retracted until an equivalent working transfer engine is implemented and measured.

---

## 1. Controlled Measurement Baseline (Host State)

Measurements were captured from live processes on Apple Silicon (`arm64`, macOS 27.2, 32 GB unified memory):

### A. Droppy Baseline (WITHOUT Test Droplet Loaded)
- **Process**: `/Applications/Droppy.app/Contents/MacOS/Droppy` (PID `37218`)
- **State**: Idle in background / notch menu bar, zero custom droplets mapped.

| Metric | Sample 1 | Sample 2 | Sample 3 | Sample 4 | Sample 5 | **Median** | **Min** | **Max** | **Range** |
|---|---|---|---|---|---|---|---|---|---|
| **RSS Memory (MB)** | 500.20 | 500.20 | 500.22 | 500.19 | 500.25 | **500.20 MB** | 500.19 | 500.25 | **0.06 MB** |
| **Physical Footprint (MB)** | 272.10 | 272.10 | 272.10 | 272.10 | 272.10 | **272.10 MB** | 272.10 | 272.10 | **0.00 MB** |

> [!NOTE]
> `DroppyMediaHelper` (`pid 43223`) was also observed running alongside Droppy, consuming an additional **15.63 MB RSS** / **12.4 MB footprint**.

---

### B. Blip Baseline (Official Application at Idle)
- **Process**: `/Applications/Blip.app/Contents/MacOS/Blip` (PID `5838`)
- **State**: Idle in menu bar, single outbound WebSocket connected to `prod.blip.net:443`, zero active transfers.

| Metric | Sample 1 | Sample 2 | Sample 3 | Sample 4 | Sample 5 | **Median** | **Min** | **Max** | **Range** |
|---|---|---|---|---|---|---|---|---|---|
| **RSS Memory (MB)** | 93.94 | 93.94 | 93.94 | 93.94 | 93.94 | **93.94 MB** | 93.94 | 93.94 | **0.00 MB** |
| **Physical Footprint (MB)** | 76.60 | 76.60 | 76.60 | 76.60 | 76.60 | **76.60 MB** | 76.60 | 76.60 | **0.00 MB** |

*(Note: Earlier reports cited 77 MB, which corresponds precisely to the 76.60 MB Physical Footprint reported by macOS `top`/`vmmap`, whereas total Resident Set Size is 93.94 MB).*

---

## 2. Controlled Comparison Matrix

The four required operational states of Droppy are evaluated below:

| Operational State | Measurement Status | RSS Median (Range) | Physical Footprint Median (Range) | Verification Notes |
|---|---|---|---|---|
| **1. Droppy without test droplet** | ✅ **Directly Measured** | **500.20 MB** (0.06 MB) | **272.10 MB** (0.00 MB) | 5 controlled samples on PID 37218. |
| **2. Droppy with test droplet loaded** | ⏳ **Pending User Permission** | *Unmeasured* | *Unmeasured* | Droplet binary exists at `work/verified-artifact/BridgeFlow.droplet`, but is NOT mapped into Droppy runtime (`lsof` confirms no dylib loaded; `hostLoadVerified: false`). Loading into user's live Droppy installation requires explicit user action. |
| **3. Droppy with UI opened (Notch expanded)** | ⏳ **Pending User Action** | *Unmeasured* | *Unmeasured* | Requires physical UI expansion by the user on the MacBook Air notch. |
| **4. Droppy after UI is closed (Dismissed)** | ⏳ **Pending User Action** | *Unmeasured* | *Unmeasured* | Requires user dismissal to measure post-UI memory reclamation and purgeable dirty pages. |

---

## 3. Formal Retraction of Previous Unsupported Claims

In accordance with Phase 1C audit findings, the following claims from Reports 07, 09, 15, and 16 are **formally retracted**:

1. **Retraction of "10–20 MB Droplet Incremental RSS" Claim**:
   - In Report 15, this figure was derived from theoretical component math (Mach-O mapping + Swift metadata + SwiftUI graph).
   - Because `BridgeFlow.droplet` has never been loaded into Droppy, this was an **estimate**, not a verified measurement. It is struck from the factual record.
2. **Retraction of "15 MB Swift Daemon" Measurement**:
   - Report 16 referenced a "demonstrated ~15 MB daemon footprint".
   - Because no replacement daemon (`transferd`) has been compiled or run, this was an architectural projection, not a demonstrated measurement.
3. **Retraction of "95% / 88% Net System Memory Savings"**:
   - Comparing Blip (a complete, working file-transfer engine) against Droppy (which currently consumes **500 MB RSS** and has no active file-transfer engine loaded) does not demonstrate memory savings.
   - Genuine memory savings can only be asserted once an equivalent, working, bidirectional file-transfer companion is compiled and measured side-by-side.
