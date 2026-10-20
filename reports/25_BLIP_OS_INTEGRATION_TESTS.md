# 25 — Blip OS integration tests

Audit date: 2026-10-19, Asia/Kolkata. All commands below run from `/Users/nilambarbehera/Documents/Projects/REA/blip-research`.

The installed app exposes genuine OS integration declarations. Actual file handoff, recipient selection and sending remain UNTESTED because a handoff can trigger a real transfer using existing settings. No transfer approval has yet been given. No app was launched, activated, hidden, quit or restarted for this audit.

## Results matrix

`D` = declaration VERIFIED; `I` = INFERRED candidate; `U` = UNTESTED. None of the U entries means “unsupported” or “works.”

| Interface | Actually accepts file URLs | Opens send interface | Selects already paired Android | Initiates without manual selection | Works while Blip backgrounded | No foreground window | After Blip restart |
|---|---|---|---|---|---|---|---|
| NSServices / NSPerformService | U; D for public.url and other input types; local file-URL pasteboard serialization verified | U | U | U | U | U | U |
| Launch Services / NSWorkspace.open | U for arbitrary file; I from `application:openFiles:` / `openURLs:` selectors | U | U | U | U | U | U |
| Registered `blip://` scheme | U; D and current OS routing verified, no send-payload syntax verified | U | U | U | U | U | U |
| Shortcuts / SiriKit / automation | U; intent metadata exists | U | U | U | U | U | U |
| Accessibility / UI automation | U; gated fallback, no permission queried/requested | U | U | U | U | U | U |

## A. Services

Source: `/Applications/Blip.app/Contents/Info.plist`. Exact inspection:

```sh
plutil -extract NSServices json -o - /Applications/Blip.app/Contents/Info.plist
```

Actual declaration: menu `Blip…` (U+2026 ellipsis), `NSMessage=blip`, `NSPortName=Blip`, input types `public.content`, `public.url`, `public.directory`, `public.folder`. Native binary selectors include `servicesProvider` and `setServicesProvider:`; full bounded strings output is in `audit/evidence/readonly-baseline.json`.

A synthetic file URL conforms to `public.url` and round-trips through a unique native pasteboard. This verifies serialization only. It does not prove service registration is enabled, the input is accepted by Blip, or the service initiates a transfer.

```sh
TMPDIR="$PWD/audit/tmp/" xcrun swiftc -swift-version 6 \
  -module-cache-path "$PWD/audit/.swift-module-cache" \
  "$PWD/audit/probes/PasteboardProbe.swift" -o "$PWD/audit/bin/PasteboardProbe"
audit/bin/PasteboardProbe "$PWD/audit/fixtures/milestone 1 synthetic.txt"
```

Actual exit 0. Relevant output:

```json
{"wroteFileURL":true,"fileURLConformsToPublicURL":true,"fileURLRoundTrip":true,"blipInvoked":false,"transferAttempted":false,"generalClipboardTouched":false}
```

Pasteboard types included `public.file-url` and `NSFilenamesPboardType`. A nonfatal stderr diagnostic, `sandbox_extension_consume failed: 1 (Operation not permitted)`, is retained in `audit/evidence/pasteboard-run.json`; the round-trip result is not a security-scoped access grant to Blip. No permission was requested or changed. The general clipboard was never used.

[NSPerformService](https://developer.apple.com/documentation/appkit/nsperformservice(_:_:)) reports whether the service was performed. Its Boolean does not contain a recipient, transferred byte count or delivery receipt. Consequently even a future `true` result must not be labeled “sent.”

## B. Launch Services

Bundle `CFBundleDocumentTypes` declares only Internet Shortcut `.url` / `com.microsoft.internet-shortcut`, Viewer, alternate handler. It does not declare universal document handling. Binary selector strings `application:openFiles:` and `application:openURLs:` support a candidate explicit-application handoff, not verified file acceptance.

```sh
plutil -extract CFBundleDocumentTypes json -o - /Applications/Blip.app/Contents/Info.plist
blipctl/bin/blipctl capabilities
```

The prepared probe uses `NSWorkspace.shared.open([fileURL], withApplicationAt: /Applications/Blip.app, configuration: …)` with `activates=false`, `hides=true`. Those flags are [OS launch configuration](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration); they do not prevent Blip from presenting its own send window. A successful callback acknowledges opening, not transfer initiation or delivery. The probe was compiled only.

## C. URL scheme

```sh
plutil -extract CFBundleURLTypes json -o - /Applications/Blip.app/Contents/Info.plist
blipctl/bin/blipctl status
```

Actual native status result includes `registeredBlipSchemeApplication=/Applications/Blip.app`. This uses `NSWorkspace.urlForApplication(toOpen:)` to query routing, without opening `blip://`. `CFBundleURLName=net.blip.macos.push`, scheme `blip`, Viewer role are VERIFIED. The word `push` does not establish a file-send API. No URL was opened and no undocumented path or recipient parameter was guessed. Pairing and invitation effects also remain UNTESTED.

## D. Shortcuts and automation

Sources: `/Applications/Blip.app/Contents/Resources/Intents.intentdefinition`, main and share-extension Info.plists. The intent plist actually defines `SendMessage` / `INSendMessageIntent`, with `recipients: Person`, `content: String` and `attachments: Object` among its parameters. Some parameter combinations declare background execution. This is stronger metadata than a lone activity string, but still not a working shortcut or a device-selector contract. `audit/evidence/intents-metadata.json` preserves the parsed entries.

Reproduce the parsing without executing any intent:

```sh
python3 - <<'PY'
import plistlib
p='/Applications/Blip.app/Contents/Resources/Intents.intentdefinition'
for i in plistlib.load(open(p,'rb'))['INIntents']:
 print(i['INIntentName'],[(p['INIntentParameterName'],p['INIntentParameterType']) for p in i['INIntentParameters']])
PY
```

No `.sdef` or `.appintents` filename was found within the installed bundle, and the inspected plists did not declare an Intents service extension or AppleScript dictionary. These are bounded observations, not proof all automation is absent. The official-source search in `audit/evidence/official-docs.md` found no published Blip file-send/recipient/action contract. Personal shortcuts were not enumerated and no shortcut or Apple Event was executed.

## E. Accessibility fallback

UNTESTED. No `AXIsProcessTrustedWithOptions(prompt:true)`, AppleScript/System Events, TCC modification, permission request, click or keystroke was performed. If later authorized, a UI test must identify the real current recipient picker, distinguish selection from send initiation, and record actual app/recipient outcomes. UI automation does not itself establish stability after updates, hidden-window operation or progress semantics.

## Concrete next test, execution withheld

Source: `audit/probes/HandoffProbe.swift`. It accepts only a marked UTF-8 synthetic fixture of at most 1 KiB directly under this research directory's `audit/fixtures`; it rejects paths escaping the research root. It never accesses a private socket or credentials. The current fixture is 63 bytes. This is a separate research probe; `blipctl send` remains disabled.

Compilation completed successfully, with no diagnostic in `audit/evidence/handoff-probe-build.log`:

```sh
TMPDIR="$PWD/audit/tmp/" xcrun swiftc -swift-version 6 -parse-as-library \
  -module-cache-path "$PWD/audit/.swift-module-cache" \
  "$PWD/audit/probes/HandoffProbe.swift" -o "$PWD/audit/bin/HandoffProbe"
```

**NOT EXECUTED — requires explicit approval because it may transmit a real synthetic file:**

```sh
audit/bin/HandoffProbe --acknowledge-may-transmit service \
  --file "$PWD/audit/fixtures/milestone 1 synthetic.txt"
```

The alternative `workspace` mechanism is also prepared, but is a separate test to select after the first outcome; no automatic fallback/retry is performed. Approval for one probe does not authorize changing app settings, granting permissions, restarting Blip or loading Droppy code.

An approved experiment must record the service/callback result, whether the send interface appears, whether recipient selection is required, and the official recipient's actual outcome. If delivered, compare the received synthetic bytes/hash; a service return, file opening or local file hash alone cannot establish successful sending. Background, no-window and restart behavior require their own controlled trials while existing transfers are idle. Until then the fully automatic send path is UNTESTED and disabled.
