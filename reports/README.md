# Blip Droplet & Engine Research Reports Archive

This directory contains the complete archive of all **62 research, architecture, audit, and implementation reports** produced during the Blip macOS Droppy Droplet development and independent engine investigation.

---

## Table of Contents

### Phase 1: Exploration, Reverse Engineering & Feasibility Baseline
- [01_SYSTEM_AND_APP_INVENTORY.md](01_SYSTEM_AND_APP_INVENTORY.md) — Host environment, installed Blip.app inspection, and baseline framework inventory.
- [02_REA_SETUP_AND_TOOL_VALIDATION.md](02_REA_SETUP_AND_TOOL_VALIDATION.md) — Reverse-engineering environment setup and toolchain validation.
- [03_STATIC_BINARY_ANALYSIS.md](03_STATIC_BINARY_ANALYSIS.md) — Static analysis of official Blip Mach-O binaries, frameworks, and symbols.
- [04_APPLICATION_ARCHITECTURE.md](04_APPLICATION_ARCHITECTURE.md) — Decomposition of official Blip macOS application architecture.
- [05_NETWORK_AND_TRANSFER_BEHAVIOR.md](05_NETWORK_AND_TRANSFER_BEHAVIOR.md) — Wireshark/tcpdump network capture of LAN transfer protocols and TLS behavior.
- [06_ANDROID_INTEROPERABILITY.md](06_ANDROID_INTEROPERABILITY.md) — Direct LAN transfer validation between macOS and official Android client.
- [07_RESOURCE_AND_PERFORMANCE_BASELINE.md](07_RESOURCE_AND_PERFORMANCE_BASELINE.md) — Memory, CPU, and thread usage profiling of official client.
- [08_DROPPY_INTEGRATION_FEASIBILITY.md](08_DROPPY_INTEGRATION_FEASIBILITY.md) — Initial assessment of hosting Blip within Droppy's notch interface.
- [09_LIGHTWEIGHT_REPLACEMENT_ARCHITECTURES.md](09_LIGHTWEIGHT_REPLACEMENT_ARCHITECTURES.md) — Architectural patterns for headless and widget replacements.
- [10_FEASIBILITY_VERDICT.md](10_FEASIBILITY_VERDICT.md) — Phase 1 feasibility conclusions and risk assessment.
- [11_EVIDENCE_AND_CLAIMS_AUDIT.md](11_EVIDENCE_AND_CLAIMS_AUDIT.md) — Verification of empirical observations against protocol facts.
- [12_NATIVE_ANALYSIS_RESULTS.md](12_NATIVE_ANALYSIS_RESULTS.md) — Disassembly and decompilation results of BlipKit framework.
- [13_LIVE_TRANSFER_TEST_RESULTS.md](13_LIVE_TRANSFER_TEST_RESULTS.md) — Multi-file LAN throughput measurements.
- [14_ANDROID_COMPATIBILITY_DECISION.md](14_ANDROID_COMPATIBILITY_DECISION.md) — Evaluation of Android client compatibility requirements.
- [15_DROPPY_POC_VALIDATION.md](15_DROPPY_POC_VALIDATION.md) — Proof of concept validation inside Droppy container.
- [16_PHASE_2_GO_NO_GO.md](16_PHASE_2_GO_NO_GO.md) — Formal Go/No-Go decision for Phase 2 implementation.
- [17_DROPPY_BUILD_EVIDENCE.md](17_DROPPY_BUILD_EVIDENCE.md) — Empirical evidence of Droppy bundle compilation.
- [18_CONTROLLED_MEMORY_MEASUREMENTS.md](18_CONTROLLED_MEMORY_MEASUREMENTS.md) — Heap allocation and memory pressure tests.
- [19_TRANSFER_TEST_PREPARATION.md](19_TRANSFER_TEST_PREPARATION.md) — Test plan for cross-device automation.

---

### Phase 2A: Headless Feasibility & Protocol Boundaries
- [20_BLIPKIT_HEADLESS_FEASIBILITY.md](20_BLIPKIT_HEADLESS_FEASIBILITY.md) — Investigation into headless BlipKit framework instantiation.
- [21_SUPPORTED_INTEGRATION_OPTIONS.md](21_SUPPORTED_INTEGRATION_OPTIONS.md) — Analysis of supported vs unsupported macOS integration vectors.
- [22_ISOLATED_DROPPY_BUILD_REPORT.md](22_ISOLATED_DROPPY_BUILD_REPORT.md) — Standalone compilation of Droppy widget harness.
- [23_PHASE_2_ARCHITECTURE_DECISION.md](23_PHASE_2_ARCHITECTURE_DECISION.md) — Architecture decision record: supported Services handoff strategy.

---

### Phase 2B: CLI Automation, Services Handoff & Discovery
- [24_CODEX_INDEPENDENT_AUDIT.md](24_CODEX_INDEPENDENT_AUDIT.md) — Independent security and license compliance audit.
- [25_BLIP_OS_INTEGRATION_TESTS.md](25_BLIP_OS_INTEGRATION_TESTS.md) — macOS Services discovery and IPC verification.
- [26_BLIPCTL_IMPLEMENTATION.md](26_BLIPCTL_IMPLEMENTATION.md) — Implementation of `blipctl` command-line utility.
- [27_INCOMING_TRANSFER_OBSERVABILITY.md](27_INCOMING_TRANSFER_OBSERVABILITY.md) — Real-time telemetry monitoring for incoming transfers.
- [28_DROPPY_CLOUD_BUILD_PLAN.md](28_DROPPY_CLOUD_BUILD_PLAN.md) — Cloud CI/CD strategy for remote compilation.
- [29_PHASE_2_MILESTONE_1_VERDICT.md](29_PHASE_2_MILESTONE_1_VERDICT.md) — Milestone 1 sign-off report.
- [30_SERVICES_HANDOFF_LIVE_TEST.md](30_SERVICES_HANDOFF_LIVE_TEST.md) — Validation of `NSPerformService` file transfer handoff to official client.
- [31_INTERACTIVE_ANDROID_DELIVERY_TEST.md](31_INTERACTIVE_ANDROID_DELIVERY_TEST.md) — Real-world delivery to physical Android phone via Services.
- [32_RECIPIENT_AUTOMATION_FEASIBILITY.md](32_RECIPIENT_AUTOMATION_FEASIBILITY.md) — Investigation into automated recipient selection.
- [33_BLIPCTL_INTERACTIVE_SEND_DESIGN.md](33_BLIPCTL_INTERACTIVE_SEND_DESIGN.md) — Architecture of `blipctl send` command.
- [34_DROPPY_INTEGRATION_READINESS.md](34_DROPPY_INTEGRATION_READINESS.md) — DroppyKit integration readiness audit.
- [35_PHASE_2B_DECISION.md](35_PHASE_2B_DECISION.md) — Phase 2B decision record.

---

### Phase 2C: DroppyKit Integration & Native Bridge
- [36_DROPPYKIT_SUPPORTED_BRIDGE_RESEARCH.md](36_DROPPYKIT_SUPPORTED_BRIDGE_RESEARCH.md) — AppKit/SwiftUI boundary analysis within Droppy shelf widgets.
- [37_FILE_DROP_ACCESS_PROOF.md](37_FILE_DROP_ACCESS_PROOF.md) — Proof of file drag-and-drop security access in sandboxed widget.
- [38_SHORTCUTS_RECIPIENT_REVIEW.md](38_SHORTCUTS_RECIPIENT_REVIEW.md) — Review of macOS Shortcuts recipient automation vectors.
- [39_PHASE_2C_IMPLEMENTATION_DECISION.md](39_PHASE_2C_IMPLEMENTATION_DECISION.md) — Decision to move to real `.droplet` bundle creation.
- [40_PHASE_2C_INDEPENDENT_REVIEW.md](40_PHASE_2C_INDEPENDENT_REVIEW.md) — Independent review of Phase 2C findings.

---

### Phase 3A–3C: Production Droplet, Pre-Build Audit & Cloud Pipeline
- [41_BLIP_DROPLET_IMPLEMENTATION.md](41_BLIP_DROPLET_IMPLEMENTATION.md) — Full source implementation of Blip Droplet using official DroppyKit SDK.
- [42_FILE_STAGING_AND_RETENTION.md](42_FILE_STAGING_AND_RETENTION.md) — Secure local file staging, SHA-256 deduplication, and quota retention rules.
- [43_DROPPYKIT_BUILD_VALIDATION.md](43_DROPPYKIT_BUILD_VALIDATION.md) — Verification with official `validate-droplet.sh` tool.
- [44_PHASE_3A_RELEASE_READINESS.md](44_PHASE_3A_RELEASE_READINESS.md) — Release readiness checklist.
- [45_PHASE_3B_SOURCE_AUDIT.md](45_PHASE_3B_SOURCE_AUDIT.md) — Strict pre-build audit (Swift 6 strict concurrency, manifest compliance).
- [46_CLOUD_BUILD_READINESS.md](46_CLOUD_BUILD_READINESS.md) — GitHub Actions cloud-build workflow architecture.
- [47_STAGING_SAFETY_CORRECTIONS.md](47_STAGING_SAFETY_CORRECTIONS.md) — Security fixes for path traversal, symlink resolution, and size quota enforcement.
- [48_GITHUB_CLOUD_BUILD_EXECUTION.md](48_GITHUB_CLOUD_BUILD_EXECUTION.md) — First successful cloud build and universal `.droplet` generation.

---

### Phase 3D: Native Floating Send Panel & Host Staging
- [49_NOTCH_INTERACTION_ROOT_CAUSE.md](49_NOTCH_INTERACTION_ROOT_CAUSE.md) — Analysis of Droppy notch hover dismissal and window lifecycle.
- [50_NATIVE_BLIP_PANEL_IMPLEMENTATION.md](50_NATIVE_BLIP_PANEL_IMPLEMENTATION.md) — Implementation of `NSPanel` floating window anchored beneath notch using `DroppyPanelActivation`.
- [51_FILE_PICKER_AND_DROP_TESTS.md](51_FILE_PICKER_AND_DROP_TESTS.md) — Test suite for native `NSOpenPanel` file picker and drag-and-drop parity.
- [52_PHASE_3D_CLOUD_BUILD_RESULT.md](52_PHASE_3D_CLOUD_BUILD_RESULT.md) — Successful cloud build and physical MacBook validation report.

---

### Independent Engine Clean-Room Research
- [53_INDEPENDENT_ENGINE_RESEARCH_AUDIT.md](53_INDEPENDENT_ENGINE_RESEARCH_AUDIT.md) — Comprehensive audit of engine reverse engineering evidence.
- [54_BLIP_ARCHITECTURE_AND_PROTOCOL_EVIDENCE.md](54_BLIP_ARCHITECTURE_AND_PROTOCOL_EVIDENCE.md) — Protocol mapping: discovery, handshake, control channel, transfer channel.
- [55_DEVICE_DISCOVERY_PAIRING_AND_AUTH_ASSESSMENT.md](55_DEVICE_DISCOVERY_PAIRING_AND_AUTH_ASSESSMENT.md) — Assessment of pairing, mDNS discovery, and TLS auth exchange.
- [56_ANDROID_TO_MAC_RECEIVE_FEASIBILITY.md](56_ANDROID_TO_MAC_RECEIVE_FEASIBILITY.md) — Feasibility of independent incoming transfer listener.
- [57_MAC_TO_ANDROID_SEND_FEASIBILITY.md](57_MAC_TO_ANDROID_SEND_FEASIBILITY.md) — Feasibility of independent outbound sender to Android.
- [58_CLEAN_ROOM_ENGINE_DESIGN.md](58_CLEAN_ROOM_ENGINE_DESIGN.md) — Clean-room specification and architecture for independent engine.
- [59_SECURITY_LEGAL_AND_INTEROPERABILITY_BOUNDARIES.md](59_SECURITY_LEGAL_AND_INTEROPERABILITY_BOUNDARIES.md) — Security and legal boundary guidelines.
- [60_INDEPENDENT_ENGINE_GO_NO_GO_DECISION.md](60_INDEPENDENT_ENGINE_GO_NO_GO_DECISION.md) — Formal Go/No-Go decision for standalone engine.

---

### Phase 3E: Native macOS Window Controls & Draggable Panel
- [61_WINDOW_CONTROLS_AND_DRAG_ARCHITECTURE.md](61_WINDOW_CONTROLS_AND_DRAG_ARCHITECTURE.md) — Architecture of AppKit traffic lights, titlebar dragging, position memory, and opaque dark styling.
- [62_PHASE_3E_CLOUD_BUILD_RESULT.md](62_PHASE_3E_CLOUD_BUILD_RESULT.md) — Phase 3E cloud build delivery, artifact checksums, and verification steps.
