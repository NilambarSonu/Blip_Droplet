# 30 — One controlled macOS Services handoff

Date: 2026-10-19, Asia/Kolkata. Research root: `/Users/nilambarbehera/Documents/Projects/REA/blip-research`.

**Result: the single Services invocation returned `true`, Blip briefly became active, and the user observed a recipient picker. Stopped without interaction. Automatic Android selection, transfer initiation and delivery are unverified.** This demonstrates an interactive handoff, not automatic sending or completed delivery.

## Authorization and execution boundary

The user explicitly authorized exactly one invocation of the existing `audit/bin/HandoffProbe`, using only `service` and the existing 63-byte synthetic fixture. The approval allowed a real synthetic transfer if Blip initiated one, but required stopping before manual interaction. No retry, alternative mechanism or follow-up transfer was authorized.

Exactly **one** probe process was launched. No recipient selection, click, keystroke, permission grant, settings/authentication/network change, application restart, private-socket connection, droplet installation, remote write or unrelated-project access occurred. Production `blipctl send` remains disabled. Neither the probe source nor executable was modified or rebuilt for this experiment.

## Preflight

Existing source: `/Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/probes/HandoffProbe.swift`.

Existing executable: `/Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/bin/HandoffProbe`.

Existing fixture: `/Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/fixtures/milestone 1 synthetic.txt`.

The fixture was checked to be a regular, nonsymlink file containing exactly:

```text
BLIP RESEARCH Milestone 1 synthetic fixture. No personal data.
```

There is one trailing LF; total size is **63 bytes**. Actual source SHA-256:

```text
c0c19d30a8a610246415acfb980138cfe2d52714d7a670adde93735646154afd
```

Probe executable SHA-256:

```text
ccc6adb1c8de2ffdb671564c21b590254b47785ecabfa3c2fef325343cff3770
```

Probe source SHA-256:

```text
c5ad90fd4c2b7c6aa7f645a437353d88495f981befdb02853c5f4e9442937fda
```

Exact preflight commands included:

```sh
cd /Users/nilambarbehera/Documents/Projects/REA/blip-research
shasum -a 256 audit/bin/HandoffProbe 'audit/fixtures/milestone 1 synthetic.txt'
wc -c 'audit/fixtures/milestone 1 synthetic.txt'
blipctl/bin/blipctl status
```

The status command is a read-only OS/bundle query; it invokes no transfer mechanism. It reported the already running official Blip 1.2.3, build `20260927200815`, PID **5838**, `active=false`, `hidden=false`. Authentication and paired recipients were not inspected. Preflight was recorded at `2026-10-19T06:42:04.371419+05:30` in `audit/evidence/services-handoff-live/preflight.json`.

## Exact single invocation and complete output

The following exact argument vector was launched through Python `subprocess.Popen`, with the research root as working directory and stdout/stderr captured separately. A file created with exclusive-create mode recorded the one-attempt reservation before launch; the wrapper contains no retry or fallback.

```sh
/Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/bin/HandoffProbe --acknowledge-may-transmit service --file '/Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/fixtures/milestone 1 synthetic.txt'
```

Complete stdout:

```text
servicePerformed=true; transferInitiation=unverified; delivery=unverified
```

Complete stderr: **empty**.

Exit status: **0**. No timeout or retry occurred. Probe PID was **54013**. The reservation was recorded at `2026-10-19T06:42:23.377376+05:30`; the invocation and bounded post-return status sampling finished at `2026-10-19T06:42:28.353165+05:30`. That approximately five-second observation interval is **not a transfer duration**.

The existing source writes the fixture URL to a unique pasteboard and calls `NSPerformService("Blip…", board)` once. It prints `servicePerformed` from that Boolean return. The `workspace` branch was not executed. No general clipboard contents were used.

Raw output and invocation record:

- `audit/evidence/services-handoff-live/invocation-reserved.json`
- `audit/evidence/services-handoff-live/probe.stdout.log`
- `audit/evidence/services-handoff-live/probe.stderr.log`
- `audit/evidence/services-handoff-live/result.json`

## Observations

Read-only `blipctl status` samples captured these OS process properties. Times are seconds after the wrapper began this single invocation, rounded to three decimals:

| Elapsed seconds | Blip PID | Active | Hidden |
|---:|---:|---|---|
| 0.021 | 5838 | false | false |
| 0.246 | 5838 | false | false |
| 0.476 | 5838 | false | false |
| 0.707 | 5838 | false | false |
| 0.938 | 5838 | false | false |
| 1.158 | 5838 | false | false |
| 1.380 | 5838 | true | false |
| 1.913 | 5838 | false | false |
| 2.944 | 5838 | false | false |
| 4.975 | 5838 | false | false |

**VERIFIED:** the existing Blip process became active at one observed sample, then inactive at later samples. It was already running, and the PID stayed the same. Sampling cannot establish the exact transition times or exclude shorter changes between samples. `hidden=false` does not itself establish whether a window or recipient picker was visible.

The user was asked to report visible effects without interacting. Their exact response was:

> Recipient picker appeared; no interaction

This is **user-observed evidence**, preserved in `audit/evidence/services-handoff-live/user-observation.json`. No screenshot, Accessibility inspection or UI automation was performed. The agent made no manual UI action.

| Requested observation | Actual result | Classification / limitation |
|---|---|---|
| Service return value | `true`; probe exit 0; empty stderr | VERIFIED from the captured process output. This is not a delivery receipt. |
| Blip opens or activates | Existing PID 5838 briefly reports `active=true` | VERIFIED OS activation change; no new launch or restart was initiated by the agent. |
| Recipient picker appears | User reports that it appeared | VERIFIED as user-observed; picker contents were not read by the agent. |
| Already paired Android automatically selected | Not confirmed | UNTESTED. A picker appeared; no selected device identity or automatic-selection behavior was established. |
| Transfer starts | Not confirmed | UNTESTED. No app-level transfer-start event, Android indication or byte-progress source was observed. |
| Transfer completes | Not confirmed | UNTESTED. Successful Services invocation is insufficient evidence. |
| Received file size and SHA-256 match | No received payload available for inspection | UNTESTED. Only the original fixture's size/hash were verified. |
| Works without foregrounding Blip | Blip became active during this trial | CONTRADICTED for a claim that this exact invocation never activates Blip; general hidden-window operation remains untested. |
| Works after restart | No restart performed | UNTESTED; outside this approval. |

## Stop and integrity check

The appearance of the recipient picker reached the manual-interaction boundary. The test stopped without selecting a recipient, pressing Send, dismissing the picker, or invoking the service again. Whether the picker remains visible afterward is not established; the agent did not close it.

A read-only postcheck confirmed that the original fixture is still 63 bytes with the same SHA-256 and that both probe source and executable hashes are unchanged. Evidence: `audit/evidence/services-handoff-live/postcheck.json`. No file from Android was read, imported or retransmitted.

The observation does not establish that nothing could have happened automatically inside Blip; it establishes that this audit has **no verified transfer start, completion or Android receipt**. No transfer claim is inferred from CPU quietness, sockets, elapsed time, the service return or app activation.

## Next recommended test — not executed

First obtain **separate approval for manual recipient selection in the existing picker** and, if required, the explicit Send action for this same synthetic fixture. Do not invoke the service again merely to recreate the picker. This would test whether the staged item can be sent through the official interactive flow; it would not prove automatic recipient selection.

Before claiming completion, record the official Android app's receipt/outcome and verify the received file is **63 bytes** and hashes to `c0c19d30a8a610246415acfb980138cfe2d52714d7a670adde93735646154afd`, using an existing authorized means. No new Android application, permission change or return transfer is approved by this experiment. If received-byte access is unavailable, delivery/integrity must remain separately qualified.

The alternative Launch Services test is still unexecuted and requires its own approval. Production `blipctl send`, background/no-window guarantees and Milestone 1's automatic-send gate remain on hold. This experiment is finished; there is no automatic continuation.
