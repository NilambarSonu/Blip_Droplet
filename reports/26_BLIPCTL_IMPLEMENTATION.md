# 26 — blipctl implementation

Audit date: 2026-10-19, Asia/Kolkata. A small native CLI was built successfully using the existing Apple Command Line Tools. It reports installed-app/runtime metadata, candidate interface declarations and local file validation. No sending integration has yet passed runtime validation, so real sending is intentionally refused.

## Files

- Source: `/Users/nilambarbehera/Documents/Projects/REA/blip-research/blipctl/Sources/blipctl/main.swift`.
- Dependency-free SwiftPM manifest: `blipctl/Package.swift`.
- Local compiler entry point: `blipctl/build.sh`.
- Executable: `blipctl/bin/blipctl`.
- Meaningful safety checks: `blipctl/verify.py`.
- Raw results: `audit/evidence/blipctl-checks.json`, `blipctl-checks.log`, `blipctl-build.log`.

The SwiftPM manifest describes the package; the tested build uses `xcrun swiftc` directly to minimize tooling and keep all explicit caches, temporary paths and outputs under research. No dependency fetch or Xcode installation is necessary. SwiftPM compilation itself was not separately executed and is not claimed as tested.

## Reproduce

```sh
cd /Users/nilambarbehera/Documents/Projects/REA/blip-research
sh blipctl/build.sh
python3 blipctl/verify.py
blipctl/bin/blipctl status
blipctl/bin/blipctl capabilities
blipctl/bin/blipctl send --dry-run "$PWD/audit/fixtures/milestone 1 synthetic.txt"
```

The build command exited 0 with no compiler diagnostics. It uses Swift 6 mode and optimization, links system Foundation/AppKit/UniformTypeIdentifiers, and creates no service or daemon. The initial executable was 102,104 bytes; this is not a runtime-memory benchmark or a droplet size claim.

`status` actual output, selected fields:

```json
{"applicationPath":"/Applications/Blip.app","bundleIdentifier":"net.blip.macos","version":"1.2.3","build":"20260927200815","running":true,"processes":[{"pid":5838,"active":false,"hidden":false}],"registeredBlipSchemeApplication":"/Applications/Blip.app","authenticationStatus":"not-inspected","pairedRecipients":"not-inspected","transferStatus":"unavailable-no-verified-source"}
```

“Running” means an OS process exists. It does not mean authenticated, online, paired, idle or ready to receive. “Hidden” and “active” are OS process properties, not a list of visible windows. The status query never launches or activates Blip.

`capabilities` reports the actual Services, document-type, scheme and user-activity declarations. Selected results:

```json
{"fileHandoff":"declared-candidate-runtime-unverified","recipientSelection":"no-verified-supported-interface","automaticSend":"unverified-disabled","progress":"no-verified-source","sendEnabled":false,"requiresApprovalForHandoffTest":true}
```

`send --dry-run` validates a readable local regular file, normalizes its file URL and symlink target, reports size/content type, and reads no payload bytes. The synthetic fixture actual result includes `bytes=63`, `contentType=public.plain-text`, `localFileValid=true`, `handoffAttempted=false`, `transferAttempted=false`, `sendEnabled=false`. Exit 0 means local validation only. Directories, special files, missing files and remote URLs are refused. A user can validate any explicitly supplied local file path, but this audit's tests used only synthetic fixtures.

```sh
blipctl/bin/blipctl send "$PWD/audit/fixtures/milestone 1 synthetic.txt"
```

Actual exit **77**, error:

```text
Sending is disabled: approval and successful official-interface validation are required. Use send --dry-run <file> for local validation.
```

This refusal path was executed as a safety check; it contains no app dispatch operation. The separate handoff probe described in report 25 is compiled but unexecuted. It is not an implemented transfer backend. Enabling actual `send` requires a later approved, verified integration and an honest output contract for whatever outcome is observable.

## Verification and limits

Actual verification summary:

```text
status PASS 0
capabilities PASS 0
dry-run PASS 0
file-url PASS 0
symlink PASS 0
literal-shell-characters PASS 0
missing PASS 66
directory PASS 66
remote-url PASS 66
remote-file-host PASS 66
send-refused PASS 77
unknown-option PASS 64
extra-argument PASS 64
13 checks passed. No handoff or transfer attempted.
```

The shell-character case passes a synthetic filename containing `$()`, a semicolon and quotes as a literal argument. There is no shell invocation in the Swift CLI; Python checks use argument arrays. No recipient names, device IDs, credentials, progress percentages, simulated completion, background agent or hidden transfer path are included. JSON goes to stdout, errors include explicit nonzero exit status, and unexpected JSON serialization errors go to stderr. No persistent app/account log is collected.

The utility reads the fixed installed bundle's metadata and public process/Launch Services information. Independent bundle signature verification and app binary hashes are recorded by the audit collector; the CLI's bundle-identifier check is not a replacement for cryptographic signature verification. No fully automatic sending, arrival notification or transfer progress claim is justified by this implementation.
