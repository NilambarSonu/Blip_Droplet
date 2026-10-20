# 28 — Independent Droppy toolchain audit and manual cloud build plan

Audit date: 2026-10-19 (Asia/Kolkata). All new local files are under `/Users/nilambarbehera/Documents/Projects/REA/blip-research`. No Xcode was installed or downloaded, no unrelated project was accessed, no remote repository was changed, and no droplet was loaded, installed, submitted or published.

## Verdict

**VERIFIED:** the unchanged official DroppyKit v1.20.1 source fails with the installed Apple Command Line Tools. A fresh native-engine release build reproduced both missing `SwiftUIMacros.StateMacro` and `SwiftUIMacros.EntryMacro` diagnostics. The installed DroppyKit framework has no public module interfaces in the inspected framework directory.

**CONTRADICTED as a universal statement:** SwiftUI state necessarily requires Xcode. A small source-compatible property-wrapper alias typechecks with the existing CLT. This does **not** fix the unchanged SDK's `@Entry` macros or prove a complete droplet build.

**INFERRED:** an existing Xcode-equipped macOS GitHub runner is a reasonable way to build the isolated droplet without local Xcode. A manual workflow and bounded build script are ready for review.

**UNTESTED:** this particular package compiles on that runner, the final artifact passes linkage/API checks, and the artifact renders or loads correctly. No GitHub Actions run was started. Cloud reliability cannot be certified from a workflow file or a historical narrative.

## 1. Source and provenance

Only a fresh official SDK checkout was used:

```sh
cd /Users/nilambarbehera/Documents/Projects/REA/blip-research
git clone --depth 1 --branch v1.20.1 https://gitlab.com/droppyformac1/droppykit.git audit/vendor/droppykit
git -C audit/vendor/droppykit rev-parse HEAD
```

Actual output:

```text
3d728a7981975714057650f80639c1e27d512fdb
```

The tag object is `6619de6e9b346dde1a8d594c9dccbb669faf8a27`; its peeled commit is the hash above. The checkout is detached at that commit. `git status --porcelain` is empty. The SDK's unmodified `Scripts/build-droplet.sh`, `Scripts/validate-droplet.sh`, `Package.swift`, relevant capability protocols and design tokens were inspected directly.

The isolated package had `.package(..., from: "1.6.0")`; the report/brief claimed a fixed v1.20.1 SDK. **CONTRADICTED:** the old package declaration did not pin that version. It now uses `exact: "1.20.1"`, with a checked `Package.resolved` containing the audited commit. A real `swift package resolve` completed with exit 0:

```text
Computed https://gitlab.com/droppyformac1/droppykit.git at 1.20.1
Working copy of https://gitlab.com/droppyformac1/droppykit.git resolved at 1.20.1
```

Exact resolution arguments and output: `audit/evidence/droplet-resolution.json`.

The existing package brief and MCP configurations contained an SDK path in an explicitly excluded unrelated project. Those references were replaced with the fresh research-local checkout in `AGENTS.md`, `.mcp.json`, `.cursor/mcp.json` and `.cursor/rules/droppykit.mdc`. No file at the excluded path was opened, copied or executed. The brief now explicitly defers loading, installation and publication steps to the user's approval constraints. Merely correcting MCP configuration does not start or register its server.

## 2. Independent CLT reproduction

Commands:

```sh
xcode-select -p
xcrun swiftc --version
xcrun --show-sdk-path
python3 audit/toolchain/run_probes.py
python3 audit/toolchain/check_sdk.py
```

Relevant actual output:

```text
/Library/Developer/CommandLineTools
Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
Target: arm64-apple-macosx27.2.0
/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

`check_sdk.py` executes this exact build, with compiler module caches and temporary files inside `audit/toolchain/cache`:

```sh
xcrun swift build \
  --package-path /Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/vendor/droppykit \
  --scratch-path /Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/toolchain/sdk-native \
  --cache-path /Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/toolchain/cache/swiftpm \
  --config-path /Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/toolchain/cache/config \
  --security-path /Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/toolchain/cache/security \
  --build-system native --target DroppyKit --configuration release --arch arm64 \
  -Xswiftc -enable-library-evolution -Xswiftc -emit-module-interface
```

Exit code: **1**. Fresh diagnostics include:

```text
Sources/DroppyKit/Capabilities/SettingsPagesProviding.swift:528:24:
error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found
Sources/DroppyKit/DesignSystem/SettingsRows.swift:95:16:
error: external macro implementation type 'SwiftUIMacros.EntryMacro' could not be found for macro 'Entry()'; plugin for module 'SwiftUIMacros' not found
```

Full command/exit: `audit/evidence/droppykit-clt-native.json`; full output: `audit/evidence/droppykit-clt-native.log`. The original package `.build` was preserved; the fresh reproduction uses a separate scratch directory.

The installed SDK's `SwiftUICore.swiftinterface` declares both `State<Value>` as a property wrapper and new macros named `State`. Its `State()` macro references `SwiftUIMacros.StateMacro`. A bounded filename search under the installed CLT found no `*SwiftUIMacros*` file. This establishes the observed toolchain failure; it does not establish where every Apple release distributes plugins.

Probe sources in `audit/toolchain/` were each typechecked with:

```sh
xcrun swiftc -typecheck \
  -module-cache-path /Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/toolchain/cache/swift \
  /Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/toolchain/StateAliasProbe.swift
```

| Probe source | Actual result | Interpretation |
|---|---|---|
| `StateProbe.swift` — ordinary `@State` | Exit 1; missing StateMacro | Original failure independently reproduced |
| `StateGenericProbe.swift` — `@State<Int>` | Exit 1; missing StateMacro | Explicit generic spelling alone does not help |
| `StateExplicitStorageProbe.swift` — explicit `SwiftUI.State<Int>(initialValue:)` | Exit 0; no output | A SwiftUI view can typecheck with CLT without invoking this macro; no runtime/view-update test |
| `StateAliasProbe.swift` — `typealias WrapperState<Value> = SwiftUI.State<Value>`, then `@WrapperState` | Exit 0; no output | A legitimate property-wrapper spelling, including a mutating Button action, typechecks |
| `StateShadowProbe.swift` — local typealias also named `State` | Exit 1 | Keeping the ambiguous spelling does not solve the macro selection |

Exact per-probe commands, output and exits: `audit/evidence/toolchain-probes.json` and `toolchain-probes-readable.log`. No plugin extraction, compiler injection, SDK patch or installed-app modification was used. The alias has not been applied to the droplet or SDK. Replacing all affected state declarations would still leave `@Entry` and other SDK checks to solve; this audit does not recommend maintaining a patched vendor SDK.

## 3. Prebuilt module alternative and historical evidence

Command:

```sh
ls -la /Applications/Droppy.app/Contents/Frameworks/DroppyKit.framework/Versions/A
```

Actual entries: `DroppyKit`, `Resources`, `_CodeSignature`; no `Modules` directory. Therefore that installed framework alone is not an immediately usable Swift import surface.

**INFERRED:** a vendor-supplied or reproducibly cloud-built resilient framework with `.swiftinterface` files could avoid locally rebuilding DroppyKit's source. **UNTESTED:** compatible prebuilt module acquisition, import with this CLT/SDK, ABI matching with the installed host, final linking and host loading. A prebuilt SDK would also not automatically resolve this droplet's own `@State` spelling on the current SDK. No binary plugin or private module was extracted.

Existing research-local build metadata was inspected and preserved:

```text
.build/droplet/kit-arm64/workspace-state.json:
  version 7; dependencies [], prebuilts [], artifacts []
.../ea1c1cc129e3aa5039850b123ecf7288.xcbuilddata/target-graph.txt:
  Target dependency graph (1 target)
  Target 'DroppyKit' in project 'DroppyKit' (no dependencies)
```

This corroborates a previous SDK build attempt, not a completed droplet. File paths, content and SHA-256 hashes are retained in `audit/evidence/toolchain-inspection.json`. The historical successful cloud log cited by Report 22 was not available within the authorized research boundary and was **not inspected**. Its claimed toolchain, provenance and successful artifact remain **UNTESTED** here. No unrelated build artifact was reused.

## 4. What the existing droplet actually does

**VERIFIED by source inspection:** `Sources/BlipResearch/BlipResearchDroplet.swift:25–33` initializes a hardcoded Pixel device name, connected/transfer flags, 65% completion and `48.5 Mbps`. These are mock values. The settings toggle only changes an in-memory `@Published` field; the destination is a hardcoded string; Browse is disabled. It neither reads nor changes Blip settings.

The apparent file-drop area is a drawing. There is no `.onDrop`/`.dropDestination` callback, recipient discovery, Blip integration, transport, incoming watcher or real progress source. The harness would render this same mock object. No screenshots or loader results were obtained. Source was preserved rather than converted into an unproved production integration.

Direct checks against the pinned SDK confirm that `ShelfWidgetContext.isCompact` exists at `Capabilities/ShelfWidgetProviding.swift:267`, `DroppySpacing.xsm` at `DesignSystem/DroppyTokens.swift:16`, and the settings/widget factory signatures match. These particular names are not demonstrated compile errors. Compilation may still reveal other errors after the SDK macro issue is removed.

Static validator command from the package directory:

```sh
../../audit/vendor/droppykit/Scripts/validate-droplet.sh --no-submission
```

Actual exit: **0**. Relevant output:

```text
Manifest
  ✓ droplet.json, icon and creator avatar
Bundle
  – not built yet; run build-droplet.sh to check linkage and architectures
```

Evidence: `audit/evidence/droplet-static-validation.json`. The validator's trailing `Ready to submit.` is generic script text; neither a build nor a Store-readiness conclusion follows from it. No submission was attempted. The existing `VStack` settings content and decorative drop target also need a design review before any real product use.

## 5. Concrete manual build files

Prepared locally:

- `.github/workflows/blip-research-droplet.yml` — `workflow_dispatch` only, `contents: read`, no push/PR/scheduled trigger, pinned action commits, no signing/install/submission step.
- `cloud-build/build-droplet-ci.sh` — refuses local execution, allowlists copied package inputs, obtains fresh official SDK tag v1.20.1 and verifies its exact commit, builds a universal `.droplet` with the official script, runs non-submission validation, records toolchain/linkage/architecture/checksum evidence, archives the result.
- `blip-research-droplet/blip-research/Package.swift` and `Package.resolved` — exact SDK version and revision.

The workflow uses `macos-26` and sets `DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer`; it fails if that preinstalled toolchain is absent. It does not download Xcode. The official runner image inventory currently lists that version/path and macOS 26 SDK 26.2 for Xcode 26.3. This is evidence of runner availability, not a completed build: [official runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md). Pinning the Xcode path reduces silent drift; the hosted image itself remains mutable and availability can change.

The SDK's official build script recompiles its resilient framework with `-enable-library-evolution`/`-emit-module-interface`, compiles the droplet, links its own objects against `@rpath/DroppyKit.framework/Versions/A/DroppyKit`, assembles the `.droplet` and runs linkage/API validation. This avoids shipping a second static SDK copy, as explained in the inspected script and [official package integration guide](https://getdroppy.app/docs/droppykit/add-spm).

Downloadable output, if a future approved run succeeds:

```text
BlipResearch-droplet-<run_id>/BlipResearch.droplet.tar.gz
BlipResearch-build-evidence-<run_id>/
  toolchain.txt, sdk-commit.txt, sdk-fetch.log,
  build.log, validation.log, architectures.txt, linkage.txt, SHA256SUMS.txt
```

The tar preserves executable bits/symlinks through artifact storage; raw artifact uploads do not preserve original Unix permissions. Failure still uploads available build evidence. Retention is 14 days. See [upload-artifact's permission guidance](https://github.com/actions/upload-artifact#permission-loss).

No runner renders the harness or loads this library into Droppy. A downloaded artifact would still be an untested research mock and requires approval before installation/loading. Build success proves packaging and static checks only.

## 6. Local verification and reproducibility limits

Executed:

```sh
bash -n cloud-build/build-droplet-ci.sh
# exit 0; no output
bash cloud-build/build-droplet-ci.sh
# exit 2: error: CI-only build; this script does not run on the local Mac.
ruby -e 'require "yaml"; x=YAML.load_file(".github/workflows/blip-research-droplet.yml"); abort "unexpected trigger" unless x.fetch("on").keys == ["workflow_dispatch"]; puts "YAML parsed; manual workflow_dispatch only"'
# exit 0: YAML parsed; manual workflow_dispatch only
```

Evidence: `audit/evidence/cloud-workflow-syntax.json` and `toolchain-inspection.json`. These are syntax/local-safety checks. They are not GitHub's workflow validation or compilation. SDK version resolution succeeded independently. The GitHub action v4 refs were checked read-only with `git ls-remote` and locked to:

```text
actions/checkout: 11d5960a326750d5838078e36cf38b85af677262
actions/upload-artifact: ea165f8d65b6e75b540449e92b4886f43607fa02
```

`git rev-parse --show-toplevel` in the research directory reports `fatal: not a git repository`. No Git repository was initialized and no remote was selected. The workflow assumes a future approved repository has the research root layout. Do not upload the entire research tree: the build needs only the workflow, script, package manifest/lockfile, sources, placeholder icon and creator asset. Reports, telemetry, compiled caches and unrelated files are unnecessary.

After explicit approval to make GitHub changes, the next bounded procedure is to place those allowlisted files in a selected repository's default branch and run its manual workflow. GitHub requires the manual workflow to exist on the default branch: [official workflow_dispatch rules](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch). Repository visibility, Actions entitlement/minutes, runner availability and upstream GitLab availability remain external dependencies. No existing credentials were read to assess them.

The successful-run acceptance criterion is a downloadable archive plus recorded SDK/toolchain identity, a universal binary, expected framework linkage and passing API/manifest checks. Runtime visual correctness, compatibility with the installed Droppy, and actual Blip integration each require separate evidence and approval boundaries.
