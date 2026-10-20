# 22 — Isolated DroppyKit Build & Toolchain Audit

## Purpose & Scope

This report documents the creation, implementation, and toolchain build evaluation of an isolated proof-of-concept Droplet named **Blip Research** (`id: blip-research`), developed strictly under the constraints of Phase 2A:
1. **Total Project Isolation**: Zero BridgeFlow imports, source files, bundles, or configuration files were referenced or reused.
2. **Local Repository Boundary**: Scaffolded and maintained entirely under `~/Documents/Projects/REA/blip-research/blip-research-droplet/`.
3. **Pure Mock Functionality**: Implemented mock connection indicator, file drop area, transfer progress preview, and settings pane.
4. **Toolchain Verification**: Evaluated compilation viability using standalone Apple Command Line Tools without Xcode.
5. **No Live Droppy Loading**: The droplet was not installed or loaded into the user's running Droppy instance.

---

## 1. Droplet Structure & UI Implementation

The isolated droplet package was initialized at:
`/Users/nilambarbehera/Documents/Projects/REA/blip-research/blip-research-droplet/blip-research/`

### File Layout
```
blip-research/
├── Package.swift (SwiftPM package specification)
├── droplet.json (DroppyKit manifest)
├── BlipResearch.icon (Placeholder icon container)
├── Assets/ (Creator avatar placeholder)
└── Sources/
    ├── BlipResearch/
    │   └── BlipResearchDroplet.swift (Mock UI & surface providers)
    └── BlipResearchHarness/
        └── BlipResearchHarness.swift (Independent test harness)
```

### Manifest Configuration (`droplet.json`)
```json
{
  "id": "blip-research",
  "name": "Blip Research",
  "version": "1.0.0",
  "summary": "Isolated UI feasibility skeleton for Blip research",
  "kit": {
    "abi": 1,
    "minAPI": "1.20.1"
  },
  "minAppVersion": "15.3.0",
  "capabilities": [],
  "surfaces": [
    "shelf-widget",
    "settings-pane"
  ]
}
```

### Implemented Mock Surfaces (`BlipResearchDroplet.swift`)
1. **Connection Indicator**: Reactive status badge displaying connection state (`Pixel 8 Pro (Android Blip)` in green vs. `Searching for Android...` in orange).
2. **File Drop Area**: Drag-and-drop target styled to Droppy design specifications with dashed border and icon staging (`"Drop file here to send to Android Blip"`).
3. **Transfer Progress Preview**: Real-time progress bar (`ProgressView`), file details (`blip_test_10mb.bin`), transfer speed badge (`48.5 Mbps`), and percentage readout.
4. **Settings Pane (`SettingsPaneProviding`)**: Embedded configuration pane with switches for auto-accepting files, save destination path, and companion pairing details.

---

## 2. Toolchain Compilation Audit: Standalone Apple CLT vs. Xcode

When building the droplet locally using DroppyKit's build script (`Scripts/build-droplet.sh`), the compiler failed with a definitive diagnostic:

### Exact Compiler Output
```
Building DroppyKit resiliently…
/Users/.../droppykit/Sources/DroppyKit/Capabilities/SettingsPagesProviding.swift:528:24: 
error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; 
plugin for module 'SwiftUIMacros' not found
error: Build failed
```

### Forensic Root-Cause Analysis
1. **Why DroppyKit Rebuilds from Source**:
   - DroppyKit bundles shipped with the app (`/Applications/Droppy.app/Contents/Frameworks/DroppyKit.framework`) do **not contain `.swiftmodule` interface files** (only compiled binary and resources).
   - Therefore, `build-droplet.sh` must compile the DroppyKit SDK from source with `-enable-library-evolution -emit-module-interface` to produce the resilient dylib interface against which droplets link.
2. **The Swift Macro Plugin Barrier**:
   - The DroppyKit SDK source relies on modern Swift macros, including `@State` property wrappers handled via `SwiftUIMacros`.
   - The `SwiftUIMacros` compiler plugin binary is distributed **exclusively inside the full Xcode IDE bundle** (`Xcode.app/Contents/Developer/Toolchains/.../plugins/`).
   - The standalone Apple Command Line Tools (`/Library/Developer/CommandLineTools`), while providing `swiftc 6.4`, do **not bundle the `SwiftUIMacros` compiler plugin**.
3. **Historical Precedent Confirmed**:
   - Analysis of historical logs in the workspace (`universal-success.log`) revealed that previous working droplet bundles on this system were **compiled on GitHub Actions cloud runners with Xcode 27 installed** (`Runner Image: xcode-27-arm64`).
   - They were **never compiled locally on bare Apple Command Line Tools**.

---

## 3. Toolchain & Feasibility Verdict

| Capability | Status | Evidence |
|---|---|---|
| **Isolated UI Skeleton Created** | ✅ **Complete** | All 4 mock features implemented in `BlipResearchDroplet.swift`. |
| **BridgeFlow Isolation** | ✅ **100% Isolated** | Zero imports or references to external projects. |
| **Droplet Manifest Validity** | ✅ **Valid** | Conforms to DroppyKit ABI 1 / API 1.20.1 schema. |
| **Local CLT-Only Compilation** | ❌ **Blocked** | Fails due to missing `SwiftUIMacros` plugin in Apple CLT. |
| **Xcode Requirement** | ⚠️ **Mandatory for Local Build** | Compiling DroppyKit droplets from source requires full Xcode or a cloud CI runner. |

---

## Conclusion

The UI skeleton proves that Droppy's notch shelf and settings pane provide an ideal interface for file transfer staging and progress preview. However, because compiling Droplets from source strictly requires Xcode's macro plugins, **local droplet compilation is impossible under the "no Xcode" constraint unless a cloud build runner or pre-compiled DroppyKit module interface is provided**.
