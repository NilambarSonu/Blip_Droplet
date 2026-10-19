//
//  FileDropModel.swift
//  BlipDroplet
//
//  Observable file-drop state machine for the Blip shelf widget.
//  Enforces 500 MB quota upfront, streams I/O without memory bloat, and manages partitioned staging.
//

import Foundation
import Combine
import UniformTypeIdentifiers
import CommonCrypto

/// Formal state machine of the staging engine
public enum DropState: Equatable, Sendable {
    case empty
    case validating(UUID)
    case staged(StagedFileInfo)
    case handoffRequested(StagedFileInfo)
    case handoffAcknowledged(StagedFileInfo)
    case error(String)
}

@MainActor
public final class FileDropModel: ObservableObject {
    @Published public private(set) var state: DropState = .empty
    @Published public var isTargeted: Bool = false

    private let storage: FileStagingStorage
    private var activeSecurityScopeURL: URL?

    public init(storage: FileStagingStorage = .shared) {
        self.storage = storage
    }

    isolated deinit {
        cleanup()
    }

    public func cleanup() {
        if let url = activeSecurityScopeURL {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopeURL = nil
        }
        if case .staged(let info) = state {
            storage.removeStagedFile(at: info.stagedURL)
        }
        state = .empty
    }

    /// Primary drop entry point from SwiftUI .onDrop
    public func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Duplicate drop guard: reject if already in progress or staged
        switch state {
        case .validating, .handoffRequested:
            state = .error("Drop rejected: an operation is already in progress.")
            return false
        case .staged:
            state = .error("A file is already staged. Clear it before dropping another.")
            return false
        case .empty, .handoffAcknowledged, .error:
            break
        }

        let opID = UUID()
        state = .validating(opID)

        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] (loadedURL, error) in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        self.state = .error("Failed to load dropped item: \(error.localizedDescription)")
                        return
                    }

                    guard let url = loadedURL else {
                        self.state = .error("Invalid file drop payload.")
                        return
                    }

                    self.stageAndValidate(url: url, operationID: opID)
                }
            }
            return true
        } else {
            state = .error("Item is not a valid file URL.")
            return false
        }
    }

    /// Validates attributes, security scope, and writes an atomic staging copy
    private func stageAndValidate(url: URL, operationID: UUID) {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        if isSecurityScoped {
            self.activeSecurityScopeURL = url
        }

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var stagedInfo: StagedFileInfo?
        var failureReason: String = ""

        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordError) { accessURL in
            let resourceValues = try? accessURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey])

            // Defense 1: Reject symlinks to prevent traversal vulnerabilities
            if resourceValues?.isSymbolicLink == true {
                failureReason = "Symlinks cannot be transferred."
                return
            }

            // Defense 2: Reject folders (single file transfer contract)
            if resourceValues?.isDirectory == true {
                failureReason = "Folders are not supported. Drop a single regular file."
                return
            }

            guard resourceValues?.isRegularFile == true else {
                failureReason = "Only regular files can be staged."
                return
            }

            // Defense 3: Upfront quota check BEFORE reading or copying
            guard let fileSizeInt = resourceValues?.fileSize else {
                failureReason = "Could not determine file size."
                return
            }
            let byteSize = Int64(fileSizeInt)

            guard byteSize > 0 else {
                failureReason = "File is empty (0 bytes)."
                return
            }

            guard byteSize <= self.storage.maxStagingBytes else {
                let formattedSize = ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
                let formattedMax = ByteCountFormatter.string(fromByteCount: self.storage.maxStagingBytes, countStyle: .file)
                failureReason = "File exceeds the \(formattedMax) limit (\(formattedSize))."
                return
            }

            // Defense 4: Check staging partition storage capacity
            let dest: URL
            do {
                dest = try self.storage.createPendingStagingDestination(for: accessURL.lastPathComponent, incomingBytes: byteSize)
            } catch {
                failureReason = error.localizedDescription
                return
            }

            // Defense 5: APFS Copy-on-Write clone / zero-RAM stream copy
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: accessURL, to: dest)
            } catch {
                failureReason = "Failed to copy file to staging: \(error.localizedDescription)"
                self.storage.removeStagedFile(at: dest)
                return
            }

            // Defense 6: Stream-computed SHA-256 in 64 KB chunks (O(64 KB) RAM, never slurps into memory)
            guard let handle = try? FileHandle(forReadingFrom: dest) else {
                failureReason = "Failed to open staged file for verification."
                self.storage.removeStagedFile(at: dest)
                return
            }

            var ctx = CC_SHA256_CTX()
            CC_SHA256_Init(&ctx)

            let chunkSize = 64 * 1024
            while true {
                let chunk = handle.readData(ofLength: chunkSize)
                if chunk.isEmpty { break }
                chunk.withUnsafeBytes { rawBuffer in
                    _ = CC_SHA256_Update(&ctx, rawBuffer.baseAddress, CC_LONG(rawBuffer.count))
                }
            }
            try? handle.close()

            var digest = [UInt8](repeating: 0, count: 32)
            CC_SHA256_Final(&digest, &ctx)
            let sha256Hex = digest.map { String(format: "%02x", $0) }.joined()

            stagedInfo = StagedFileInfo(
                id: operationID,
                originalName: accessURL.lastPathComponent,
                stagedURL: dest,
                byteSize: byteSize,
                sha256Hex: sha256Hex
            )
        }

        if isSecurityScoped {
            url.stopAccessingSecurityScopedResource()
            self.activeSecurityScopeURL = nil
        }

        if let info = stagedInfo {
            self.state = .staged(info)
        } else {
            let message = failureReason.isEmpty ? (coordError?.localizedDescription ?? "File validation failed.") : failureReason
            self.state = .error(message)
        }
    }

    /// User-initiated cancel / clear
    public func clearStaging() {
        switch state {
        case .staged(let info), .handoffRequested(let info), .handoffAcknowledged(let info):
            storage.removeStagedFile(at: info.stagedURL)
        default:
            break
        }
        state = .empty
    }

    /// Sets the state to handoff requested and promotes file from `pending/` to `handed_off/`.
    @discardableResult
    public func markHandoffRequested() throws -> StagedFileInfo {
        guard case .staged(let info) = state else {
            throw FileStagingError.moveFailed("Cannot request handoff from current state")
        }
        let handedOffURL = try storage.promoteToHandedOff(at: info.stagedURL)
        let updatedInfo = StagedFileInfo(
            id: info.id,
            originalName: info.originalName,
            stagedURL: handedOffURL,
            byteSize: info.byteSize,
            sha256Hex: info.sha256Hex,
            stagedAt: info.stagedAt
        )
        self.state = .handoffRequested(updatedInfo)
        return updatedInfo
    }

    /// Sets the state to handoff acknowledged
    public func markHandoffAcknowledged() {
        if case .handoffRequested(let info) = state {
            state = .handoffAcknowledged(info)
        }
    }

    /// Sets the state to error
    public func markError(_ message: String) {
        state = .error(message)
    }
}
