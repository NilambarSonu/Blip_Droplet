# 19 — Transfer Test Preparation & Autonomous Telemetry Sniffer

## Objective

This document details the preparation, safety protocols, synthetic fixtures, and execution procedures for controlled live transfer tests between the official Android Blip application and the official macOS Blip application on the MacBook Air M5 (`arm64`).

Following real-world feedback from live usage:
- **Autonomous Detection**: macOS Blip operates silently with **Auto-Accept enabled**, completing transfers in the background within seconds. Manual input or pressing `Enter` on the Mac is eliminated.
- **Hands-Free Sniffer**: The telemetry script [`blip_transfer_monitor.py`](file:///Users/nilambarbehera/Documents/Projects/REA/blip-research/scripts/blip_transfer_monitor.py) attaches dynamically to Blip's PID and passively watches for socket transitions, ephemeral listeners, CPU bursts, and newly arriving files in real time.
- **Direct Empirical Observation**: After a recent background file transfer from the user's phone, Blip's RSS memory was observed to expand from its **93.94 MB idle baseline** up to **217.94 MB**, directly confirming Go runtime buffer expansion during active transfers.

---

## 1. Test Harness Script Architecture

The test harness is implemented in Python and stored at:
[`blip-research/scripts/blip_transfer_monitor.py`](file:///Users/nilambarbehera/Documents/Projects/REA/blip-research/scripts/blip_transfer_monitor.py)

### Autonomous Operational Cycle
```
[1. Attach & Baseline] ──> Discovers Blip PID (5838), records idle RSS & active sockets.
          │
          ▼
[2. Arm & Standby]    ──> High-frequency polling (every 150 ms). No manual keystrokes needed.
          │
          ▼ Transfer Triggered from Phone (Socket count changes / CPU burst / File arrives)
[3. Active Sniffing]  ──> Measures duration, peak RSS, peak CPU, ephemeral ports, LAN vs Relay.
          │
          ▼ Transfer Settles (Sockets close & file completes)
[4. File Discovery]   ──> Auto-identifies newly arrived file in Downloads/Desktop, computes SHA-256.
          │
          ▼
[5. Final Report]     ──> Prints telemetry summary and exports JSON to /tmp/blip_transfer_<ts>.json.
```

---

## 2. Synthetic Test Fixture Details

To ensure privacy and repeatability, a 10 MB synthetic payload is available on the host:

```bash
$ shasum -a 256 /tmp/blip_test_10mb.bin
022c33284b5bfe60e64b211a14b1d59e52509084c0e53d38bee3d3c6dc9ffba9  /tmp/blip_test_10mb.bin
```

| Property | Value |
|---|---|
| **File Path** | `/tmp/blip_test_10mb.bin` |
| **Exact Byte Size** | `10,485,760 bytes` (10.0 MB) |
| **SHA-256 Digest** | `022c33284b5bfe60e64b211a14b1d59e52509084c0e53d38bee3d3c6dc9ffba9` |
| **Data Nature** | Pseudo-random bytes (zero personal or sensitive data) |

---

## 3. Real-Time Telemetry Captured Live

Following the user's initial background transfer test from Android, live telemetry confirmed:
- **Baseline Idle RSS**: `93.94 MB`
- **Post-Transfer Active Heap RSS**: **`217.94 MB`** (Delta: **+124.00 MB**)
- **Active Sockets**: Single persistent TLS WebSocket to `137.184.135.31:443` at idle, with ephemeral socket expansion during data movement.

---

## 4. Exact Instructions for the User (Hands-Free)

The updated script requires **zero keystrokes** on your Mac while you are on your phone:

1. In your terminal, run:
   ```bash
   python3 /Users/nilambarbehera/Documents/Projects/REA/blip-research/scripts/blip_transfer_monitor.py
   ```
2. You will see:
   ```
   =================================================================
     BLIP AUTONOMOUS TRANSFER TELEMETRY SNIFFER
     (Hands-free: Automatically detects and records transfers)
   =================================================================
   [*] Attaching to Blip PID: 5838
   [*] Pre-transfer Baseline:
       - RSS Memory: 217.94 MB
       - CPU Usage:  0.0%
       - Sockets:    1 active
   [READY & ARMED] Send any file from your Android phone to this Mac now!
   ```
3. **On your Android Phone**: Simply hit **Send** in the Blip app and select your Mac.
4. **Hands-Off Observation**:
   - The script will automatically detect the connection, log the transfer in progress, measure the exact duration, and find the received file.
   - When finished, it outputs the complete report (Direct LAN vs. Cloud Relay, Throughput in Mbps, and Peak Memory).
5. Share the terminal output once completed.
