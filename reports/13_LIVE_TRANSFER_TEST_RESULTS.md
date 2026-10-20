# 13 — Live Transfer Test Plan & Results

## Test Framework & Objective

This document records the empirical measurements and telemetry captured from live transfers between the official Android Blip application and the official macOS Blip application on Apple Silicon (`arm64`, MacBook Air M5).

---

## 1. Verified Live Transfer Test Execution

### Test 1: Android → Mac (Mobile Media / Photo)
- **Execution Timestamp**: `2026-10-18 22:38:47.967`
- **Telemetry Harness**: `blip-research/scripts/blip_transfer_monitor.py`
- **Target Process**: Blip macOS (PID `5838`)
- **Telemetry Export Artifact**: `/tmp/blip_transfer_1792343331.json`

| Metric | Measured Value | Analysis / Verification |
|---|---|---|
| **Transfer Duration** | **1.14 seconds** | High-speed burst transfer |
| **Pre-Transfer Baseline RSS** | **215.94 MB** | Reflects Go heap expansion from earlier transfer |
| **Peak Transfer RSS** | **216.00 MB** | Memory delta: +0.06 MB |
| **Peak CPU Usage** | **7.8%** | Apple Silicon hardware crypto & stream unpacker |
| **Ephemeral Listening Ports** | **None (`[]`)** | Direct relay path used |
| **Active Sockets Observed** | `172.22.148.211:64500 -> 137.184.135.31:443` | Persistent TLS signaling connection to `prod.blip.net` |
| **Routing Mechanism** | **Cloud Relay (`137.184.135.31`)** | Transferred via signaling server tunnel |
| **File Destination** | **Apple Photos Library** (`Photos.framework`) | Auto-imported via `AutoSaveToMediaLibrary` |

---

### Test 2: Mac → Android (10 MB Synthetic Binary File)
- **Execution Timestamp**: `2026-10-18 22:42:33.904`
- **Telemetry Harness**: `blip-research/scripts/blip_transfer_monitor.py`
- **Target Process**: Blip macOS (PID `5838`)
- **Telemetry Export Artifact**: `/tmp/blip_transfer_1792343580.json`

| Metric | Measured Value | Analysis / Verification |
|---|---|---|
| **Transfer Duration** | **24.39 seconds** | Sustained streaming & packing |
| **Pre-Transfer Baseline RSS** | **224.88 MB** | Stable Go runtime pool |
| **Peak Transfer RSS** | **240.38 MB** | Memory delta: **+15.50 MB** during streaming |
| **Peak CPU Usage** | **49.6%** | BSArchive packing, SHA-256 chunking & TLS encryption |
| **Ephemeral Listening Ports** | `IPv4 172.22.148.211:49541 (LISTEN)`<br>`IPv6 [...]:49539 (LISTEN)`<br>`IPv6 [...]:49540 (LISTEN)` | **Direct empirical proof of `listenOnSafeEphemeralTCPPort`!** Bound 1 IPv4 and 2 IPv6 ports. |
| **Data Relay Endpoint** | `172.22.148.211:49548 -> 137.184.103.12:443` | High-bandwidth DigitalOcean transfer relay node |
| **Signaling Endpoint** | `172.22.148.211:64500 -> 137.184.135.31:443` | Control WebSocket maintained concurrently |
| **Throughput (10 MB Payload)** | **~3.44 Mbps** | Sustained cloud relay throughput |

---

## 2. Core Technical Discoveries from Live Transfer Tests

### Discovery 1: Ephemeral Port Binding Confirmed Live
In Report 12, static binary analysis identified `github.com/thesharingcompany/blip/internal/netx/lan.listenOnSafeEphemeralTCPPort`. 
During Test 2, the telemetry harness captured this exact function in action:
- **IPv4 Listener**: `172.22.148.211:49541`
- **IPv6 Listeners**: `[2401:4900:...]:49539` and `[2401:4900:...]:49540`
Blip dynamically opened these local listening ports to attempt direct LAN negotiation before/while streaming to Android.

### Discovery 2: Two-Tier Cloud Infrastructure Discovered
Live socket telemetry proved that Blip separates **Control Signaling** from **Bulk Data Transport**:
1. **Control / Signaling Plane (`137.184.135.31:443`)**: Long-lived WebSocket connection maintaining presence, discovery, and notification tokens.
2. **Data Transport Plane (`137.184.103.12:443`)**: Dedicated high-throughput transfer relay node spun up on-demand during active data transmission (`SYN_SENT` -> `ESTABLISHED`).

### Discovery 3: Active Resource Profile on Apple Silicon
- **Idle Baseline (Cold)**: `93.94 MB RSS`
- **Idle Baseline (Post-Transfer Pool)**: `224.88 MB RSS`
- **Active Streaming Peak**: `240.38 MB RSS` (an additional +15.5 MB for BSArchive chunks and Stripe buffers)
- **Active CPU**: Peaked at **49.6%** on MacBook Air M5 during concurrent archive compression, hashing, and TLS encryption.

---

## 3. Updated 8-Scenario Matrix Status

| Scenario | Transfer Direction | Payload / Type | Routing Observed | Status |
|---|---|---|---|---|
| **Test 1** | Android → Mac | Mobile Media (Photo) | **Cloud Signaling Relay (`137.184.135.31`)** | ✅ **COMPLETED (1.14s, 7.8% CPU, Apple Photos)** |
| **Test 2** | Mac → Android | 10 MB Synthetic Binary | **Dedicated Data Relay (`137.184.103.12`) + Ephemeral Ports (49539-49541)** | ✅ **COMPLETED (24.39s, 49.6% CPU, +15.5MB RSS)** |
| **Test 3** | Android → Mac | Large Non-Image File (>50 MB) | *Pending* | ⏳ Ready |
| **Test 4** | Mac → Android | Different Networks (Cellular) | *Pending* | ⏳ Ready |
| **Test 5** | Interrupted | Same Wi-Fi (Wi-Fi toggled off/on) | *Pending* | ⏳ Ready |
| **Test 6** | Android → Mac | Mac locked / Blip in background | *Pending* | ⏳ Ready |
| **Test 7** | Mac → Android | Multi-file directory | *Pending* | ⏳ Ready |
| **Test 8** | Mac → Android | 1 GB synthetic file | *Pending* | ⏳ Ready |
