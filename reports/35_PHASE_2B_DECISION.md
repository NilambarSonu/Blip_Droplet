# 35 — Phase 2B decision

Date: 2026-10-19, Asia/Kolkata. Research root: `/Users/nilambarbehera/Documents/Projects/REA/blip-research`.

**Interactive official-Blip delivery is established through one Services invocation followed by user selection. Picker-free sending remains unverified. A functioning Droppy sending integration is not ready; its host invocation and file-access boundaries remain unresolved.**

## Direct answers

1. **Can we send directly to the Android phone without opening a recipient picker?** No verified method currently does this. The demonstrated flow opens a picker and the user chooses Android. That result does not prove another supported path is impossible.
2. **Can we do it using a supported Blip integration?** The registered Services integration demonstrably supports the interactive flow for the tested fixture, with delivery confirmed by the user. No examined public recipient-specific Services, Shortcuts, remembered-device, Launch Services, URL or automation contract has established picker-free sending. Treat that ability as UNTESTED, not available.
3. **What is the safest low-friction alternative?** Use a single explicit file handoff and let the user select the recipient in official Blip. Keep the handoff and delivery states separate. Optional Accessibility automation adds permission, identity and UI-drift risks; it remains an unimplemented, separately approved fallback, with exact-match and fail-closed requirements.
4. **What is the minimum next approved test?** First, a no-transmission inspection by the user of Blip's own available Shortcuts action and its file/recipient inputs, without running, creating or saving a shortcut. Establish whether it can identify this specific paired Android device and accept the synthetic file. If such an action exists, propose exactly one separately approved synthetic invocation. If not, retain manual selection; a CLI live-adapter test is a distinct later approval and should not be confused with new recipient automation.
5. **Are we ready to implement a real Droppy notch file-drop interface?** Ready to specify a staging-only UI, but not an operational sending droplet. The reviewed DroppyKit facade has no established supported CLI-launch/Services-dispatch route, and dropped-file lifetime/authority across processes is untested. Resolve those gates before connecting a real drop handler to sending. No production droplet was built, rendered, loaded or installed in this phase.

## Evidence and classification

| Finding | Classification | Evidence |
|---|---|---|
| Services accepted the original handoff | VERIFIED by probe | Report 30 and original `servicePerformed=true`, exit 0, one invocation. |
| Picker appearance and manual Android selection | USER-OBSERVED / USER-CONFIRMED | Report 31 records the user's subsequent observation without changing Report 30. |
| Delivery after manual choice, without a second invocation | USER-CONFIRMED | Report 31; approximate user timing, no invented telemetry. |
| Received payload matches source SHA-256 | UNVERIFIED | Only the source digest was measured. No received bytes were read. |
| Intent metadata has a recipient parameter | VERIFIED declaration | Report 32; `Person`/Contact, resolution and confirmation flags. Not a working paired-device API. |
| A supported one-step recipient interface is usable here | UNTESTED | Bounded primary-source/installed-metadata review found no verified contract. No candidate was invoked. |
| New interactive CLI safely refuses dispatch | VERIFIED local implementation | Report 33; separate candidate, mandatory no-dispatch compilation, safe refusal and negative tests. |
| A test-stub acknowledgement is a real Blip acceptance | CONTRADICTED | Stub outcomes explicitly remain test-only with no real acknowledgement/delivery claim. |
| Current Droppy widget accepts files or reflects transfers | CONTRADICTED | Preserved historical mock has no drop callback and contains fabricated demonstration state. Excluded from future production design. |
| New production design avoids fake recipient/progress/speed | VERIFIED as design content | Report 34 and `droppy-design/state-contract.json`; no running implementation claimed. |
| Host-to-helper invocation and cross-process file access are solved | UNTESTED | Report 34 identifies missing supported route and unverified provider/grant semantics. |

## Safe local changes delivered

The original `blipctl` source/binary, original live-test probe/fixture, prior evidence, isolated mock package and Reports 01–30 are preserved. New implementation lives in `blipctl/phase2b`, with its own executable. New report/evidence/design files supplement the historical record.

The candidate supports `send --interactive` parsing and local validation, with dispatch compiled out. A call without `--dry-run` still exits 77 after validation and cannot invoke the Service. The verification suite includes 22 command checks plus six backend-contract scenarios. It verifies literal shell-character filenames, bad inputs, disabled execution, ignored environment overrides, refused build overrides, unknown outcomes without retries, mandatory safety compilation and absence of the native Service symbol in the candidate binary. These are local safety results; they are not new Android delivery or Droppy runtime tests.

Reproduce only the safe candidate checks:

```sh
cd /Users/nilambarbehera/Documents/Projects/REA/blip-research
sh blipctl/phase2b/build.sh
python3 blipctl/phase2b/verify.py
blipctl/phase2b/bin/blipctl send --interactive --dry-run "$PWD/audit/fixtures/milestone 1 synthetic.txt"
```

Exact final build/verification exits, output paths and binary digest: `audit/phase2b/verification-summary.json`. Prior-file digest comparison: `audit/phase2b/preservation-check.json`. Source-bound recipient evidence is in `audit/phase2b/recipient-docs`; Droppy source/policy evidence is in `droppy-design/evidence`.

No live dispatch-enabled candidate was produced. No real transfer, original-probe invocation, private RPC access, UI automation/permission action, Blip/Droppy restart, setting/authentication/network change, Xcode acquisition, Android installation, cloud run, GitHub push or droplet loading occurred during Phase 2B. No excluded-project source or dependency was used.

## Gates after this phase

The interactive route can inform a future one-shot helper, but that does not authorize a new send. Any live test of the staged adapter requires a deliberately approved source/build change and one controlled invocation. Received-file integrity must be checked through an existing authorized means; no new Android app, permission change or implicit return transfer is included.

For Droppy, first establish a sanctioned host invocation contract and a file-lifetime/access contract. Then validate a staging-only model and UI, followed by separately approved build/load and one synthetic handoff. The cloud workflow still targets the preserved historical mock; building it would not validate this new design or solve the host API gap.

For optional Accessibility, first obtain separate permission/action approval and inspect only the official picker. If its exposed attributes cannot uniquely identify the intended user-approved device, retain manual selection. Never select by first match, approximate name, list order or coordinates, and never use private identifiers to compensate. No AX implementation or permission request was made.

**Decision:** keep automatic sending and the production Droppy bridge on hold. Deliver the truthful interactive design and disabled candidate for review, then stop. No automatic continuation or next live action is authorized.
