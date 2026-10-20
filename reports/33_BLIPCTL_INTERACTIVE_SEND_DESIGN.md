# 33 — Dispatch-disabled blipctl interactive-send candidate

Date: 2026-10-19, Asia/Kolkata. Research root: `/Users/nilambarbehera/Documents/Projects/REA/blip-research`.

**Implemented and locally verified:** a separate native CLI candidate recognizes `send --interactive` and preserves file-validation/error safeguards. Its real Services dispatch is compiled out. No new handoff or transfer was performed. The original working CLI, original Services probe, reports and prior evidence remain unchanged.

The historical route is now established at two evidence levels: the probe accepted the Services handoff, and the user confirms subsequent manual Android selection and delivery. The CLI itself still has no supported way to observe picker display, recipient selection, transfer start, completion or received-byte integrity. It must not derive those facts from `NSPerformService=true`.

## Source and architecture

New files live in `blipctl/phase2b/`:

| File | Role |
|---|---|
| `Sources/Inspection.swift` | Staged copy of the original read-only status/capability/file-validation functions; historical capability descriptions reference Reports 30–31. |
| `Sources/InteractiveSend.swift` | One-file interactive workflow, typed backend boundary, evidence states, disabled native Services adapter. |
| `Sources/CLI.swift` | Explicit command parsing; no recipient/force/dispatch flag or bare-send execution. |
| `Tests/InteractiveSendChecks.swift` | Isolated counting-stub tests; no Blip calls. |
| `build.sh` | Existing CLT compiler, mandatory `BLIPCTL_NO_DISPATCH`, no build overrides. |
| `verify.py` | CLI safety checks, contract checks, missing-safety-define failure and binary symbol inspection. |
| `bin/blipctl` | New verification-only executable; original `blipctl/bin/blipctl` is untouched. |

The native adapter is based on the previously validated probe: unique pasteboard, `NSURL` file serialization and one `NSPerformService("Blip…", board)`. There is no alternate Launch Services route or invocation of the historical probe. This adapter's live branch is **not compiled or executed in this phase**. Historical probe success is not a live test of the new adapter. A later approved source change and bounded trial are necessary before enabling it.

All usable builds currently require the `BLIPCTL_NO_DISPATCH` define. Without it, source compilation fails at an explicit `#error`. With it, the adapter throws `dispatchDisabled` before creating a pasteboard or calling a Service. There is no environment or command-line override. The build script refuses extra arguments. This is stronger than relying on verification callers to remember `--dry-run`.

## Exact safe commands and actual results

```sh
cd /Users/nilambarbehera/Documents/Projects/REA/blip-research
sh blipctl/phase2b/build.sh
python3 blipctl/phase2b/verify.py
blipctl/phase2b/bin/blipctl send --interactive --dry-run "$PWD/audit/fixtures/milestone 1 synthetic.txt"
blipctl/phase2b/bin/blipctl send --interactive "$PWD/audit/fixtures/milestone 1 synthetic.txt"
```

The final command above is safe **only because this candidate cannot dispatch**; it was exercised as a refusal test and returned **77**, not a send result. Build completed with existing Apple Swift 6.4 CLT, without Xcode or dependency acquisition. Compiler/cache/temp/output paths are inside research. Build logs: `audit/phase2b/build.log`, `build-final.log`; verification logs and complete command results are under `audit/phase2b/`.

Selected actual dry-run fields (exit 0):

```json
{
  "mode": "interactive",
  "phase": "file-validated",
  "fileValidated": true,
  "dryRun": true,
  "liveDispatchCompiledIn": false,
  "handoffAttempted": false,
  "serviceHandoffAccepted": null,
  "recipientPickerDisplayed": "unobserved",
  "recipientSelection": "unobserved",
  "recipientSelectionMode": "manual-in-official-Blip",
  "transferInitiation": "unverified",
  "transferCompleted": "unverified",
  "receivedPayloadIntegrity": "unverified"
}
```

The synthetic file's reported metadata was `bytes=63`, `contentType=public.plain-text`. The candidate reads metadata only, not payload bytes, when validating. The JSON above is a selected-field excerpt, not a transfer trace. Version 1 of the completed result schema adds `schemaVersion=1`.

Selected refusal result (exit 77):

```json
{
  "phase": "dispatch-blocked",
  "events": ["file-validated", "dispatch-blocked"],
  "fileValidated": true,
  "handoffAttempted": false,
  "serviceHandoffAccepted": null,
  "error": "Live dispatch is compiled out for Phase 2B. No runtime option or environment variable enables it."
}
```

## Honest state contract

| Evidence boundary | Permitted state | What must not be inferred |
|---|---|---|
| Readable regular local file and metadata | `file-validated` | App acceptance, recipient identity or any bytes sent. |
| Current native adapter | `dispatch-blocked`, exit 77 | No Service was attempted. |
| Future real Service returns true | `services-handoff-accepted` | Picker visibility, recipient selection, transfer start/completion. |
| Future real Service returns false | `services-handoff-rejected`, exit 69 | End-to-end transfer status; do not retry automatically. |
| File URL serialization fails before a call | `pasteboard-write-failed`, exit 74 | No Service invocation occurred. |
| Backend error with uncertain invocation outcome | `handoff-outcome-unknown`, exit 74 | Do not relaunch or treat uncertainty as a safe retry. |
| Test stub returns true/false | `test-only-service-outcome` with `evidenceOrigin=testStub` | Not real acceptance; `serviceHandoffAccepted=null`, `handoffAttempted=false`. |
| Picker/transfer state unavailable | `unobserved` / `unverified` | Never fill these with assumed success or progress. |

After a future approved real acknowledgement, a caller must require the schema version, native evidence origin, matching accepted phase and positive acknowledgement. A zero exit code alone is insufficient. Manual guidance may say “Choose the recipient in Blip”; it must not claim a picker was detected. The current candidate has no completion event producer or status-import endpoint. User testimony belongs in a separately attributed report, as in Report 31.

## Verification

The local suite passed **22 verification commands**, including six contract scenarios. Full result files preserve argument arrays, command strings, output and exit status. Earlier iteration results are preserved separately; the final result location is recorded in `audit/phase2b/verification-summary.json`.

Coverage includes ordinary and interactive dry-run, file URLs, symlinks, spaces/quotes/shell syntax in a literal filename, invalid/remote/directory inputs, missing files, bare-send/recipient/force/extra-file refusal, environment override refusal, build override refusal, accepted/rejected stub outcomes, unknown outcomes without retry, and dry-run/invalid-input zero backend calls.

Relevant actual output:

```text
interactive-compiled-out PASS 77
environment-cannot-enable-dispatch PASS 77
build-override-refused PASS 64
contract-checks PASS 0
build-without-safety-flag-fails PASS 1
undefined-symbol-inspection PASS 0
22 verification commands passed; no Services invocation or real transfer occurred.
```

The missing-define compile test reports `error: Phase 2B requires BLIPCTL_NO_DISPATCH`. `nm -u` inspection confirms the candidate has **no `NSPerformService` symbol reference**. Stub acceptance is not counted as runtime Blip coverage. No screenshot, AX call, shortcut, private RPC, live dispatch-enabled build or real sending command was used.

File validation preserves the original CLI's local regular-file/readability checks, remote-URL rejection and canonical symlink-target resolution. Files can change after metadata validation; a future actual dispatch must revalidate just before the call and still cannot guarantee which bytes Blip later reads. The proposed Droppy drop policy rejects symlinks initially and must solve its separate provider lifetime/file-grant boundary.

## Future approval gate

No further experiment is authorized by this implementation. The minimum eventual CLI validation is a separately approved one-file/one-call trial of a deliberately enabled candidate, with explicit manual selection in official Blip and independently attributed Android outcome. Any received size/hash comparison needs an existing authorized means; no new Android app or implicit return transfer is allowed. That live test is distinct from the smaller no-transmission Shortcuts inspection recommended in Report 32.

This code is ready for review of interactive staging semantics. It is not a production sending release or a Droppy integration. Report 34 identifies the unresolved sanctioned host-to-helper route and file-access gates.
