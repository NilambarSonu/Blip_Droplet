# Changelog

All notable changes to the Blip droplet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-19

### Added
- Native Droppy shelf widget supporting both solo (420pt) and compact paired (210pt) compositions.
- Real SwiftUI file-drop engine utilizing coordinated file reading (`NSFileCoordinator`) and atomic temporary staging.
- Security-scoped access handling and automatic disposal of ephemeral provider representations.
- Rejection of symlinks, directories, unsupported items, and duplicate drops.
- Isolated macOS Services adapter for official Blip integration (compiled out in Phase 3A safety build).
- Verified bounded staging storage with automatic pruning of stale files.
