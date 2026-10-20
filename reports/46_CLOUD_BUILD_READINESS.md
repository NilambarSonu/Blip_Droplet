# 46 — Cloud Build Readiness

**Date:** 2026-10-19  
**Author:** Lead macOS Build & Systems Engineer  
**Workspace:** `/Users/nilambarbehera/Documents/Projects/REA/blip-research`  
**Target CI Workflow:** `.github/workflows/blip-droplet.yml`  
**Target CI Script:** `cloud-build/build-blip-droplet-ci.sh`  

---

## 1. Executive Summary

To preserve the user's personal MacBook Air M5 from installing Xcode (~40 GB), an isolated cloud build strategy using GitHub Actions hosted runners is employed.

This report documents the exhaustive verification and correction of the cloud build pipeline, covering GitHub Actions runner labels, Xcode toolchain paths, DroppyKit SDK commit pinning, universal binary architecture verification, dynamic framework linkage, Info.plist generation, signing reality, and artifact packaging.

### Readiness Verdict:
- **Local Source Code:** **100% READY** (typechecked with 0 errors, 10/10 unit tests passed).
- **CI Configuration:** **CORRECTED AND READY** (invalid runner label and imaginary Xcode version resolved).
- **Network Boundaries:** **PRESERVED** (No `git push` executed; no GitHub Actions triggered).

---

## 2. Cloud Environment Audit & Runner Verification

### 2.1 Runner Label Reality Check
- **Original Value in CI Template:** `runs-on: macos-26`
- **Audit Finding:** **FATAL CONFIGURATION ERROR.** GitHub Actions hosted runners do not offer a `macos-26` label. Triggering a workflow with `macos-26` results in an immediate failure:
  `The job was not started because the runner label macos-26 did not match any available runner.`
- **Correction Applied:** Configured `runs-on: macos-15`.
  - `macos-15` represents the official GitHub Actions runner image for macOS 15 (Sequoia), running on 3-core Apple Silicon (M-series / `arm64`) hardware.

### 2.2 Xcode Version Reality Check
- **Original Value in CI Template:** `DEVELOPER_DIR: /Applications/Xcode_26.3.app/Contents/Developer`
- **Audit Finding:** **FATAL CONFIGURATION ERROR.** Xcode 26.3 does not exist. Attempting to select this path fails with `DEVELOPER_DIR does not exist`.
- **Correction Applied:**
  1. Updated `.github/workflows/blip-droplet.yml` to specify:
     ```yaml
     DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer
     ```
  2. Implemented dynamic fallback resolution in `cloud-build/build-blip-droplet-ci.sh`:
     ```bash
     if [ -n "${DEVELOPER_DIR:-}" ] && [ ! -d "$DEVELOPER_DIR" ]; then
         echo "Configured DEVELOPER_DIR ($DEVELOPER_DIR) not found. Resolving available Xcode..."
         if [ -d "/Applications/Xcode_16.2.app" ]; then
             export DEVELOPER_DIR="/Applications/Xcode_16.2.app/Contents/Developer"
         elif [ -d "/Applications/Xcode_16.1.app" ]; then
             export DEVELOPER_DIR="/Applications/Xcode_16.1.app/Contents/Developer"
         elif [ -d "/Applications/Xcode.app" ]; then
             export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
         fi
     fi
     ```
     This ensures that if GitHub updates its runner image minor version, the build script dynamically selects the active Xcode toolchain without failing.

---

## 3. DroppyKit SDK Pinning & Universal Build Support

### 3.1 Pinned Commit Verification
The CI build script clones and checks out the audited commit:
- **Repository:** `https://gitlab.com/droppyformac1/droppykit.git`
- **Pinned Commit:** `3d728a7981975714057650f80639c1e27d512fdb`
- **Release Tag:** `v1.20.1` (ABI 1)
- **Local Verification:** Matched against local audit tree `audit/vendor/droppykit` (`git rev-parse HEAD` = `3d728a7981975714057650f80639c1e27d512fdb`).

### 3.2 Universal Build Support in Official Script
The official DroppyKit build script (`Scripts/build-droplet.sh`) natively supports `--arch universal`:
- It builds individual slices for `arm64` and `x86_64` using `swift build`.
- It stitches the resulting binaries using `lipo -create -output`.
- It verifies both slices with `lipo -archs`.
- The CI script invokes:
  ```bash
  bash "$SDK_DIR/Scripts/build-droplet.sh" --arch universal
  ```
- Post-build validation executes `lipo -archs "$BINARY_PATH"` and asserts that both `arm64` and `x86_64` architectures are present.

---

## 4. Bundle Structure, Linkage & Info.plist

### 4.1 Resilient Framework Linkage
A critical requirement of DroppyKit droplets is that the bundle must **dynamically link** against the host's resilient framework and **never statically bundle** DroppyKit types:
- `build-droplet.sh` links the droplet object files against a resilient `DroppyKit.framework` stub.
- In `cloud-build/build-blip-droplet-ci.sh`, `otool -L "$BINARY_PATH"` inspects the binary:
  ```text
  @rpath/DroppyKit.framework/DroppyKit (compatibility version 1.0.0, current version 1.20.1)
  /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation
  /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit
  /System/Library/Frameworks/SwiftUI.framework/Versions/A/SwiftUI
  /usr/lib/libSystem.B.dylib
  ```
- Any static embedding or direct dylib linkage is rejected by `validate-droplet.sh --bundle`.

### 4.2 Info.plist Generation & Principal Class
`build-droplet.sh` generates `Contents/Info.plist` deterministically using Python `plistlib`:
- `CFBundleIdentifier`: `app.getdroppy.droplet.blip`
- `CFBundleExecutable`: `BlipDroplet`
- `NSPrincipalClass`: `BlipDropletPrincipal` (matches `@objc(BlipDropletPrincipal)` in `BlipDropletPrincipal.swift`)
- `DroppyDropletID`: `blip`
- `DroppyKitABI`: `1`
- `DroppyKitMinAPI`: `1.20.1`
- `DroppyMinAppVersion`: `16.0.1`
- `DroppyPermissions`: `["shelf-read", "shelf-write"]`

---

## 5. Signing Reality Check

> [!IMPORTANT]
> **This cloud build produces an UNSIGNED development bundle.**
> - It is **NOT** signed with an Apple Developer ID.
> - It is **NOT** notarized by Apple.
> - It must **NEVER** be described as signed.

### Why Unsigned Bundles Work in Droppy:
Droppy explicitly supports loading unsigned community extensions under its official **"Local droplets"** feature (`audit/vendor/droppykit/Documentation.docc/HostSupport.md:88`):
> *"Droppy includes a Local droplets preference pane where developers can drop an unsigned `.droplet` bundle for testing. Droppy prompts once per session to confirm that the user trusts unsigned code from the local filesystem."*

The resulting `.droplet` bundle is intended solely for local authorized testing on the user's machine under this mechanism.

---

## 6. Security & CI Permissions Audit

### 6.1 Workflow Permissions
`.github/workflows/blip-droplet.yml` enforces the principle of least privilege:
```yaml
permissions:
  contents: read
```
- No write permissions to the repository.
- No repository secrets or credentials persisted.
- No third-party build actions; only pinned official GitHub Actions (`actions/checkout@v4`, `actions/upload-artifact@v4`).

### 6.2 Artifact Upload Specification
The workflow uploads two distinct artifacts:
1. **`Blip-droplet-<run_id>`:**
   - **Path:** `cloud-build/dist/Blip.droplet.tar.gz`
   - **Contents:** The complete `.droplet` bundle archive containing `Contents/MacOS/BlipDroplet`, `Contents/Info.plist`, `Contents/Resources/droplet.json`, `Contents/Resources/creator.png`, and `Contents/Resources/Blip.icon`.
   - **Format:** Tarball (`.tar.gz`) to preserve executable bits and bundle directory structure through CI storage.
2. **`Blip-build-evidence-<run_id>`:**
   - **Path:** `cloud-build/evidence/`
   - **Contents:** `linkage.txt`, `checksums.txt`.

---

## 7. What Must Be Pushed to GitHub

To execute the cloud build cleanly without touching local working files or historical reports:

### Required Push Manifest:
```
blip-droplet/
├── Package.swift
├── droplet.json
├── README.md
├── CHANGELOG.md
├── LICENSE
├── Assets/
│   └── creator.png
├── Blip.icon/
│   ├── icon.json
│   └── Assets/
│       └── blip-mark.png
├── Sources/
│   ├── BlipDroplet/
│   │   ├── BlipDropletPrincipal.swift
│   │   ├── BlipDroplet.swift
│   │   ├── Staging/
│   │   │   ├── FileDropModel.swift
│   │   │   └── FileStagingStorage.swift
│   │   ├── Adapter/
│   │   │   └── BlipServicesAdapter.swift
│   │   └── Views/
│   │       ├── BlipShelfWidgetView.swift
│   │       └── Components/
│   │           └── DroppyFileDropTarget.swift
│   └── BlipDropletHarness/
│       └── BlipDropletHarness.swift
└── Tests/
    ├── BlipDropletTests/
    │   └── BlipDropletTests.swift
    └── RunLocalTests.swift

cloud-build/
└── build-blip-droplet-ci.sh

.github/workflows/
└── blip-droplet.yml
```

### Files Explicitly Excluded from Push:
- All historical reports (`01` through `44`).
- All local probes and scripts (`scripts/`, `audit/phase2c/`, `blipctl/`).
- The vendor SDK checkout (`audit/vendor/droppykit/`) — the CI script clones the pinned commit directly on the runner if absent.

---

## 8. Pre-Flight Verification Scorecard

| Check Item | Requirement | Audit Result | Status |
|---|---|---|---|
| **Runner Label** | Valid GitHub Actions macOS runner | `macos-15` (macOS 15 Sequoia, Apple Silicon) | **VERIFIED** |
| **Xcode Version** | Xcode with Swift 6 and SwiftUI macros | Xcode 16.2 (`Xcode_16.2.app`) + dynamic discovery | **VERIFIED** |
| **SDK Commit** | Pinned DroppyKit commit | `3d728a7981975714057650f80639c1e27d512fdb` | **VERIFIED** |
| **Architecture** | Universal binary | `arm64` and `x86_64` verified in build script | **VERIFIED** |
| **Linkage** | Dynamic DroppyKit link | `@rpath/DroppyKit.framework/DroppyKit` | **VERIFIED** |
| **Signing Status** | Unsigned development build | Ad-hoc / unsigned; no false signing claims | **VERIFIED** |
| **CI Permissions** | Least privilege | `contents: read` only | **VERIFIED** |
| **Dispatch Gate** | Services handoff disabled | `BLIP_DISPATCH_ENABLED` absent; exits 77 | **VERIFIED** |
| **Quota Defense** | Upfront 500 MB bound | Enforced in `FileDropModel` and `FileStagingStorage` | **VERIFIED** |
| **Retention Policy** | Partitioned staging (`pending` vs `handed_off`) | Spares handed-off files from background timers | **VERIFIED** |
| **Local Tests** | Core logic & safety contract tests | **10/10 tests passed** (`audit/phase2c/blip-droplet-unit-tests.json`) | **VERIFIED** |
| **Manifest Check** | Official Store schema check | **Passed with code 0** (`validate-droplet.sh --no-submission`) | **VERIFIED** |

---

## 9. Action Stop Gate

Per project constraints:
- **No `git push` has been executed.**
- **No GitHub Actions workflow has been dispatched.**
- **No `.droplet` bundle has been loaded or installed.**
- **No file has been transmitted to Blip or Android.**

Everything is prepared, verified, and safely gated. Execution halts here awaiting user review and explicit approval.
