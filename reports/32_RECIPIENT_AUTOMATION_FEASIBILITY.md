# 32 — Recipient automation feasibility

Date: 2026-10-19 (Asia/Kolkata). Read-only Phase 2B research; prior reports 24–30 and their evidence remain unchanged.

**A supported interactive Services handoff is established for the tested synthetic file. A supported recipient-specific automatic-send interface remains unverified.** The latest user observation strengthens the interactive result: after the original service invocation, the user manually chose Android and reported delivery within a few seconds, with no second invocation. Received-file size/hash and precise transfer duration remain unverified. That sequence does not demonstrate automatic recipient selection.

No transfer, app activation, shortcut execution, UI inspection/automation, Accessibility/Automation permission check/request, settings change, private RPC call or credential access occurred in this workstream. Evidence is installed public bundle metadata, primary Apple/Blip documentation, prior captured test output, and the supplied user observation. No personal shortcuts or recipient registries were enumerated.

## Capability assessment

**VERIFIED** means observed within the named evidence boundary, including explicitly identified user reports. **INFERRED** means a reasoned candidate. **UNTESTED** means the necessary execution or contract is missing. **CONTRADICTED** means the particular claim conflicts with recorded behavior or the cited API contract.

| Candidate / claim | Classification | Actual evidence | Remaining limit |
|---|---|---|---|
| Services can stage the tested file for interactive Android sending | VERIFIED for one user-assisted trial | Report 30 captures `servicePerformed=true` and the picker; latest user report supplies manual selection and delivery without reinvocation | Received bytes/integrity, unattended behavior, other file types and repeat/restart behavior are unverified. |
| That trial automatically selected Android and sent without manual selection | CONTRADICTED by the reported sequence | User manually chose Android | It does not prove all automatic paths impossible. |
| Current Services declaration supplies a device-specific service variant | Not found; recipient-specific service contract UNTESTED | One `Blip…` service with `NSMessage=blip`, `NSPortName=Blip`, broad input types; no `NSUserData` or recipient-specific service names | Current declaration and one invocation do not rule out vendor-supported app-defined inputs elsewhere. |
| Stock `NSPerformService` has a recipient parameter | CONTRADICTED | Apple API parameters are service title and pasteboard | App-defined pasteboard data/Services user data are possible platform mechanisms, requiring an actual Blip contract. |
| `INSendMessageIntent` proves own-device targeting | UNTESTED | Metadata has `recipients: Person`, Contact metadata and app-specific resolution | User/account identity is not necessarily paired-device identity. Blip's actual mapping is unknown. |
| Intent metadata promises arbitrary-file background sending | UNTESTED; guarantee unsupported | `attachments: Object/MessageAttachment`; recipient-only combination has background execution false; confirmation-required true | Some content combinations permit background execution. None was executed; the public system attachment docs concern audio messages. |
| A callable Blip action exists in this Mac's Shortcuts catalog | UNTESTED | An intent definition and activity declarations are present | No action catalog or private shortcut list was queried. A donation/suggestion declaration is insufficient. |
| Blip remembers a target or offers a default recipient setting | UNTESTED | No published setting contract found in the bounded primary-source search; current settings not read | One prior selection does not establish persistent defaults or their routing semantics. |
| `NSWorkspace.open` directly chooses a Blip recipient | No standard recipient field; Blip-specific behavior UNTESTED | API selects the app/URLs/configuration; generic Apple event support exists | No accepted recipient event or public launch argument for Blip was found. Workspace branch remains unexecuted. |
| A documented `blip://` file-plus-recipient API is available | UNTESTED | `blip` scheme is declared; no public send grammar found within the examined official sources | Registration is not a send grammar. No URL was guessed, opened or tested. |
| Accessibility can reliably choose the exact paired Android | INFERRED fallback, operational feasibility UNTESTED | macOS provides AX APIs; Blip's actual picker tree/identity attributes were not inspected | Requires explicit permission/action approval and unambiguous exposed identity. It cannot supply a supported Blip automation contract or delivery acknowledgement. |

## Services: staging is real; recipient parameters are not established

The installed `/Applications/Blip.app/Contents/Info.plist` contains exactly one Services entry:

```json
{
  "NSMenuItem": {"default": "Blip…"},
  "NSMessage": "blip",
  "NSPortName": "Blip",
  "NSSendTypes": ["public.content", "public.url", "public.directory", "public.folder"]
}
```

The full entry, including its key equivalent/context and source hash, is in `audit/phase2b/recipient-docs/bundle-metadata.json`. The declared types support a file-handoff candidate; the actual trial is stronger evidence for this one synthetic file. It presented a picker and then sent after human selection according to the user.

[Apple's API](https://developer.apple.com/documentation/appkit/nsperformservice(_:_:)) accepts a title and pasteboard. A successful Boolean describes the service operation. It neither identifies the intended Android nor acknowledges received bytes. The [Services property contract](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html) permits provider-specific user data and add-on service behavior. Consequently, the two-argument function is not universal proof that no app could accept a recipient through app-defined data. This installed declaration and the official documentation reviewed supply no such Blip contract. No add-on service, custom payload, or undocumented parameter was created or tried.

## SiriKit and Shortcuts: inspect the actual action before proposing invocation

The installed resource `/Applications/Blip.app/Contents/Resources/Intents.intentdefinition` defines a customizable `SendMessage` / `INSendMessageIntent`, title `Send Items`, with `INIntentKeyParameter=recipients`. Relevant actual metadata:

```text
INIntentUserConfirmationRequired = true
recipients: Person; metadata type Contact; multiple values; supports resolution
content: String
attachments: Object; system object type MessageAttachment
content,recipients: SupportsBackgroundExecution = true
recipients: SupportsBackgroundExecution = false
```

There is no attachment-specific background combination in the inspected definition. Other combinations are preserved in the JSON. Those flags describe declared behavior, not tested runtime behavior. Confirmation-required true does not prove exactly which prompt a future action would show; nor do background flags guarantee the absence of a window.

[Apple defines recipients](https://developer.apple.com/documentation/intents/insendmessageintent/recipients) as users represented by `INPerson`, resolved by the receiving app. Its [customIdentifier](https://developer.apple.com/documentation/intents/inperson/customidentifier) and [personHandle](https://developer.apple.com/documentation/intents/inperson/personhandle) are app-specific identities. A device label is not an authenticated person handle or a documented paired-device ID. Equally, this type alone does not prove Blip could never map its own device into an app-specific identity. That mapping, its discovery mechanism and its acceptance by Blip are unverified. Do not invent identifiers or reuse private registration records.

The [system message-attachment documentation](https://developer.apple.com/documentation/intents/insendmessageattachment) concerns audio messages. An `attachments` field named in the bundle therefore does not establish a general regular-file Shortcuts input. Blip's action could implement additional behavior, but it must be observed or documented before being claimed.

Both main and share-extension Info.plists list `INSendMessageIntent` under `NSUserActivityTypes`. The inspected extension points are Share Services and QuickLook, with no Intents extension declaration in those inspected plists. This does not exclude app-hosted handling. Apple's [communication-notification guide](https://developer.apple.com/documentation/usernotifications/implementing-communication-notifications) uses the same activity declaration for donations and notification behavior. The key alone is not proof of a runnable send action. Apple's [share-suggestion example](https://developer.apple.com/documentation/foundation/supporting-suggestions-in-your-app-s-share-extension) is explicitly iOS; do not promote it into verified macOS behavior.

The smallest useful next step is a **no-transmission action inspection by the user**, without running, saving, editing or importing a shortcut: inspect only Blip's available actions in the installed Shortcuts app. Report whether an action exists, its displayed input types, whether its recipient field can distinguish the specific own Android device from contacts/accounts, and whether confirmation/open-app options are exposed. Do not enumerate unrelated personal shortcuts. This observation is not yet performed or permission to run an action.

If no relevant action appears, record that installation-specific result. If an action exists but accepts only people, text or audio and cannot express the intended device plus arbitrary file, it has not satisfied recipient automation. Only if the visible action resolves the required identity and accepts a synthetic file should a separately approved, single bounded invocation be proposed. Merely constructing/donating an intent is not a substitute for a supported external invocation path.

## Remembered/default recipients, Launch Services and URLs

No default-recipient or remembered-device contract was found on the reviewed official Blip pages/search results. Current preferences, private data and UI settings were not inspected. The original picker and subsequent manual choice establish a human-selected route, not automatic routing for the next handoff. Do not change defaults to test a hypothesis without approval. If the user later reports an existing visible setting, record its exact semantics without toggling it and validate its effect separately.

[NSWorkspace's open API](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withApplicationAt:configuration:completionHandler:)) selects a destination application and URLs. Configuration has launch attributes and a generic [Apple event](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/appleevent), but it does not standardize a Blip recipient. Recipient-specific Apple events or launch arguments would need an accepted vendor contract; none is established. Supplying invented Apple events/arguments is not a supported recipient integration. No AppleScript dictionary declaration was found in the selected main plist/Resources filename scope, which is not proof no Apple event handler exists.

The installed URL registration is Viewer role, name `net.blip.macos.push`, scheme `blip`. It gives no send grammar, attachment field or recipient identity. Official-domain searches for Shortcuts, URL syntax, default recipients and `NSPerformService` returned generic product pages rather than an API contract. Search boundaries, exact queries and bounded source excerpts are in `audit/phase2b/recipient-docs/README.md`. This is a scoped unknown, not a universal absence claim. No URL path/parameter was guessed or executed.

## Optional Accessibility fallback and failure conditions

Manual picker selection is the currently demonstrated path and needs no new automation permission. A future AX adapter would operate the official UI and can be considered only after separate approval; **no AX code or permission request was introduced here**. Apple's [trust check](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) distinguishes client trust and optional prompting. Neither was called. A direct AX helper would need Accessibility authorization for its actual execution identity. AppleScript through System Events can additionally involve Automation permissions; it is not a permission-free shortcut.

Before any future automated selection, all of these acceptance conditions would have to be proved in an approved inspection:

1. Resolve the genuine installed Blip process and verify the current picker belongs to that process. Bind to its current PID and expected window structure, never to whichever app happens to be frontmost. Restrict inspection to that picker's necessary subtree.
2. Resolve a user-approved target using explicit, unique identity exposed by the official UI. A display name alone, list index, recents order, first match or coordinate is insufficient. If the picker offers no stable or adequately distinguishing identity for the intended own device, retain manual selection. Do not extract private IDs to compensate.
3. Require exactly one matching, enabled recipient and verify the expected staged synthetic item and single-recipient context. Duplicate names, unknown account-versus-device identity, stale UI, unexpected dialogs or file mismatch must abort. Revalidate immediately before an action.
4. Treat choosing the recipient as a potentially transmitting action: the user-observed trial delivered after selection. Approval must encompass that single action and its possible immediate send. No generic Return key, global click, retry, fallback target or repeated service call is acceptable after an ambiguous result.
5. Abort on missing trust, unsupported attributes/actions, invalid elements, app exit/restart, timeout, changed picker or uncertain outcome. [AX attribute APIs](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue) can fail or lack attributes. Failures do not justify blind input or changing permissions.

Even a correctly selected AX element would not prove delivery/integrity, background/no-window behavior, or future UI compatibility. It creates an explicitly permission-gated UI dependency. No TCC database inspection/reset, global UI crawl, private protocol use or permission workaround belongs in that proposal.

## Evidence and decision gate

Run from the research root:

```sh
python3 audit/phase2b/recipient-docs/collect_metadata.py
cat audit/phase2b/recipient-docs/metadata-summary.txt
```

Actual execution: exit 0. Relevant stdout and source paths are above. The collector only parses installed public metadata and writes new research evidence. It performs no Services, Workspace, intent, Apple event, AX or network operation. The browser searches retrieved public primary documentation only.

Evidence files: `audit/phase2b/recipient-docs/bundle-metadata.json`, `metadata-summary.txt`, `apple-source-excerpts.json`, `official-blip-search.json`, and `README.md`. Report 30 remains the historical one-invocation record; the latest manual-delivery observation supplements it and is explicitly user-reported.

Keep recipient-specific automatic `send` unavailable. Prioritize user inspection of Blip's own Shortcuts action inputs without transmission; do not repeat the already demonstrated manual-delivery test merely to reconfirm staging. If that inspection or a vendor-published contract exposes a real device-plus-file interface, the next step can be a separate, explicitly approved synthetic validation. AX remains optional and unimplemented. No production implementation or deployment is justified by this read-only recipient study.
