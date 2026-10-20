# Blip Droplet for Droppy

Native macOS shelf extension for Droppy that stages and hands off files to official Blip for Android delivery.

## Architecture

Blip Droplet is built with the official DroppyKit SDK (v1.20.1 / ABI 1) using SwiftUI and native AppKit integration:

- **Native Floating Panel:** Dedicated AppKit `NSPanel` anchored beneath the Droppy notch using `DroppyPanelActivation`, with native traffic lights (Close, Miniaturize/Hide, Zoom) and titlebar dragging.
- **Isolated File Staging:** Native drag-and-drop zone and native file picker (`NSOpenPanel`) with upfront 500 MB quota enforcement, APFS Copy-on-Write clone staging, and streaming SHA-256 calculation.
- **Position Persistence:** Remembers panel coordinates across launches, clamps to visible screen bounds, and gracefully handles multi-monitor topology changes.
- **macOS Services Integration:** Coordinates with official Blip via the verified macOS Services boundary.
- **Design Tokens:** Strict adherence to Droppy's notch and shelf design language (dark opaque material, Liquid Glass controls, adaptive text, continuous squircle geometry).

## Repository Structure

- `blip-droplet/`: Droplet Swift package (manifest, sources, assets, icon, tests).
- `cloud-build/`: CI build scripts for universal macOS bundle assembly.
- `.github/workflows/`: Automated GitHub Actions cloud build pipeline.
- `reports/`: Complete archive of all 62 research, reverse-engineering, architecture, and implementation reports ([Index & Table of Contents](reports/README.md)).

## Research & Implementation Reports

The complete development trajectory and reverse-engineering research is documented across 62 formal reports in [`reports/`](reports/):

- **Phase 1:** Blip Architecture, Reverse Engineering, Static Analysis & Feasibility (Reports 01–19)
- **Phase 2A:** Headless Feasibility & Protocol Boundaries (Reports 20–23)
- **Phase 2B:** CLI Automation, Services Handoff & Discovery (Reports 24–35)
- **Phase 2C:** DroppyKit Integration & Native Bridge (Reports 36–40)
- **Phase 3A–3C:** Production Droplet, Pre-Build Audit & Cloud Pipeline (Reports 41–48)
- **Phase 3D:** Native Floating Send Panel & Host Staging (Reports 49–52)
- **Independent Engine Research:** Clean-Room Protocol & Engine Design (Reports 53–60)
- **Phase 3E:** Native macOS Window Controls & Draggable Panel (Reports 61–62)

See [`reports/README.md`](reports/README.md) for full descriptions and links to all reports.

## Building with GitHub Actions

The droplet is built in the cloud on macOS runners with full Xcode:

```bash
# Manual workflow trigger
gh workflow run blip-droplet.yml
```

The resulting `Blip.droplet.tar.gz` bundle artifact is downloadable from GitHub Actions run artifacts.

## License

MIT License. See [blip-droplet/LICENSE](blip-droplet/LICENSE) for details.
