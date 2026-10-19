# Blip Droplet for Droppy

A native shelf extension for [Droppy](https://getdroppy.app) that provides local file staging and macOS Services handoff to official Blip for fast, reliable delivery to Android.

## Features

- **Native Droppy Shelf Widget:** Rendered cleanly below the macOS notch in both solo (420pt) and compact paired (210pt) layouts.
- **Genuine File-Drop Engine:** Accepts dropped files via standard SwiftUI drag-and-drop, coordinates reading atomically, and validates file attributes.
- **Security & Integrity:** Automatically rejects symlinks, directories, and duplicate drops.
- **Services Handoff:** Bridges to the official Blip application via macOS Services (`NSPerformService`), triggering the official recipient picker.
- **Safety First:** In Phase 3A, live dispatch is safely compiled out to prevent premature or accidental network transmission.

## Architecture

- **Extension Model:** Built with the official DroppyKit SDK v1.20.1 (ABI 1).
- **Execution:** Runs in-process on the main actor within Droppy's extension host.
- **File Access:** Ephemeral `NSItemProvider` representations are coordinated and staged atomically in `~/Library/Application Support/Droppy/Droplets/blip/staging/`.

## Development & Testing

```bash
# Run unit & contract tests
swift test

# Validate droplet manifest & assets
droppykit validate --no-submission
```

## Licence

MIT License. See [LICENSE](LICENSE) for details.
