# 27 — Incoming transfer observability

Audit date: 2026-10-19, Asia/Kolkata. Scope: read-only source and retained telemetry review, primary documentation, synthetic local filesystem probe. No real transfer, Blip setting change, permission request, Photos access, or monitoring daemon was started.

The existing evidence supports filesystem change candidates and process activity samples. It does not supply a verified Blip-specific incoming-transfer event, byte-progress feed, or completion acknowledgement. Production transfer HUD work remains on hold.

## Finding ledger

| Finding | Classification | Evidence / actual result | Limitation |
|---|---|---|---|
| The historical monitor watches top-level files in Downloads, Desktop and Documents | VERIFIED | `scripts/blip_transfer_monitor.py:18` and `:42`; `os.scandir` with `entry.is_file(follow_symlinks=False)` | Does not recurse into received folders, observe a custom destination, or prove the writer is Blip. |
| It can include an unrelated file write in its received-file candidates | VERIFIED | Synthetic probe below reports `unrelated-editor-save.txt` with no Blip operation | Demonstrates helper behavior, not a live transfer. |
| It omits nested arrivals | VERIFIED | Same probe returns `nested_file_detected: false` | Folders and subdirectories need separate tracking. |
| Ten quiet CPU/socket samples mean a successful completed transfer | CONTRADICTED | Source `:170–179` prints completion after quiet samples without consulting transfer state | An idle period can mean a stalled, paused, cancelled, failed, or unrelated operation. Approximate sample timing also includes `ps`/`lsof` execution costs. |
| Every socket except one hardcoded public IP is a direct LAN transfer | CONTRADICTED | Source `:207–215` assigns all other endpoints to `lan_conns` | Another public relay address is mislabeled LAN. Socket existence does not identify bulk bytes, protocol role, transfer direction, or success. |
| Report 13's incoming photo reached Apple Photos | UNTESTED | Report 13/16 claim this; both retained historical telemetry records have zero detected files in `audit/evidence/readonly-baseline.json` | No received asset/file or app-level success record was captured. A missed destination, nested file, incomplete transfer, or no transfer are also consistent with that telemetry. |
| Binary strings suggest Downloads and media autosave code exists | INFERRED | Root's read-only binary inspection retained `xplat.DownloadsDirectory` and `Event_TransferSetAutoSaveToMediaLibrary` in `audit/evidence/readonly-baseline.json` | Cross-platform symbols do not identify active macOS setting, default destination, or execution for a historical transfer. |
| A public system notification API lets a helper consume Blip's delivered notifications | CONTRADICTED for the proposed generic UserNotifications approach | Apple's `getDeliveredNotifications` API applies to the calling app's notifications | No documented Blip event API was found. A different authorized vendor integration remains untested. |
| FSEvents alone yields real-time transfer percentages and authoritative completion | CONTRADICTED | Apple callback carries paths/flags/IDs; no transfer total, expected item set, or Blip completion state | Size growth can estimate local write activity only. Resumes, decompression, temporary files, preallocation, and renames can break transfer-progress assumptions. |
| Actual arrival while backgrounded/locked and persistence across Blip restarts | UNTESTED | No live operation performed in this audit | Requires an approved synthetic transfer and explicit app lifecycle test. No restart performed, preserving existing transfers. |

## Downloads and configurable destination folders

An observer can report that a file appeared or changed, including filename, size and time, when filesystem access is already authorized. [Apple's FSEvents contract](https://developer.apple.com/documentation/coreservices/fseventstreamcallback) is a filesystem event source, not a Blip protocol event source. Event coalescing, dropped-event flags and rescans must be handled in any future implementation. [Apple's handling guidance](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html) documents these conditions.

A file in `~/Downloads` may have come from a browser, shell, sync client, editor, another transfer application, or Blip. A stable size for a fixed interval is only a settlement heuristic. It is insufficient to announce transfer success. A hash proves content equality only when compared with a known synthetic source hash; it does not prove transport, sender, or which application wrote the copy.

The installed build's active/default destination is UNTESTED; private settings were not accessed. The iPhone/iPad [Blip App Store listing](https://apps.apple.com/us/app/blip-send-files-in-a-click/id6463305181) documents a custom save folder for that platform, not for this Mac build. The local Downloads/media symbols provide a candidate for later UI verification. If the official macOS settings support a dedicated destination and the user approves changing it, that folder can reduce unrelated traffic. Other writers can still use it. Do not change that setting until approval.

Future observer labels should be honest: `file appeared`, `file changed`, or `candidate arrival — source unverified`. Only a verified supported app event or independently recorded official-app success plus matching synthetic payload can justify stronger language. No watcher or configuration was implemented for this milestone.

## Apple Photos

The historical reports infer direct Photos import from media autosave symbols and the absence of files in three scanned directories. That inference does not establish the actual destination. A Photos framework link or autosave event name is static evidence of possible functionality, not proof it ran on macOS for the recorded sample.

The public [Photos change-observer API](https://developer.apple.com/documentation/photos/phphotolibrary/register(_:)-6y3b9) can report changes to fetched assets and collections under the appropriate authorization. The API does not provide a Blip transfer identifier or authoritative network progress. iCloud sync, user imports, edits and other apps also change a library. Monitoring a Photos library package's file activity would be even less specific and is outside this plan. The private Photos database was never opened or modified.

Actual macOS media import, current autosave behavior, and asset-to-transfer attribution remain UNTESTED. If the user later approves a synthetic media transfer, verify using the official app/Photos user interface and an identifiable synthetic image. A separate helper's Photos access requires its own permission review; it was not requested here.

## Notifications and automation

The [UserNotifications delivered-notification API](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/getdeliverednotifications(completionhandler:)) is scoped to the caller's app. It does not permit `blipctl` to subscribe to Blip's Notification Center stream. No notification databases, UI scraping, private daemon hooks or Accessibility permission requests were used.

No published Blip transfer-event, Shortcuts completion-trigger, webhook, or external progress API was found in the bounded primary-source search documented in `audit/evidence/official-docs.md`. That is an UNTESTED/unknown integration boundary, not proof no vendor-supported option exists. `DownloadSession.ProgressBytes` in the installed binary is an internal symbol candidate; it does not establish an authorized external API.

UI/Accessibility automation remains a permission-gated fallback only. The existing evidence does not establish that it can reliably map an arrival to a transfer, survive interface changes, or suppress windows. It was not enabled or run.

## Reproducible local evidence

From `/Users/nilambarbehera/Documents/Projects/REA/blip-research`:

```sh
nl -ba scripts/blip_transfer_monitor.py | sed -n '20,270p'
shasum -a 256 scripts/blip_transfer_monitor.py
python3 audit/evidence/observability_synthetic_probe.py
```

Relevant source SHA-256:

```text
12814302fd71605e0947aaba3dbbb50f9ed1c475c2bd18556deb34a926c52753  scripts/blip_transfer_monitor.py
```

Relevant actual probe output:

```json
{
  "blip_operation_performed": false,
  "new_or_modified_reported": ["unrelated-editor-save.txt"],
  "nested_file_detected": false,
  "classification": "Filesystem candidate changes only; neither sender identity nor completion established"
}
```

Exact test source: `audit/evidence/observability_synthetic_probe.py`. Full output: `audit/evidence/observability-synthetic-output.json`. All fixture writes are below `audit/evidence/observability-fixture`. The helper was imported without running its main routine; `WATCH_DIRS` was replaced before the scan. No personal directory contents were inspected by the probe. The historical monitor is unchanged, and it should not be treated as a completion detector.

## Approval-gated next validation

An approved future test should send one uniquely named synthetic non-image from the unchanged official Android Blip app to the unchanged official Mac app. Record the official-app outcome, destination selected/shown by the app, resulting file path/length, and equality with an expected hash. Repeat a media sample only if needed. Test background and restart behavior separately while no transfer is active. File/event correlation remains an inference until an application-supported transfer identifier links the events.

No current result justifies real-time progress percentages, automatic recipient-specific sending, a background daemon, or droplet installation. This report's successful experiment concerns the limitations of the existing scan helper only.
