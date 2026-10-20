# 24 — Codex independent audit

Audit date: 2026-10-19, Asia/Kolkata. Research root: `/Users/nilambarbehera/Documents/Projects/REA/blip-research`.

Milestone 1 has a working read-only native utility, but no demonstrated recipient-specific sending integration. Reports 20–23 materially overstate both impossibility and feasibility. Most significantly, the running official Blip process has a named Unix socket, directly contradicting the asserted absence of external IPC.

## Inventory and evidence rules

Read reports 01 through 23, including the updated reports 13 and 16. Their original contents were preserved. The independent report byte counts and SHA-256 inventory are in `audit/evidence/readonly-baseline.json`, record `reports-01-23`. Also inspected the actual isolated droplet Swift source, manifest, SwiftPM configuration, harness, existing isolated `.build` metadata, and `scripts/blip_transfer_monitor.py`. The two specific telemetry JSON files named in report 13 still exist and were parsed using an allowlist of telemetry fields. No account database, Keychain item, token, private key, or private Photos database was read.

The root is not a Git repository. The only initial source package is `blip-research-droplet/blip-research`. Its SDK references previously pointed outside this research directory into the expressly excluded project. Those locations and historical logs were not accessed. A fresh official SDK was obtained inside `audit/vendor/droppykit`; see report 28 for revision and build evidence. Reports referring to external historical builds are claims, not independently authenticated build provenance.

The installed app is `/Applications/Blip.app`, bundle `net.blip.macos`, version `1.2.3`, build `20260927200815`. It was already running as PID 5838. Selected developer directory is `/Library/Developer/CommandLineTools`; compiler is Apple Swift 6.4. No Xcode acquisition, application restart, transfer, permission change, settings change, remote write, or droplet load was performed.

Classification vocabulary: **VERIFIED** means directly observed within the stated boundary; **INFERRED** means supported interpretation; **UNTESTED** means the evidence needed to decide is missing; **CONTRADICTED** identifies a claim inconsistent with a direct observation or the cited API contract. A bounded unsuccessful search is not a proof of universal absence.

## Reports 20–23: finding ledger

| Claim under review | Classification | Independent result and limitation |
|---|---|---|
| Installed BlipKit contains no headers, module map, `.swiftmodule` or `.swiftinterface` | VERIFIED | Framework inventory contains binary/resources/signature only. A normal `import BlipKit` typecheck fails. This concerns the shipped framework, not every vendor-authorized integration. |
| Every substantive BlipKit symbol is private because it is Swift-mangled | CONTRADICTED | `nm -arch arm64 -gU` returns globally defined symbols, including hosting and RPC-client constructors. Mangling is a name encoding, not proof of private visibility or lack of linker exports. Exported ABI does not establish documented, stable, licensed or supported third-party API. |
| There is no usable supported public BlipKit SDK | INFERRED | No shipped development interface or published SDK contract found in the examined bundle/docs. Actual rehosting is UNTESTED. This does not establish mathematical impossibility. |
| Blip is App-Sandboxed because it has an App Group entitlement | CONTRADICTED | App entitlements include an application group but no `com.apple.security.app-sandbox`. Modern group-container protection still applies outside App Sandbox. |
| A separate developer needs Blip's private certificate and a provisioning profile in every possible authorized hosting arrangement | CONTRADICTED as a universal platform claim | Apple distinguishes team-prefixed groups, provisioning, and user-authorized container access. No entitlement impersonation or permission request was attempted. Actual independent hosting of this engine remains UNTESTED and unsupported by current evidence. |
| Reported `ls … EPERM` proves every form of headless hosting is impossible | UNTESTED / unsupported conclusion | The historical denial is not an independent test of every host, initialization path, vendor-supported API, or authorization model. No container access was retried. |
| The framework's designated signing requirement alone proves any independent host cannot load it | UNTESTED / unsupported conclusion | A framework's designated requirement identifies its signature. Library validation is a host policy; the hypothetical host and initialization were never tested. No framework was loaded, resigned or altered. |
| No external Unix or TCP IPC socket exists | CONTRADICTED | Live `lsof -U` shows the named group-container `Library/Caches/sock` socket. The earlier `lsof -i` scope excludes Unix sockets. |
| All DRPC execution is exclusively in-memory | CONTRADICTED as the asserted exhaustive boundary | A named Unix socket and exported `Core(connectingToRPCServer:lowEnergy:)` / `RPCSockFileAddress` are counter-evidence. Association of this live socket with DRPC is INFERRED; its actual protocol, access controls and supported third-party contract are UNTESTED. No connection was made. |
| Services / Launch Services guarantee automatic Android delivery | UNTESTED | Declarations and handlers exist; no approved invocation or recipient/delivery result exists. See report 25. |
| `INSendMessageIntent` guarantees a callable file-send shortcut | UNTESTED | Installed intent metadata includes recipients and attachments, but declaration is not execution, registration of a usable action, or successful file delivery. |
| Zero maintenance, 100% reliability, APNS wake during Mac sleep | UNTESTED | No relevant update, sleep, restart, background or lifecycle experiment supports the guarantees. |
| Unchanged official DroppyKit builds with this CLT | CONTRADICTED | Fresh SDK compile reproduces `SwiftUIMacros.StateMacro` and `EntryMacro` failures. Report 22 correctly identifies a real local failure, but its universal explanation is too broad. |
| Every SwiftUI build requires local Xcode | CONTRADICTED | Native AppKit CLI builds; a small SwiftUI wrapper-alias probe typechecks using CLT. That probe is not a complete DroppyKit fix. |
| A compatible prebuilt module solves the full droplet build on this machine | UNTESTED | Installed host framework has no module interfaces. A trusted compiler-compatible prebuilt module/interface remains a candidate, not an existing verified solution. |
| GitHub Actions reliably builds the isolated droplet | UNTESTED | A pinned, manually triggered workflow is prepared. No remote run or artifact exists from this audit. See report 28. |

Apple describes group protection outside App Sandbox, team-prefix checks without a provisioning profile, and authorization prompts for nonmembers in [Accessing app group containers](https://developer.apple.com/documentation/xcode/accessing-app-group-containers). This narrows the blanket impossibility claim; it supplies no permission to reuse credentials or operate private RPC. [Library validation documentation](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.cs.disable-library-validation) describes a hardened host's loading policy, which is distinct from the loaded framework's designated requirement.

## Reproducible commands and actual output

Run from the research root:

```sh
python3 audit/collect_readonly.py
xcode-select -p
xcrun swiftc --version
xcrun --find swift-demangle
codesign --verify --deep --strict /Applications/Blip.app
codesign -d --entitlements :- /Applications/Blip.app
lsof -nP -a -p 5838 -U
nm -arch arm64 -gU /Applications/Blip.app/Contents/Frameworks/BlipKit.framework/BlipKit | xcrun swift-demangle
```

PID 5838 is the observed PID for this audit, not a value to hardcode into a future monitor. `pgrep -x Blip` obtains the current PID without restarting it.

Relevant output:

```text
/Library/Developer/CommandLineTools
Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
/Library/Developer/CommandLineTools/usr/bin/swift-demangle
```

`codesign --verify` exited 0 with no diagnostic. Entitlements contain `application-groups = [AY8UB8KTUX.blip]`, `cs.disable-library-validation = true`, and `personal-information.photos-library = true`; no app-sandbox key.

The Unix-socket output contains this descriptor (other connected Unix descriptors are preserved in the JSON):

```text
Blip 5838 … 15u unix … /Users/nilambarbehera/Library/Group Containers/AY8UB8KTUX.blip/Library/Caches/sock
```

Selected demangled exports:

```text
static BlipKit.Core.startHosting(takeover: Swift.Bool) -> ()
static BlipKit.Core.stopHosting() -> ()
BlipKit.Core.__allocating_init(connectingToRPCServer: Swift.String, lowEnergy: Swift.Bool) -> BlipKit.Core
static BlipKit.AppInfo.RPCSockFileAddress.getter : Swift.String
```

Exact full addresses, selection terms, command strings and exit statuses: `audit/evidence/blipkit-demangled.json`. The count of 29,539 globally defined arm64 symbols is a linker inventory, not a count of supported APIs. No function above was called; `startHosting(takeover:)` could interfere with the installed engine and is outside this audit's execution scope.

Normal import test, source `audit/probes/ImportBlipKit.swift`:

```sh
xcrun swiftc -typecheck -F /Applications/Blip.app/Contents/Frameworks \
  -module-cache-path "$PWD/audit/.swift-module-cache" "$PWD/audit/probes/ImportBlipKit.swift"
```

Actual exit 1: `error: no such module 'BlipKit'`. Full result: `audit/evidence/blipkit-import.json`. This proves the ordinary source import is unavailable here, not that every possible binary interface is unusable.

## Reports 13 and 16: retained live-test evidence

Exact inputs are `/tmp/blip_transfer_1792343331.json` and `/tmp/blip_transfer_1792343580.json`. Allowlisted contents, hashes and source paths are retained in `readonly-baseline.json`; the original files were not modified.

| Recorded value | First record | Second record | What it actually establishes |
|---|---:|---:|---|
| `duration_seconds` | 1.1366989613 | 24.3928539753 | Monitor activity interval derived from heuristics; not a verified transfer duration. |
| Baseline / peak RSS MiB | 215.9375 / 216.0 | 224.875 / 240.375 | Recorded process-memory samples; monitor divides KiB by 1024. |
| Peak sampled `%cpu` | 7.8 | 49.6 | Recorded `ps` statistic, not byte progress or proof of encryption/compression. |
| Listeners | none sampled | IPv4 :49541, IPv6 :49539/:49540 | Listening socket observations; no proof a particular Go function executed. |
| Detected files | 0 | 0 | Neither record captures a received payload/hash or app-level success acknowledgement. |

The second JSON places public endpoint `137.184.103.12:443` inside `direct_lan_endpoints`, exposing the hardcoded-IP classification defect. Inferring a separate data-relay role from this connection is plausible, but the socket sample contains no verified payload-byte attribution. The first record's lone connection to `137.184.135.31:443` does not prove a photo was tunneled through it. Absence of scanned files does not prove Photos import. Historical user-observed successful transfers may have occurred; this audit does not independently establish their completion or route from these records alone. Offline operation was not tested and cannot be disproved by an online sample.

## REA skills and verification boundary

Read all five upstream skills at revision `273bb662763406662b4c061887397e9e5f27aa4d`; local copies and `REVISION` are in `audit/rea-skills`.

| Skill | Application |
|---|---|
| `reverse-engineer-anything` | Staged artifact/runtime evidence, bounded negative findings, explicit unknowns; its broader-investigation instruction calls for parallel independent scopes, used for SDK/toolchain and official-doc review. |
| `rea-ci-tests-audit` | Trace build/validator commands and separate missing artifact from passing static checks. User's isolation requirement overrides its suggested `/tmp` notes location. |
| `rea-tool-design` | Explicit distinction between local validation, app handoff, transfer initiation and delivery in `blipctl` output. No REA API contract was changed. |
| `rea-analysis-optimization` | Preserve producer identity and scope; no performance improvement or memory-saving claim made. Provider optimization is otherwise inapplicable. |
| `rea-changelog-update` | Reviewed; release-history/changelog publication is inapplicable to this milestone and was not executed. |

The [pinned REA skill](https://github.com/morluto/rea/blob/273bb662763406662b4c061887397e9e5f27aa4d/.agents/skills/reverse-engineer-anything/SKILL.md) and its native/recovery references were read. No REA MCP tools are exposed in this session and `command -v rea` found no CLI on PATH. No REA native session, decompiler, injected tracer or setup/configuration change was used. All local results are explicitly ordinary Apple-tool/Python/Swift evidence; no REA Evidence IDs or decompiled schemas are invented. The older reports' reconstructed protobuf schemas are not authenticated source definitions.

Reports 25–29 record the safe implementation, interface test boundary, incoming observability, cloud build plan and milestone verdict.
