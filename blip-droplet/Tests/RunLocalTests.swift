//
//  RunLocalTests.swift
//  BlipDropletTests
//
//  Standalone local test runner for BlipDroplet core logic and state safety gates.
//

import Foundation
import Combine
import UniformTypeIdentifiers

struct TestReportResult: Codable {
    let testName: String
    let passed: Bool
    let detail: String
}

struct TestReport: Codable {
    let timestamp: String
    let total: Int
    let passed: Int
    let failed: Int
    let results: [TestReportResult]
}

@main
struct TestRunnerMain {
    static func main() {
        var results: [TestReportResult] = []

        let tempBase = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("blip_runner_test_\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempBase)
        }

        let storage = FileStagingStorage(customBaseURL: tempBase.appendingPathComponent("staging"))
        let model = FileDropModel(storage: storage)

        // Helper to pump RunLoop
        func pump(timeout: TimeInterval = 3.0, condition: () -> Bool) -> Bool {
            let start = Date()
            while !condition() && Date().timeIntervalSince(start) < timeout {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
            return condition()
        }

        // Test 1: Empty state
        do {
            let passed = (model.state == .empty) && !model.isTargeted
            results.append(TestReportResult(testName: "Initial Empty State", passed: passed, detail: "Model initializes in .empty state with target flag false"))
        }

        // Test 2: Valid File Drop & Staging
        do {
            let fileURL = tempBase.appendingPathComponent("sample_valid.txt")
            let payload = "Antigravity Phase 3B Synthetic Test Data. 43 bytes.".data(using: .utf8)!
            try! payload.write(to: fileURL)

            let provider = NSItemProvider(contentsOf: fileURL)!
            let accepted = model.handleDrop(providers: [provider])

            let staged = pump(timeout: 3.0) {
                if case .staged(let info) = model.state {
                    return info.byteSize == Int64(payload.count)
                }
                return false
            }

            var detail = ""
            var passed = false
            if staged, case .staged(let info) = model.state {
                let fileExists = FileManager.default.fileExists(atPath: info.stagedURL.path)
                let inPending = info.stagedURL.path.hasPrefix(storage.pendingDirectory.path)
                let dataMatches = (try? Data(contentsOf: info.stagedURL)) == payload
                passed = accepted && fileExists && inPending && dataMatches
                detail = "Staged \(info.byteSize) bytes in pending/ (SHA: \(info.sha256Hex.prefix(8))…) at \(info.stagedURL.lastPathComponent)"
            } else {
                detail = "Failed to transition to .staged state"
            }
            results.append(TestReportResult(testName: "Valid File Drop and Staging", passed: passed, detail: detail))
        }

        // Test 3: Duplicate Drop Rejection (Code 409)
        do {
            let fileURL = tempBase.appendingPathComponent("sample_valid.txt")
            let provider2 = NSItemProvider(contentsOf: fileURL)!
            let secondAccepted = model.handleDrop(providers: [provider2])

            var passed = false
            var detail = ""
            if !secondAccepted, case .error(let msg) = model.state {
                passed = msg.contains("already staged")
                detail = "Correctly rejected re-entrant drop: \(msg)"
            } else {
                detail = "Duplicate drop was not rejected"
            }
            results.append(TestReportResult(testName: "Duplicate Drop Rejection", passed: passed, detail: detail))
        }

        // Test 4: Symlink Rejection
        do {
            model.clearStaging()
            let realURL = tempBase.appendingPathComponent("real_file.txt")
            try! "real content".write(to: realURL, atomically: true, encoding: .utf8)

            let linkURL = tempBase.appendingPathComponent("symlink.txt")
            try? FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: realURL)

            let linkProvider = NSItemProvider(contentsOf: linkURL)!
            _ = model.handleDrop(providers: [linkProvider])

            let rejected = pump(timeout: 3.0) {
                if case .error(let msg) = model.state {
                    return msg.contains("Symlinks cannot be transferred")
                }
                return false
            }
            results.append(TestReportResult(testName: "Symlink Rejection", passed: rejected, detail: "Symlink was safely identified and rejected"))
        }

        // Test 5: Directory Drop Rejection
        do {
            model.clearStaging()
            let folderURL = tempBase.appendingPathComponent("sample_folder")
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            let dirProvider = NSItemProvider(contentsOf: folderURL)!
            _ = model.handleDrop(providers: [dirProvider])

            let rejected = pump(timeout: 3.0) {
                if case .error(let msg) = model.state {
                    return msg.contains("Folders are not supported")
                }
                return false
            }
            results.append(TestReportResult(testName: "Directory Drop Rejection", passed: rejected, detail: "Directory was safely identified and rejected"))
        }

        // Test 6: Clear Staging Cleanup
        do {
            model.clearStaging()
            let fileURL = tempBase.appendingPathComponent("sample_valid.txt")
            let provider = NSItemProvider(contentsOf: fileURL)!
            _ = model.handleDrop(providers: [provider])

            _ = pump(timeout: 3.0) {
                if case .staged = model.state { return true }
                return false
            }

            var stagedPath = ""
            if case .staged(let info) = model.state {
                stagedPath = info.stagedURL.path
            }

            let existedBefore = FileManager.default.fileExists(atPath: stagedPath)
            model.clearStaging()
            let existsAfter = FileManager.default.fileExists(atPath: stagedPath)

            let passed = existedBefore && !existsAfter && (model.state == .empty)
            results.append(TestReportResult(testName: "Clear Staging Cleanup", passed: passed, detail: "Staged file removed from disk and state reset to .empty"))
        }

        // Test 7: Services Adapter Dispatch Safety Gate
        do {
            let isCompiledIn = BlipServicesAdapter.isDispatchCompiledIn
            let adapter = BlipServicesAdapter()

            final class SafeBox: @unchecked Sendable {
                var callbackReturned = false
                var failureCorrect = false
            }
            let box = SafeBox()

            let dummyURL = tempBase.appendingPathComponent("dummy.txt")
            try! "dummy".write(to: dummyURL, atomically: true, encoding: .utf8)

            adapter.requestHandoff(for: dummyURL) { res in
                box.callbackReturned = true
                if case .failure(let err) = res, err == .dispatchDisabledInPhase3A {
                    box.failureCorrect = true
                }
            }

            let passed = !isCompiledIn && box.callbackReturned && box.failureCorrect
            let detail = "isDispatchCompiledIn=\(isCompiledIn). Handoff safely refused with .dispatchDisabledInPhase3A."
            results.append(TestReportResult(testName: "Services Adapter Safety Gate", passed: passed, detail: detail))
        }

        // Test 8: 500 MB Quota Rejection
        do {
            let hugeSize: Int64 = 501 * 1024 * 1024
            var quotaThrew = false
            do {
                _ = try storage.createPendingStagingDestination(for: "oversized.bin", incomingBytes: hugeSize)
            } catch FileStagingError.quotaExceeded {
                quotaThrew = true
            } catch {
                quotaThrew = false
            }
            results.append(TestReportResult(testName: "500 MB Quota Pre-Check", passed: quotaThrew, detail: "createPendingStagingDestination threw quotaExceeded before allocating file"))
        }

        // Test 9: Partitioned Promotion (pending -> handed_off)
        do {
            storage.purgeAll()
            let dest = try! storage.createPendingStagingDestination(for: "promotion_test.txt", incomingBytes: 100)
            try! "test payload".write(to: dest, atomically: true, encoding: .utf8)

            let inPendingBefore = FileManager.default.fileExists(atPath: dest.path)
            let promotedURL = try! storage.promoteToHandedOff(at: dest)
            let inPendingAfter = FileManager.default.fileExists(atPath: dest.path)
            let inHandedOffAfter = FileManager.default.fileExists(atPath: promotedURL.path)

            let passed = inPendingBefore && !inPendingAfter && inHandedOffAfter && promotedURL.path.hasPrefix(storage.handedOffDirectory.path)
            results.append(TestReportResult(testName: "Partitioned Promotion", passed: passed, detail: "File atomically moved from pending/ to handed_off/"))
        }

        // Test 10: Retention Isolation (handed_off NEVER pruned by background rule)
        do {
            let handedOffDest = storage.handedOffDirectory.appendingPathComponent("retained_transfer.txt")
            try! "essential data still streaming to Android".write(to: handedOffDest, atomically: true, encoding: .utf8)

            // Simulate ancient file timestamp
            let twoHoursAgo = Date(timeIntervalSinceNow: -7200)
            try? FileManager.default.setAttributes([.modificationDate: twoHoursAgo], ofItemAtPath: handedOffDest.path)

            // Run pending pruning
            storage.pruneOrphanedPendingFiles()

            // File in handed_off MUST still exist!
            let stillExists = FileManager.default.fileExists(atPath: handedOffDest.path)
            storage.purgeAll()

            results.append(TestReportResult(testName: "Retention Isolation", passed: stillExists, detail: "pruneOrphanedPendingFiles spared files in handed_off/ regardless of age"))
        }

        // Output JSON report
        let passedCount = results.filter { $0.passed }.count
        let failedCount = results.filter { !$0.passed }.count
        let report = TestReport(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            total: results.count,
            passed: passedCount,
            failed: failedCount,
            results: results
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report), let str = String(data: data, encoding: .utf8) {
            print(str)
        }

        if failedCount > 0 {
            exit(1)
        } else {
            exit(0)
        }
    }
}
