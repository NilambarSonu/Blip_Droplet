# Blip Droplet for Droppy

Native macOS shelf extension for Droppy that stages and hands off files to official Blip for Android delivery.

## Architecture

Blip Droplet is built with the official DroppyKit SDK (v1.20.1 / ABI 1) using SwiftUI and native AppKit integration:

- **Isolated File Staging:** Native drag-and-drop zone with upfront 500 MB quota enforcement, APFS Copy-on-Write clone staging, and streaming SHA-256 calculation.
- **Partitioned Retention:** Staged files are isolated into `pending/` and `handed_off/` partitions to prevent premature deletion while transfers are in flight.
- **macOS Services Integration:** Coordinates with official Blip via the verified macOS Services boundary.
- **Design Tokens:** Strict adherence to Droppy's notch and shelf design language (Liquid Glass controls, adaptive text, squircle geometry).

## Repository Structure

- `blip-droplet/`: Droplet Swift package (manifest, sources, assets, icon, tests).
- `cloud-build/`: CI build scripts for universal macOS bundle assembly.
- `.github/workflows/`: Automated GitHub Actions cloud build pipeline.

## Building with GitHub Actions

The droplet is built in the cloud on macOS runners with full Xcode:

```bash
# Manual workflow trigger
gh workflow run blip-droplet.yml
```

The resulting `Blip.droplet.tar.gz` bundle artifact is downloadable from GitHub Actions run artifacts.

## License

MIT License. See [blip-droplet/LICENSE](blip-droplet/LICENSE) for details.
