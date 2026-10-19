#!/bin/bash
#
# build-blip-droplet-ci.sh — Isolated CI build script for Blip Droplet
#
# Pinned to DroppyKit v1.20.1 (commit 3d728a7981975714057650f80639c1e27d512fdb).
# Runs in an isolated macOS runner with full Xcode.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$WORKSPACE_ROOT/blip-droplet"
DIST_DIR="$WORKSPACE_ROOT/cloud-build/dist"
EVIDENCE_DIR="$WORKSPACE_ROOT/cloud-build/evidence"
SDK_DIR="$WORKSPACE_ROOT/.sdk/droppykit"

mkdir -p "$DIST_DIR" "$EVIDENCE_DIR" "$WORKSPACE_ROOT/.sdk"

echo "=== 1. Toolchain & Environment Verification ==="
echo "Swift: $(swift --version | head -1)"
echo "Xcode: $(xcodebuild -version 2>/dev/null | head -1 || echo 'Command Line Tools')"
echo "DEVELOPER_DIR: ${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || echo unset)}"

# Verify / clone pinned DroppyKit SDK
PINNED_COMMIT="3d728a7981975714057650f80639c1e27d512fdb"
if [ ! -d "$SDK_DIR" ]; then
    echo "Cloning pinned DroppyKit SDK v1.20.1..."
    git clone https://gitlab.com/droppyformac1/droppykit.git "$SDK_DIR"
    git -C "$SDK_DIR" checkout "$PINNED_COMMIT"
fi

ACTUAL_COMMIT="$(git -C "$SDK_DIR" rev-parse HEAD)"
echo "DroppyKit SDK commit: $ACTUAL_COMMIT"
if [ "$ACTUAL_COMMIT" != "$PINNED_COMMIT" ]; then
    echo "error: DroppyKit SDK commit mismatch (got $ACTUAL_COMMIT, expected $PINNED_COMMIT)" >&2
    exit 1
fi
echo "$ACTUAL_COMMIT" > "$EVIDENCE_DIR/sdk_commit.txt"

echo "=== 2. Manifest & Schema Pre-Validation ==="
cd "$PACKAGE_DIR"
bash "$SDK_DIR/Scripts/validate-droplet.sh" --no-submission | tee "$EVIDENCE_DIR/manifest_validation.txt"

echo "=== 3. Building Universal .droplet Bundle ==="
# Un-silence build-droplet.sh so compiler and linker diagnostics appear in CI
sed -i '' 's/>\/dev\/null//g' "$SDK_DIR/Scripts/build-droplet.sh"
bash "$SDK_DIR/Scripts/build-droplet.sh" --arch universal 2>&1 | tee "$EVIDENCE_DIR/build.log"

BUNDLE_PATH="$(find "$PACKAGE_DIR/.build" -maxdepth 1 -name '*.droplet' | head -1)"
if [ -z "$BUNDLE_PATH" ] || [ ! -d "$BUNDLE_PATH" ]; then
    echo "error: No .droplet bundle produced in $PACKAGE_DIR/.build" >&2
    exit 1
fi
echo "Produced bundle: $BUNDLE_PATH"

echo "=== 4. Post-Build Bundle Validation ==="
bash "$SDK_DIR/Scripts/validate-droplet.sh" --bundle "$BUNDLE_PATH" --no-submission | tee "$EVIDENCE_DIR/bundle_validation.txt"

echo "=== 5. Architecture & Linkage Inspection ==="
BINARY_PATH="$(find "$BUNDLE_PATH/Contents/MacOS" -type f -perm +111 | head -1)"
echo "Binary: $BINARY_PATH"

ARCHS="$(lipo -archs "$BINARY_PATH")"
echo "Architectures: $ARCHS"
echo "$ARCHS" > "$EVIDENCE_DIR/architectures.txt"
case "$ARCHS" in
    *arm64*x86_64*|*x86_64*arm64*) echo "✓ Universal binary confirmed ($ARCHS)" ;;
    *) echo "error: Expected universal binary, got $ARCHS" >&2; exit 1 ;;
esac

echo "Linkage:"
otool -L "$BINARY_PATH" | tee "$EVIDENCE_DIR/linkage.txt"

echo "=== 6. Packaging Distributable Artifact ==="
ARCHIVE_NAME="Blip.droplet.tar.gz"
tar -czf "$DIST_DIR/$ARCHIVE_NAME" -C "$PACKAGE_DIR/.build" "$(basename "$BUNDLE_PATH")"

shasum -a 256 "$DIST_DIR/$ARCHIVE_NAME" | tee "$EVIDENCE_DIR/checksums.txt"

echo "Build complete. Artifact at: $DIST_DIR/$ARCHIVE_NAME"
