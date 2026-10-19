//
//  FileStagingStorage.swift
//  BlipDroplet
//
//  Storage and retention management for local staged files.
//  Implements partitioned staging (pending vs. handed_off) and strict quota bounds.
//

import Foundation

/// Metadata of a staged file
public struct StagedFileInfo: Codable, Equatable, Sendable {
    public let id: UUID
    public let originalName: String
    public let stagedURL: URL
    public let byteSize: Int64
    public let sha256Hex: String
    public let stagedAt: Date

    public init(id: UUID = UUID(), originalName: String, stagedURL: URL, byteSize: Int64, sha256Hex: String, stagedAt: Date = Date()) {
        self.id = id
        self.originalName = originalName
        self.stagedURL = stagedURL
        self.byteSize = byteSize
        self.sha256Hex = sha256Hex
        self.stagedAt = stagedAt
    }
}

public enum FileStagingError: Error, LocalizedError, Equatable {
    case quotaExceeded(Int64, Int64)
    case invalidFilename
    case stagingDirectoryCreationFailed
    case moveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .quotaExceeded(let current, let limit):
            let curStr = ByteCountFormatter.string(fromByteCount: current, countStyle: .file)
            let limStr = ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)
            return "Staging storage quota exceeded (\(curStr) used of \(limStr) limit). Clear existing items."
        case .invalidFilename:
            return "Filename contains invalid or dangerous characters."
        case .stagingDirectoryCreationFailed:
            return "Unable to create local staging directories."
        case .moveFailed(let reason):
            return "Failed to move file in staging: \(reason)"
        }
    }
}

/// Thread-safe manager for droplet staging storage, partitioned retention, and quota enforcement.
public final class FileStagingStorage: @unchecked Sendable {
    public static let shared = FileStagingStorage()

    private let fileManager = FileManager.default
    private let stagingBaseDirectory: URL
    public let pendingDirectory: URL
    public let handedOffDirectory: URL

    public let maxStagingBytes: Int64 = 500 * 1024 * 1024 // 500 MB hard ceiling
    private let stalePendingLifetimeSeconds: TimeInterval = 3600 // 1 hour for never-handed-off files

    public init(customBaseURL: URL? = nil) {
        if let customBaseURL = customBaseURL {
            self.stagingBaseDirectory = customBaseURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.stagingBaseDirectory = appSupport
                .appendingPathComponent("Droppy", isDirectory: true)
                .appendingPathComponent("Droplets", isDirectory: true)
                .appendingPathComponent("blip", isDirectory: true)
                .appendingPathComponent("staging", isDirectory: true)
        }
        self.pendingDirectory = stagingBaseDirectory.appendingPathComponent("pending", isDirectory: true)
        self.handedOffDirectory = stagingBaseDirectory.appendingPathComponent("handed_off", isDirectory: true)

        createDirectoriesIfNeeded()
        pruneOrphanedPendingFiles()
    }

    private func createDirectoriesIfNeeded() {
        if !fileManager.fileExists(atPath: pendingDirectory.path) {
            try? fileManager.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: handedOffDirectory.path) {
            try? fileManager.createDirectory(at: handedOffDirectory, withIntermediateDirectories: true)
        }
    }

    /// Calculates total bytes used across both pending and handed-off partitions.
    public func currentTotalStagingBytes() -> Int64 {
        var total: Int64 = 0
        for dir in [pendingDirectory, handedOffDirectory] {
            guard let entries = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for file in entries {
                if let values = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    /// Allocates an isolated destination URL in `pending/` for staging, enforcing quota and strict filename sanitization.
    public func createPendingStagingDestination(for filename: String, incomingBytes: Int64) throws -> URL {
        createDirectoriesIfNeeded()

        // 1. Quota pre-check
        let currentUsage = currentTotalStagingBytes()
        if (currentUsage + incomingBytes) > maxStagingBytes {
            throw FileStagingError.quotaExceeded(currentUsage + incomingBytes, maxStagingBytes)
        }

        // 2. Strict filename sanitization and traversal prevention
        var safeName = (filename as NSString).lastPathComponent
        // Strip null bytes and path separators
        safeName = safeName.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Prevent hidden file or dot-dot manipulation
        while safeName.hasPrefix(".") {
            safeName = String(safeName.dropFirst())
        }
        if safeName.isEmpty {
            safeName = "staged_file"
        }
        // Limit maximum filename length to 128 characters
        if safeName.count > 128 {
            let ext = (safeName as NSString).pathExtension
            let base = (safeName as NSString).deletingPathExtension
            safeName = "\(base.prefix(120)).\(ext)"
        }

        let uniquePrefix = UUID().uuidString.prefix(8)
        let destination = pendingDirectory.appendingPathComponent("\(uniquePrefix)_\(safeName)")

        // Defense-in-depth: Canonical path prefix verification
        let standardizedDest = destination.standardizedFileURL.path
        let standardizedPending = pendingDirectory.standardizedFileURL.path
        guard standardizedDest.hasPrefix(standardizedPending) else {
            throw FileStagingError.invalidFilename
        }

        return destination
    }

    /// Atomically moves a staged file from `pending/` to `handed_off/` when services handoff is requested.
    /// Files in `handed_off/` are NEVER pruned by background timers.
    public func promoteToHandedOff(at pendingURL: URL) throws -> URL {
        createDirectoriesIfNeeded()
        let filename = pendingURL.lastPathComponent
        let targetURL = handedOffDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }

        do {
            try fileManager.moveItem(at: pendingURL, to: targetURL)
            return targetURL
        } catch {
            throw FileStagingError.moveFailed(error.localizedDescription)
        }
    }

    /// Immediately cleans up a specific staged file URL (from either pending or handed_off).
    public func removeStagedFile(at url: URL) {
        let path = url.standardizedFileURL.path
        let pendingPrefix = pendingDirectory.standardizedFileURL.path
        let handedOffPrefix = handedOffDirectory.standardizedFileURL.path

        guard path.hasPrefix(pendingPrefix) || path.hasPrefix(handedOffPrefix) else { return }
        try? fileManager.removeItem(at: url)
    }

    /// Prunes ONLY orphaned files in `pending/` left behind from crashed operations or abandoned drops.
    /// CRITICAL: NEVER deletes files in `handed_off/`, as external Blip may still be streaming them.
    public func pruneOrphanedPendingFiles() {
        guard let entries = try? fileManager.contentsOfDirectory(at: pendingDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let now = Date()
        for file in entries {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               now.timeIntervalSince(modDate) > stalePendingLifetimeSeconds {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// Purges all active staging files across both pending and handed-off partitions (e.g. test teardown or explicit user purge).
    public func purgeAll() {
        for dir in [pendingDirectory, handedOffDirectory] {
            guard let entries = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for file in entries {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
