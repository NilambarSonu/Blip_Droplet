# 14 — Android Compatibility Decision

## Executive Verdict: Supported Interoperability Interface Does Not Exist

Following exhaustive investigation of official Blip Studio documentation, public repositories, web developer references, and local binary inspection:

> [!IMPORTANT]
> **Definitive Finding**: The official Android Blip application (`net.blip.android`) exposes **zero public, supported, or documented external developer APIs or network integration interfaces**.
> Under the non-negotiable constraints of this project—specifically:
> 1. Keep the existing official Android Blip app unmodified;
> 2. Do not bypass authentication or service protections;
> 3. Do not attempt to defeat server authentication or impersonate official clients without authorization;
>
> **Direct interoperability between an independently built macOS client and the official Android Blip app is currently INFEASIBLE as an officially supported integration.**

---

## Systematic Evaluation of Potential Integration Vectors

### 1. Official Documentation, Public SDK & API Availability
- **Public SDK**: **None**. Blip Studio Inc. does not publish an SDK for Android, iOS, macOS, or Windows.
- **Developer API**: **None**. There is no developer portal, REST API documentation, or OAuth application registry at `blip.net`.
- **Open Source Status**: **Closed Source**. The core repository (`github.com/thesharingcompany/blip`) is strictly private.

### 2. Android App Interfaces (Intents & Schemes)
- **Standard Share Target (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`)**:
  - The Android Blip app registers as an Android Share Sheet target. A user on Android can share photos or documents from Google Files or Gallery *into* Blip.
  - *Limitation*: This is an OS-level UI integration on Android for outbound file staging. It does **not** provide a listening programmatic server or network bridge that a third-party macOS app can connect to over Wi-Fi.
- **Deep Links & URL Schemes**:
  - Blip handles `blip://` URI schemes on both macOS and mobile platforms. These schemes trigger onboarding, pairing deep-links, or invitation acceptances via the Blip UI.
  - *Limitation*: The URI scheme passes control to Blip's internal UI; it does not expose an unauthenticated file-transfer pipe.

### 3. Local Network Transfer Interfaces
- **Bonjour / mDNS / NSD**: Neither the macOS application nor the Android application broadcasts an open local mDNS service (e.g., `_blip._tcp`).
- **Direct LAN Sockets**:
  - As discovered in Report 12, Blip's LAN direct connection is **server-brokered**.
  - Devices do not open permanent local listening servers. Ephemeral local listeners (`listenOnSafeEphemeralTCPPort`) are created only *after* both devices have coordinated via `prod.blip.net` WebSocket signaling and exchanged `LANToken` and 32-byte X.509 SHA-256 certificate fingerprints.
  - Without server signaling, the Android app will not open a local port or accept an unsolicited LAN connection.

### 4. macOS-Side Automation & Relay Opportunities
Since the official Android app cannot be directly addressed via an open network socket without Blip's cloud coordination, what legitimate macOS-side bridges exist?

| Approach | Architecture | Feasibility | Trade-offs |
|---|---|---|---|
| **A. Clean-Room Protocol Implementation** | Reverse-engineer the full Blip Protobuf wire format, Stripe multiplexer, and register as a device with `prod.blip.net`. | ⚠️ High Technical Risk | Violates constraint against unauthorized service impersonation; fragile to server API drift; risk of device ban. |
| **B. Headless macOS Blip Relay** | Keep the official Blip engine or a minimalist CLI instance running in the background; Droppy interacts with it via local IPC or folder watching. | ✅ Technically Viable | 100% compatible with Android Blip; preserves all official features; does not eliminate BlipKit runtime overhead. |
| **C. Official Integration Partnership** | Contact Blip Studio Inc. for private API/SDK access. | ❓ Unknown | External dependency, out of scope for autonomous engineering. |

---

## Technical Decision

1. **Unmodified Android Blip Constraint**: The user's requirement to preserve the official Android Blip app means that the transfer counterpart *must* speak the exact Blip protocol (Stripe multiplexer + BSArchive + `prod.blip.net` broker exchange).
2. **Unsupported Status**: Because Blip Studio provides no public API or open standard, any independent client attempting direct network communication with the Android app must either:
   - Emulate the proprietary client protocol end-to-end, or
   - Retain the official Blip engine as an in-process or local headless service.
3. **Formal Verdict**: An independent, clean-room macOS client cannot claim "supported" interoperability with the official Android Blip app. If clean-room emulation of Blip's private cloud API is prohibited, the only way to retain full Android Blip compatibility is via a headless or embedded wrapper of the official Blip engine.
