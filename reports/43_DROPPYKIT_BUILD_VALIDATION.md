# 43 — DroppyKit Build Validation

**Date:** 2026-10-19  
**Author:** Lead macOS Build & Systems Engineer  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Target:** `blip-droplet` package build and validation audit

---

## 1. Executive Summary

This report documents the exhaustive local build validation, unit testing, toolchain analysis, and CI workflow preparation for the newly created `blip-droplet` package.

### Results at a Glance:
1. **Manifest & Asset Pre-Validation:** **PASSED 100%**. `validate-droplet.sh --no-submission` completed with code `0`, verifying `droplet.json`, `Blip.icon`, and `Assets/creator.png`.
2. **Local Core & Contract Unit Tests:** **PASSED 8/8 (100%)**. The standalone test harness (`RunLocalTests`) verified state initialization, file staging, duplicate rejection, symlink rejection, directory rejection, cleanup, dispatch compilation gate, and storage pruning with zero failures (`audit/phase2c/blip-droplet-unit-tests.json`).
3. **Local Toolchain Barrier (CLT vs. Xcode):** Attempting to execute `build-droplet.sh` locally with Apple Command Line Tools failed during the resilient compilation of the vendor `DroppyKit` SDK due to the absence of the proprietary `SwiftUIMacros.StateMacro` plugin in standalone CLT.
4. **Reproducible Cloud Build Preparation:** A dedicated CI build script (`cloud-build/build-blip-droplet-ci.sh`) and GitHub Actions workflow (`.github/workflows/blip-droplet.yml`) were prepared, pinning Xcode 26.3 and DroppyKit v1.20.1. Per project constraints, the workflow was **not** pushed or executed.

---

## 2. Local Validation & Test Execution

### 2.1 Manifest & Schema Validation
Executed the official DroppyKit validation script:
```bash
cd blip-droplet
bash ../audit/vendor/droppykit/Scripts/validate-droplet.sh --no-submission
```

**Actual Output:**
```text
Manifest
  ✓ droplet.json, icon and creator avatar
Live activity
  - no Sources to scan
Bundle
  – not built yet; run build-droplet.sh to check linkage and architectures

Ready to submit.
```
- **Exit Code:** `0`
- **Verification:** All manifest fields (id `blip`, category `Files`, summary 42 chars <= 60 limit, permissions, surfaces, icon, creator avatar 256x256, MIT license, GitHub repository) conform strictly to Droppy Store intake rules.

### 2.2 Core Logic & Safety State Unit Testing
Compiled and executed the local unit test suite:
```bash
swiftc -parse-as-library \
  blip-droplet/Sources/BlipDroplet/Staging/FileStagingStorage.swift \
  blip-droplet/Sources/BlipDroplet/Staging/FileDropModel.swift \
  blip-droplet/Sources/BlipDroplet/Adapter/BlipServicesAdapter.swift \
  blip-droplet/Tests/RunLocalTests.swift \
  -o blip-droplet/Tests/RunLocalTests
blip-droplet/Tests/RunLocalTests
```

**Actual Output (`audit/phase2c/blip-droplet-unit-tests.json`):**
```json
{
  "failed" : 0,
  "passed" : 8,
  "results" : [
    {
      "detail" : "Model initializes in .empty state with target flag false",
      "passed" : true,
      "testName" : "Initial Empty State"
    },
    {
      "detail" : "Staged 51 bytes (SHA: a02da8d8…) at FEC676BD_sample_valid.txt",
      "passed" : true,
      "testName" : "Valid File Drop and Staging"
    },
    {
      "detail" : "Correctly rejected re-entrant drop: A file is already staged. Clear it before dropping another.",
      "passed" : true,
      "testName" : "Duplicate Drop Rejection"
    },
    {
      "detail" : "Symlink was safely identified and rejected",
      "passed" : true,
      "testName" : "Symlink Rejection"
    },
    {
      "detail" : "Directory was safely identified and rejected",
      "passed" : true,
      "testName" : "Directory Drop Rejection"
    },
    {
      "detail" : "Staged file removed from disk and state reset to .empty",
      "passed" : true,
      "testName" : "Clear Staging Cleanup"
    },
    {
      "detail" : "isDispatchCompiledIn=false. Handoff safely refused with .dispatchDisabledInPhase3A.",
      "passed" : true,
      "testName" : "Services Adapter Safety Gate"
    },
    {
      "detail" : "FileStagingStorage correctly creates and purges bounded staging entries",
      "passed" : true,
      "testName" : "Staging Storage Pruning"
    }
  ],
  "timestamp" : "2026-10-19T02:05:58Z",
  "total" : 8
}
```

---

## 3. Toolchain Compatibility Analysis

### 3.1 The SwiftUIMacros Toolchain Barrier
When executing `build-droplet.sh` locally:
```bash
bash ../audit/vendor/droppykit/Scripts/build-droplet.sh
```

The build failed during the initial resilient build of DroppyKit:
```text
Building DroppyKit resiliently…
/Users/nilambarbehera/Documents/Projects/REA/blip-research/audit/vendor/droppykit/Sources/DroppyKit/Capabilities/SettingsPagesProviding.swift:528:24: error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found
528 |     @State private var presenter = DropletSettingsToolbarMenuPresenter()
```

### Technical Root Cause:
1. In Swift 6, `@State` is backed by a compiler macro implemented in `libSwiftUIMacros.dylib`.
2. Apple includes `libSwiftUIMacros.dylib` inside the full Xcode app bundle (`Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib`).
3. Apple's standalone Command Line Tools (`/Library/Developer/CommandLineTools`) **omits** this proprietary dylib.
4. Because the vendor SDK source (`DroppyKit`) uses `@State` inside `SettingsPagesProviding.swift` and `DroppyButtonStyles.swift`, compiling DroppyKit resiliently from source requires a full Xcode toolchain.
5. In accordance with user constraints ("I refuse to install full Xcode locally"), local Xcode was not installed.

---

## 4. Prepared CI / Cloud Build Workflow

In accordance with Section 6 of the project instructions, a clean, isolated cloud build configuration was prepared:

### 4.1 CI Script: `cloud-build/build-blip-droplet-ci.sh`
- Pinned Xcode: 26.3 (`DEVELOPER_DIR: /Applications/Xcode_26.3.app/Contents/Developer`).
- Pinned SDK: DroppyKit commit `3d728a7981975714057650f80639c1e27d512fdb`.
- Universal Slices: Builds `arm64` and `x86_64` using `build-droplet.sh --arch universal`.
- Linkage Audit: Checks that the dynamic library links `@rpath/DroppyKit.framework` and emits zero direct-access `…9DroppyKit…vau` symbols.
- Packaging: Bundles `Blip.droplet.tar.gz` and calculates SHA-256 checksums into `cloud-build/evidence/`.

### 4.2 GitHub Actions Workflow: `.github/workflows/blip-droplet.yml`
- Trigger: `workflow_dispatch` (Manual dispatch only).
- Runner: `macos-26`.
- Artifact Upload: Saves `Blip-droplet-${{ github.run_id }}` for 14 days.

### 4.3 Policy Compliance:
- **No Git Push:** The workflow file exists locally only. No `git push` was executed.
- **No Cloud Execution:** The cloud build was not triggered.
- **Truthful Status:** We explicitly record that `Blip.droplet` has **not** yet been built as a compiled Mach-O bundle, pending cloud execution approval.

---

## 5. Build Readiness Matrix

| Gate | Requirement | Status | Verification Evidence |
|---|---|---|---|
| **Manifest Schema** | Valid `droplet.json` conforming to DroppyKit schema | **PASSED** | `validate-droplet.sh` exited 0 |
| **Visual Assets** | 256x256 creator avatar + Icon Composer layers | **PASSED** | IHDR checked; `creator.png` & `Blip.icon` verified |
| **Logic Unit Tests** | 8 core tests covering drop, staging, security, and safety | **PASSED** | `RunLocalTests` passed 8/8 tests |
| **Dispatch Safety** | Services dispatch compiled out in Phase 3A | **PASSED** | `isDispatchCompiledIn = false` verified |
| **Local Compilation** | Core business logic compiles with standalone CLT | **PASSED** | `libBlipCore.dylib` compiled with `swiftc` |
| **Complete Bundle** | Resilient `.droplet` bundle with resilient DroppyKit framework | **PENDING CLOUD BUILD** | Blocked locally by CLT `SwiftUIMacros` gap; CI workflow prepared |
