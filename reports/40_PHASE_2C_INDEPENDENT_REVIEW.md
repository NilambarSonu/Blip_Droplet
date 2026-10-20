# 40 — Phase 2C Independent Review

**Date:** 2026-10-19  
**Reviewer:** Lead macOS Systems & Extension Architect  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Scope Reviewed:** Reports 24–39, particularly Reports 30, 31, 33, 34, 35, 36, 37, 38, and 39.

---

## 1. Executive Summary

This independent technical review audits the empirical findings, architectural deductions, and implementation decisions produced across Phases 2A, 2B, and 2C. 

The review confirms that:
1. **Interactive macOS Services Delivery is Verified:** The baseline trial documented in Report 30 (`NSPerformService("Blip…", pasteboard)`) and user-confirmed in Report 31 successfully delivered a 63-byte synthetic file to an official Android device following manual recipient selection.
2. **Picker-Free Automation is Formally Closed:** Independent audits of Blip's SiriKit intent (`INSendMessageIntent`), Mach-O binary metadata, AppleScript definitions, and URL schemes prove that automated background sending without user confirmation is impossible across all supported macOS IPC channels.
3. **DroppyKit Bridge Architecture is Clarified:** The DroppyKit SDK source audit (Report 36) established that while in-process AppKit execution is technically operational in local unsigned sideloaded droplets, public Store distribution strictly requires a declared host capability or an out-of-process companion helper driven via `DropletURLHandling`.
4. **File Drop Mechanics are Empirically Proven:** The 8-test synthetic harness (Report 37) established that raw `NSItemProvider` ephemeral representations are destroyed upon handler return, proving that atomic local staging is mandatory before handoff.
5. **Phase 2B CLI Baseline is Preserved:** The Phase 2B CLI candidate (`blipctl/phase2b`) remains isolated with dispatch safely disabled, having passed all 22 verification checks.

---

## 2. Audit of Key Claims and Evidence

| Claim / Boundary | Prior Status | Independent Review Verdict | Primary Source / Empirical Evidence |
|---|---|---|---|
| **Official Blip accepts Services handoff** | Claimed in Rep. 30 | **VERIFIED** | Report 30 process execution log; probe returned exit 0; picker appeared. |
| **Manual selection achieves Android delivery** | User account (Rep. 31) | **VERIFIED** | User-confirmed receipt on Android; persistent WebSocket active. |
| **Automated recipient selection via Shortcuts** | Speculative | **CONTRADICTED** | `Intents.intentdefinition`: `recipients` is `Person` (Contacts), `UserConfirmationRequired: true`. |
| **Automated recipient selection via AppleScript** | Hypothesized | **CONTRADICTED** | Blip `Info.plist`: `NSAppleScriptEnabled: None`, no `.sdef`. |
| **DroppyKit has a native subprocess API** | Unclear | **REFUTED** | SDK audit: `DropletHost` has no `Process` facade; `DropletPermission` has no process capability. |
| **Droplets execute in-process inside Droppy** | Inferred | **CONFIRMED** | `Droplet.swift:54`, `Submitting.md:16`. Bundle loaded dynamically on main actor. |
| **Temporary provider files survive callback** | Assumption | **REFUTED** | Report 37 Test 5: File exists during callback (`true`), deleted after return (`false`). |
| **Coordinated read prevents file tearing** | Recommended | **VERIFIED** | Report 37 Test 6: `NSFileCoordinator` read 67 bytes cleanly under concurrent load. |
| **Phase 2B CLI safety defines compile out dispatch** | Claimed in Rep. 33 | **VERIFIED** | `blipctl/phase2b` binary check: `NSPerformService` symbol absent; exits 77 on dispatch. |

---

## 3. Review of DroppyKit Host Boundaries (Report 36)

The architectural analysis in Report 36 accurately distinguishes between native runtime privileges and host policy contracts:

### 3.1 Runtime In-Process Capabilities
Droplets are compiled as dynamic libraries linked against the resilient `DroppyKit.framework` and loaded via `Bundle.load()` into `Droppy.app`. Because Droppy is a native AppKit application running without an App Sandbox, any symbol linked into the address space (such as `NSPerformService`) can be called directly by droplet Swift code.

### 3.2 Host Policy and Review Constraints
Droppy's developer documentation (`HostSupport.md:5-7`) emphasizes that `DropletHost` is the sole sanctioned facade. Calling un-declared AppKit APIs violates the contribution guidelines for the official Droplet Store. However, Droppy provides a dedicated "Local droplets" feature (`HostSupport.md:88`) specifically designed for personal extensions, which prompts the user once per session to authorize unsigned code.

### 3.3 Evaluation of the Vendor Extension Proposal
Report 36 proposes a minimal additive extension:
- `DropletPermission.servicesHandoff = "services-handoff"`
- `DropletWorkspaceService.performService(_ serviceName: String, fileURLs: [URL]) -> Bool`

This proposal is technically sound, adheres to DroppyKit ABI 1 additive evolution rules, and represents the cleanest long-term bridge for official Store distribution.

---

## 4. Review of File Drop Access & Staging (Report 37)

Report 37 correctly identified that passing a file to an external process requires solving three distinct platform challenges:

1. **The Ephemeral File Problem:** When a file is dragged from another application (e.g. Mail, Safari, or an archive utility), `NSItemProvider` provides a temporary file representation via `loadFileRepresentation`. The operating system deletes this temporary file immediately upon return of the completion closure. Holding the URL or passing it to an asynchronous task results in an immediate `ENOENT` error.
2. **Security-Scoped Lifetime:** For sandboxed or security-scoped URLs, access must be held while reading and released immediately after copying.
3. **Cross-Process Read Authority:** While Droppy may hold a security scope granted by the drag session, a child CLI process does not automatically inherit that sandbox extension. Copying the file to an authorized staging directory under `~/Library/Application Support/Droppy/Droplets/blip/staging/` resolves the authority boundary.

The 8 empirical tests in `audit/phase2c/file-drop-proof.json` substantiate these findings without ambiguity.

---

## 5. Review of Shortcuts & SiriKit Capabilities (Report 38)

The static analysis in Report 38 thoroughly inspects Blip's SiriKit declarations:
- Blip declares only `INSendMessageIntent`.
- The intent parameter `recipients` is restricted to system contacts (`INPerson`).
- The intent requires explicit user confirmation (`INIntentUserConfirmationRequired: true`).
- Blip implements no custom App Intents or `AppShortcutsProvider`.

These facts prove that SiriKit cannot be used to automate file delivery to a paired Android phone. The decision to abandon Shortcuts automation and focus exclusively on the verified Services handoff is fully justified.

---

## 6. Review Verdict on Phase 3A Readiness

Phase 2C successfully closed every technical ambiguity:
- The handoff route is proven (`NSPerformService("Blip…", pasteboard)`).
- The file staging engine is designed and tested.
- The Droppy package structure and manifest rules are verified.
- The safety gates (compiled-out dispatch) are established.

**Verdict: APPROVED to proceed with Phase 3A implementation.**
