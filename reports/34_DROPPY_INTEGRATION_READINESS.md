# 34 — Droppy integration readiness, Phase 2B design review

Date: 2026-10-19, Asia/Kolkata. Research root: `/Users/nilambarbehera/Documents/Projects/REA/blip-research`.

**Readiness: HOLD for a functioning Droppy integration. A truthful local staging design is defined; its supported host-to-helper invocation and file-access boundary remain unresolved.** The confirmed interactive Blip result does not establish either of those Droppy boundaries.

This review creates only new report/design/evidence files. Existing reports 24–30, droplet source, SDK source, original CLI/probe, workflow and recorded evidence are preserved. No build, rendering, droplet installation/loading, cloud action, transfer, UI automation, permission request, settings change or private-RPC access occurred.

## Evidence baseline and the new user observation

Read reports 24–30 and the actual isolated droplet, CLI handoff probe and fresh official SDK. SDK v1.20.1 remains commit `3d728a7981975714057650f80639c1e27d512fdb`. Report 30 records the original single `NSPerformService("Blip…", ...)` call, its `true` return, Blip activation and a user-observed picker. It correctly stopped before interaction at that time.

The user's latest Phase 2B account adds that they manually selected the Android recipient and successfully received the original 63-byte synthetic fixture. That is **VERIFIED as user-reported interactive delivery**, following the same handoff; it is not a second invocation or a new agent-run experiment. No received payload bytes or received SHA-256 were inspected here. The original source length/hash are established in report 30; received-byte equality remains **UNTESTED**. Earlier reports retain their historical observations and are not rewritten.

| Boundary | Current evidence | Status |
|---|---|---|
| Official Blip accepts the tested Services handoff sufficiently to show recipient UI | Report 30 process output and user observation | VERIFIED for that one controlled trial |
| User completes interactive Android delivery after manually choosing a recipient | Latest user account | VERIFIED as user-reported delivery; independent payload integrity unverified |
| Automatic recipient discovery/selection | No supported interface or trial | UNTESTED |
| No foregrounding | Report 30 samples show activation | CONTRADICTED for a guarantee about that trial |
| Droppy receives real file drops into this widget | Existing widget has no drop callback | UNTESTED; absent from historical mock |
| Droppy can invoke this CLI through a sanctioned host API | No such route found in reviewed v1.20.1 host facade | UNRESOLVED; do not enable |
| Dropped-file access survives provider lifetime and reaches helper/Blip | No cross-process file-access test | UNTESTED |
| Byte progress, rate, completion, incoming attribution | No verified source | UNTESTED; omit from product |

## What the historical mock contains

Source: `blip-research-droplet/blip-research/Sources/BlipResearch/BlipResearchDroplet.swift`.

- Lines 25–33 initialize `isConnected=true`, a Pixel device name, `isTransferring=true`, progress `0.65`, `48.5 Mbps`, a synthetic filename, auto-accept and a Downloads string.
- Lines 87 and 148–163 contain a drag-target flag and decorative drop region, with no `.onDrop`, `.dropDestination` or `NSItemProvider` handler anywhere under the source directory.
- Lines 113–140 display the mock percentage/rate. These are not telemetry.
- Lines 185–204 show local-only settings and a hardcoded companion. They neither read nor write Blip settings.
- Lines 35–46 retain the host and expose a mock toggle, without a transport or observation backend.

**VERIFIED:** the source is an inert demonstration, not a working file-transfer droplet. It is preserved unchanged for history. The proposed production design is a new artifact and must exclude that entire old package from future production inputs. It must not import its state model, build its library as the production integration or present its mock data as live. Existing report-28 cloud configuration still targets the historical mock; it must not be run or repurposed as a production build on the basis of this report.

## Host policy and invocation review

Reviewed official SDK source paths under `audit/vendor/droppykit/Sources/DroppyKit`:

| Source and line | Direct observation | Implication |
|---|---|---|
| `Core/DropletHost.swift:5` | Host is described as the only sanctioned way to reach outside the droplet | Use host-supported services; native privileges are not a substitute for supported integration |
| `Core/DropletHost.swift:77` | `workspace` is for URLs/files and pasteboard | Not a subprocess API |
| `Services/DropletServices.swift:544` | Workspace provides `open(URL)`, Finder reveal, plain-text pasteboard and Droppy settings navigation | No executable-plus-arguments/pipe-result interface; no Services dispatch method |
| `Services/DropletServices.swift:545` | `open(URL)` uses the user's default handler; schemes are constrained | Opening the CLI's file URL does not establish CLI execution, argument passing or file authority |
| `Services/DropletLauncherService.swift:148` | Launcher lists/runs Droppy's catalog items using item IDs | Its `perform(itemID:actionID:query:)` is not an arbitrary program launcher |
| `DropletBundle/DropletPermission.swift:11` | Capability enforcement is host gating plus review; the native in-process code is not sandboxed separately | Technical ability to call Foundation/AppKit does not establish policy support |
| `DropletBundle/DropletPermission.swift:69` | Known capabilities include shelf, HUD, network and Apple Events; no named process-execution/file-grant capability | Do not invent a capability or assume `network-client`/`apple-events` authorizes CLI execution |
| `DesignSystem/DroppyAnimation.swift:36` | The SDK itself imports AppKit | An AppKit import alone is not proof of a ban; assess the actual effect/API used |

The pinned SDK contains no documented `Process`/`NSTask` spawning, `executableURL`, or `NSPerformService` entry in the reviewed `Core`/`Services` scope. That is a bounded source observation, not proof that every future host version or separately approved vendor extension must lack one.

**INFERRED design decision:** do not directly call `Process`, `NSWorkspace`, `NSPerformService`, private host objects or unrestricted filesystem APIs from a production droplet to work around a missing facade. The SDK's own native privileges and passing compiler/validator results would not prove that such a design is sanctioned. No direct invocation code was added or executed.

The published [Droppy developer terms](https://getdroppy.app/droplet-developer-terms) require declared permissions and disclosure of sent data. The [official contribution policy](https://gitlab.com/droppyformac1/droplets/-/raw/main/CONTRIBUTING.md) limits packages/executable targets and requires review. These documents do not establish a general subprocess execution contract. Store submission is not part of this task, and no legal acceptance, publication or contact was performed.

The smallest candidate engine remains a separately invoked, one-shot native CLI using the demonstrated Services mechanism, with clear user confirmation and no recipient automation. Its dispatch-disabled Phase 2B candidate is under `blipctl/phase2b`, independently of the preserved original CLI. **Connecting that candidate to Droppy remains unknown.** Before implementation, identify a documented host invocation API with argument/result/file-access semantics, or obtain an explicit vendor-supported extension contract. No message was sent to the vendor. A new custom URL scheme/helper app, terminal script, polling directory, background daemon or unauthenticated local socket is not an established alternative in this review.

## Proposed user-visible behavior

These are **DESIGN choices, not implemented or tested behavior**. `droppy-design/state-contract.json` contains the corresponding data-only contract with `dispatch_enabled=false`.

1. An explicit drop stages **one** local regular file. Dropping does not call Blip, spawn a helper, change the clipboard or initiate transmission. Start with one file because only a single-file Services trial exists; directories, bundles, promises and batch semantics require their own design/test.
2. Show its name and size only after local access/metadata validation. Show `File staged locally`, not `Ready` or `Connected`. If validation fails, explain the concrete local failure. The model has no recipient-device field.
3. Keep `Continue in Blip` disabled while the host route or file access is unresolved. Explain `Droppy handoff is not available`. A read-only CLI candidate or installed Blip process does not remove this gate.
4. In a future approved, supported implementation, a separate confirmation would name the current file, explain that Blip may come forward and may send using existing settings, and require the user to continue. The scope is one file/one attempt. No automatic confirmation, remembered blanket consent, default send-on-drop or activation-time dispatch.
5. Only after all gates pass, consume one attempt reservation before one helper launch. Use an exact trusted executable and argument array; never construct shell commands. Revalidate the file immediately before dispatch. Disable duplicate actions while that attempt is unresolved.
6. Only the complete versioned native-result contract below changes the label to `Handoff acknowledged. Finish in Blip; delivery is unknown.` The candidate's acknowledgement field is `serviceHandoffAccepted`, not the historical probe's `servicePerformed`. The CLI return is not a picker-visibility, transfer-start or receipt event. Give manual recipient-selection guidance; do not claim the picker was observed on every invocation.
7. On malformed/missing output, timeout or process loss after launch, report `Handoff outcome unknown; do not repeat automatically`. Do not relaunch, fall back to Launch Services or infer failure safe to retry. A matching versioned native rejection (`phase=services-handoff-rejected`, `serviceHandoffAccepted=false`, `handoffAttempted=true`, `evidenceOrigin=nativeService`) is a handoff failure, not a transfer-status update.
8. Clearing the staged item clears local state only. After dispatch, it does not dismiss Blip's picker or cancel an official-app transfer. Releasing staging must not destroy a granted resource or disposable copy still needed by Blip.

The future bridge must require **all** acknowledgement fields from the same validated helper invocation: process exit 0; integer `schemaVersion=1`; `mode=interactive`; `phase=services-handoff-accepted`; Boolean `serviceHandoffAccepted=true`; Boolean `handoffAttempted=true`; `evidenceOrigin=nativeService`; Boolean `dryRun=false`; and Boolean `liveDispatchCompiledIn=true`. Missing/unknown schema, contradictory fields or legacy probe text fail this contract. This is the required versioned consumer contract; absence of `schemaVersion` in a candidate revision is a gate failure, never an excuse to infer acceptance. The present compiled-out candidate cannot produce this real acknowledgement.

`evidenceOrigin=testStub`, `phase=test-only-service-outcome` and any `simulatedServiceReturn` represent verification data only, including when their exit code is 0. They must never become a real handoff acknowledgement, picker observation or transfer success. The consumer must also reject local-validation/dry-run/dispatch-blocked results as native evidence, bind the result to its own one-shot request and validated helper identity, and ignore URL callbacks or arbitrary JSON as completion evidence. Stub tests can exercise labels and validation rules only.

The candidate source checked at `blipctl/phase2b/Sources/CLI.swift:32` calls `application()` before preparing a send; `Sources/Inspection.swift:27` validates the fixed `/Applications/Blip.app` path and `net.blip.macos` bundle identifier. That is an installation/identifier check, not cryptographic provider verification or proof that a globally named Services entry is bound to that app. `NativeServiceHandoff` uses the service name `Blip…`; its dispatch is compiled out in this candidate. Any future sanctioned host route must validate the intended official service/provider and file-access context before a separately approved trial. Per-host support and provider binding remain unverified.

Allowed state labels: `empty`, `validating`, `staged`, `bridge_unavailable`, `confirmation`, `handoff_requested`, `handoff_acknowledged`, `handoff_failed`, `outcome_unknown`, `cancelled_locally`. A transient spinner may represent a real pending local validation/helper task, with that task's label. There is no transfer-progress bar, percentage, bytes-per-second value, ETA, paired-device list or completed badge. User-reported delivery is recorded separately as a user observation; it does not become a programmatic completion event.

No Blip settings controls are proposed. Destination, auto-accept, sign-in, network and Android pairing remain in official Blip. No incoming HUD is proposed until a Blip-attributable arrival source is verified; Downloads changes and CPU/socket activity do not supply one.

## Dropped files: lifetime, authorization and process boundaries

**VERIFIED platform contract from the installed Foundation headers; actual Droppy behavior remains UNTESTED.**

- `NSItemProvider.h:199` states that `loadFileRepresentation` creates a temporary copy deleted when its completion handler returns; an authorized app must copy/move it within the handler if it needs a lasting copy. Holding a URL string until a later confirmation is insufficient.
- `NSItemProvider.h:206` describes `loadInPlaceFileRepresentation`; the returned URL requires `NSFileCoordinator` access, and a local copy can be deleted after coordinated access ends. Provider progress is progress in loading a drag representation, not Blip network progress.
- `NSURL.h:909` describes security-scoped resource access and balancing successful start/stop calls. Granting access in Droppy's process does not establish authority for a different helper just because it receives the same pathname.
- `NSURL.h:835` says an app-scoped security bookmark cannot grant another sandboxed app access. The same header at lines 745–769 describes implicit scope options; therefore it is also incorrect to claim all bookmark transfer is impossible. A specific supported bookmark/file-descriptor/OS-mediated grant contract is needed. None has been designed into the current CLI or verified from Droppy to it.

The installed SwiftUI interface declares `.onDrop(of:isTargeted:perform:)` at `SwiftUI.swiftinterface:2701` and generic `.dropDestination` at line 2713. A widget can theoretically return a SwiftUI view with a drop modifier because `ShelfWidgetProviding.makeWidgetView` returns `AnyView` (`ShelfWidgetProviding.swift:445`). This is **INFERRED UI feasibility**; it does not prove that the real Droppy shelf forwards drops correctly, keeps the source grant alive, or sanctions the subsequent external invocation. No modifier was added or rendered.

A future staging implementation must preserve valid provider access through asynchronous loading, metadata validation and the user's decision, and prove a supported authority handoff to the one-shot helper and then Blip. Do not serialize raw sandbox extension tokens, credentials, bookmark data or payload bytes into logs or URL query strings. No private grant API is proposed.

The initial design rejects symlinks rather than silently following them, checks for a readable regular file and rejects nonlocal URLs, special files and directories. Validate resource identity/size again before a confirmed handoff; when identity changes or scope expires, refuse and require an explicit restage. Path validation alone cannot eliminate all file-replacement races or establish that Blip later reads the same bytes; keep that limitation explicit.

The default design performs no silent payload copies and stores no persistent paths/bookmarks. A durable staging copy may be an alternative only after its host support, disclosure, bounded storage, cancellation/cleanup and access by helper/Blip have been specified and tested. Do not delete a copy merely when the Services call returns: no verified completion/read-finished event exists. Until a supported lifetime/grant contract is available, the truthful implementation is to keep handoff disabled.

The earlier pasteboard round-trip probe's `sandbox_extension_consume failed` diagnostic remains relevant: local URL serialization was not proof of a reusable cross-process grant. The successful user-assisted fixture delivery establishes that one concrete official flow worked; it does not establish equivalent access for promised files, iCloud providers, network volumes, Downloads, the host's container, or arbitrary sandboxed helpers.

## Minimal resources and lifecycle

A future widget keeps only its current staged item and local attempt state. No launch agent, persistent helper, timer, polling watcher, CPU/socket sampler or notification-database observer is needed. Query capabilities on explicit refresh/operation boundaries rather than continuously. A running process is not an authenticated or paired state.

Use host logging for bounded error/outcome metadata, without file contents or full personal paths; use a local request ID for correlation, not a recipient identity. If a supported helper route exists, bound captured stdout/stderr and require a versioned result contract. Do not infer success from an exit code alone.

Only declare capabilities actually used. A pure local widget should not request Apple Events, Accessibility, network-client/server, microphone, Photos, Full Disk Access or download/install authority. Optional later HUD and shelf-hold behavior would require `hud` and/or `shelf-write` through the host and must handle refusal. Neither is necessary for the first staging design. The absence of a process capability is a host-support gap, not a reason to declare an unrelated capability.

On `deactivate`, cancel local provider-loading tasks, discard transient staging, balance any successful scope starts, release any shelf hold and remove observers. Do not automatically reopen or resend on reactivation. If a helper was already launched, loss of local task state must not imply transfer cancellation or authorize a retry. The SDK lifecycle guidance at `Documentation.docc/DropletSetup.md:23` requires inertness after deactivation; no new component currently runs.

## Minimum next gates and tests — not executed

| Gate | Smallest useful future evidence | Current disposition |
|---|---|---|
| Supported host invocation | Documented supported executable/arguments/results interface or explicit vendor-approved contract | Missing; blocks operational droplet |
| Local model correctness | Pure tests of stage/confirm/cancel/deactivation/one-attempt transitions and malformed helper outcomes, with dispatch stubbed | Design only; does not need a real transfer |
| File lifetime/access | Approved host/harness test using only a synthetic regular file; verify helper read authority without invoking Blip; explicitly exercise expiry/refusal | No host test authorized/performed |
| UI truthfulness | Future approved build/render of a new staging-only package; inspect both solo/paired views and disabled bridge message | No build/render performed |
| One-shot helper handoff | Separate explicit approval for exactly one Services call through the new candidate, controlled manual picker interaction and official Android outcome | Disabled; original trial is not authorization to repeat |
| End-to-end Droppy handoff | Separate approval to load/test the new droplet and one synthetic file; verify same file/one invocation/no retry | Blocked pending previous gates |
| Received integrity | Compare received bytes/size/SHA-256 with the known synthetic source using an already authorized means | Missing; do not add Android tools or send a return transfer |
| Background/restart | Separately approved lifecycle trials while existing transfers are idle | Unverified; not required to label a manual staging flow accurately |

No approval is requested by this review and none of these future actions was carried out. Cloud packaging from report 28 remains a separate, unexecuted build-only plan for the historical mock. A cloud build cannot resolve a missing host API or prove Android interoperability.

## Exact read-only commands and relevant outputs

From the research root, the bounded review used:

```sh
git -C audit/vendor/droppykit rev-parse HEAD
rg -n 'onDrop|dropDestination|NSItemProvider|NSPerformService|Process\(|executableURL|loadFileRepresentation|startAccessingSecurityScopedResource' blip-research-droplet/blip-research/Sources
rg -n 'deviceName|transferProgress|activeTransferSpeed|autoAcceptEnabled|saveDestination' blip-research-droplet/blip-research/Sources/BlipResearch/BlipResearchDroplet.swift
sed -n '541,620p' audit/vendor/droppykit/Sources/DroppyKit/Services/DropletServices.swift
sed -n '148,186p' audit/vendor/droppykit/Sources/DroppyKit/Services/DropletLauncherService.swift
rg -n 'Process\(|NSTask|NSPerformService|executableURL|func.*(spawn|launchProcess|runProcess)' audit/vendor/droppykit/Sources/DroppyKit/Services audit/vendor/droppykit/Sources/DroppyKit/Core
```

Actual relevant output:

```text
SDK revision: 3d728a7981975714057650f80639c1e27d512fdb
Drop/invocation symbols in historical droplet source: no matches (rg exit 1)
27: @Published public var deviceName: String = "Pixel 8 Pro (Android Blip)"
29: @Published public var transferProgress: Double = 0.65
31: @Published public var activeTransferSpeed: String = "48.5 Mbps"
Workspace API: func open(_ url: URL) -> Bool
Arbitrary process/Services launch symbols in SDK Core/Services: no matches (rg exit 1)
```

Additional exact `sed` reads examined `Core/DropletHost.swift`, `DropletBundle/DropletPermission.swift`, and installed Foundation `NSItemProvider.h`/`NSURL.h` ranges cited above. All 15 command argument vectors, exit statuses and complete selected outputs are stored in `droppy-design/evidence/source-review.json`; input path/byte-count/SHA-256 snapshots are in `droppy-design/evidence/preserved-inputs.json`. These commands inspect source/metadata only; no probe, CLI, harness, service or app was invoked. The future state contract is JSON-parseable design data, not tested runtime behavior.
