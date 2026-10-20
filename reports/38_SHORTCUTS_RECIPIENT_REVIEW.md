# 38 — Shortcuts & SiriKit Recipient Review

**Date:** 2026-10-19  
**Author:** Senior macOS Systems & Extension Architect  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Target:** Blip macOS 1.2.3 (`net.blip.macos`), `/Applications/Blip.app`  
**Primary Sources Examined:**
- `/Applications/Blip.app/Contents/Info.plist`
- `/Applications/Blip.app/Contents/Resources/Intents.intentdefinition`
- `/Applications/Blip.app/Contents/MacOS/Blip` (Mach-O binary strings and Objective-C runtime metadata)

---

## 1. Executive Summary

This independent investigation answers the specific question posed in Phase 2C: **Can a file and a specific paired Android device be supplied to Blip through an officially supported Shortcuts or SiriKit action without opening a recipient picker?**

### Definitive Verdict: NO.
Blip macOS contains **no officially supported Shortcuts or SiriKit action** capable of addressing a paired Android device or delivering a file without user interaction.

Specifically:
1. **Single Declared Intent:** Blip declares only one SiriKit intent: `INSendMessageIntent` ("Send Items") in `Intents.intentdefinition`.
2. **Contact Binding, Not Device Binding:** The `recipients` parameter is typed as `INPerson` (macOS system Contacts), not a Blip device ID, network endpoint, or paired mobile client.
3. **Mandatory Confirmation Flag:** The intent definition explicitly declares:
   ```plist
   INIntentUserConfirmationRequired = true
   ```
   macOS SiriKit and the Shortcuts app enforce interactive confirmation before the intent can execute.
4. **No Modern App Intents:** Blip contains **no implementations of the modern Swift `AppIntents` framework** (`AppIntent`, `AppShortcutsProvider`). It relies solely on legacy SiriKit (`application:handlerForIntent:`).
5. **No Scripting Support:** AppleScript dictionaries (`.sdef`) and `NSAppleScriptEnabled` are absent from `Info.plist`.

---

## 2. Primary Source Inspection

### 2.1 Info.plist Declarations
Inspection of `/Applications/Blip.app/Contents/Info.plist` yielded:
```python
Bundle ID: net.blip.macos
NSUserActivityTypes: ['INSendMessageIntent']
INIntentsSupported: None
OSAScriptingDefinition: None
NSAppleScriptEnabled: None
CFBundleURLSchemes: ['blip'] (Role: Viewer, Name: net.blip.macos.push)
```
- **Finding:** Blip registers `INSendMessageIntent` under `NSUserActivityTypes`. It declares no custom SiriKit intents, no Shortcuts actions, and no AppleScript support.

### 2.2 Intents.intentdefinition Deep Dive
The intent definition model located at `/Applications/Blip.app/Contents/Resources/Intents.intentdefinition` (Model Version 1.2, Tools Version 26.6) was parsed and analyzed:

```plist
<dict>
    <key>INIntentClassName</key>
    <string>INSendMessageIntent</string>
    <key>INIntentCategory</key>
    <string>system</string>
    <key>INIntentDomain</key>
    <string>Messaging</string>
    <key>INIntentTitle</key>
    <string>Send Items</string>
    <key>INIntentDescription</key>
    <string>A request to send items to the designated recipient.</string>
    <key>INIntentUserConfirmationRequired</key>
    <true/>
    <key>INIntentKeyParameter</key>
    <string>recipients</string>
    <key>INIntentParameters</key>
    <array>
        <dict>
            <key>INIntentParameterName</key>
            <string>recipients</string>
            <key>INIntentParameterType</key>
            <string>Person</string>
            <key>INIntentParameterMetadata</key>
            <dict>
                <key>INIntentParameterMetadataType</key>
                <string>Contact</string>
            </dict>
            <key>INIntentParameterSupportsMultipleValues</key>
            <true/>
            <key>INIntentParameterSupportsResolution</key>
            <true/>
        </dict>
        <dict>
            <key>INIntentParameterName</key>
            <string>content</string>
            <key>INIntentParameterType</key>
            <string>String</string>
        </dict>
        <dict>
            <key>INIntentParameterName</key>
            <string>attachments</string>
            <key>INIntentParameterType</key>
            <string>Object</string>
            <key>INIntentParameterObjectType</key>
            <string>MessageAttachment</string>
        </dict>
    </array>
</dict>
```

### Key Architectural Observations from Intent Metadata:
- **Parameter Type Mismatch:** The recipient parameter is an `INPerson` linked to macOS `CNContact`. Blip's paired Android devices exist exclusively as dynamic ephemeral session records in Blip's WebSocket signaling engine (`137.184.135.31:443`). They are not synced to the macOS Contacts database.
- **Mandatory User Confirmation:** `INIntentUserConfirmationRequired: true` instructs the system to present an interactive confirmation dialog even if invoked through a Shortcuts workflow.
- **Attachments Model:** `attachments` uses standard `INSendMessageAttachment` / `MessageAttachment`, designed for iMessage/Mail style media payloads, not peer-to-peer file transfer sessions.

### 2.3 Binary Analysis for Modern App Intents
Inspection of the Mach-O binary `/Applications/Blip.app/Contents/MacOS/Blip`:
- Searches for `AppIntent`, `AppShortcutsProvider`, `AppShortcut`, `_AppIntent` returned **0 symbols**.
- Searches for SiriKit intent handlers revealed:
  ```text
  application:handlerForIntent:
  @32@0:8@"NSApplication"16@"INIntent"24
  ```
- **Finding:** Blip implements only the legacy `NSApplicationDelegate.application(_:handlerFor:)` entry point. It has not adopted macOS 13+ App Intents.

---

## 3. Detailed Comparison: SiriKit vs. macOS Services Handoff

| Dimension | SiriKit `INSendMessageIntent` | macOS Services (`NSPerformService`) |
|---|---|---|
| **API Status** | Declared in `Intents.intentdefinition` | Declared in `Info.plist` (`NSServices`) |
| **Recipient Parameter** | `Person` (System Contacts) | None (Interactive UI Picker) |
| **Target Identity** | System contact email/phone | Manual user click on device card |
| **File Handoff Method** | `MessageAttachment` object | `NSPasteboard` containing file URLs |
| **User Confirmation** | Enforced by OS (`UserConfirmationRequired`) | Enforced by Blip UI (Picker Window) |
| **Automated Background Send** | Not supported for network devices | Not supported; requires user click |
| **Empirical Status** | Static metadata inspected; no device mapping | **Proven working** (Report 30 & 31: 63-byte file delivered to Android) |

---

## 4. Evidence Classification

| Statement | Classification | Source Evidence |
|---|---|---|
| Blip declares `INSendMessageIntent` | **VERIFIED Declaration** | `Info.plist`, `Intents.intentdefinition` |
| Recipients parameter requires an `INPerson` contact | **VERIFIED Declaration** | `Intents.intentdefinition:tag 20` |
| `INIntentUserConfirmationRequired` is set to `true` | **VERIFIED Declaration** | `Intents.intentdefinition:INIntents[0]` |
| Blip lacks modern Swift App Intents | **VERIFIED Binary Evidence** | Absence of `AppShortcutsProvider` in Mach-O |
| Blip lacks AppleScript scripting support | **VERIFIED Declaration** | Absence of `.sdef` and `NSAppleScriptEnabled` |
| Paired Android device can be selected via Shortcuts | **CONTRADICTED** | Intent parameters have no device ID or network peer field |
| Interactive picker can be bypassed via Shortcuts | **CONTRADICTED** | Confirmation flag and contact resolution mandate UI |

---

## 5. Architectural Verdict

Attempting to use macOS Shortcuts or SiriKit to deliver files to a paired Android device is an **unviable route**. The declared intent is designed for contact-based message sharing, requires user confirmation, and has no programmatic interface to Blip's paired device state.

The **only verified, compliant mechanism** to pass files from an external context into Blip is the official **macOS Services handoff** (`NSPerformService("Blip…", pasteboard)`).
