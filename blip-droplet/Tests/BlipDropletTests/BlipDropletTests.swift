//
//  BlipDropletTests.swift
//  BlipDropletTests
//
//  Unit and contract tests for the Blip droplet state engine and safety gates.
//

import XCTest
import Foundation
import UniformTypeIdentifiers
@testable import BlipDroplet

final class BlipDropletTests: XCTestCase {
    var tempDirectory: URL!
    var storage: FileStagingStorage!
    var dropModel: FileDropModel!

    override func setUp() {
        super.setUp()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("blip_unit_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storage = FileStagingStorage(customBaseURL: tempDirectory)
        dropModel = FileDropModel(storage: storage)
    }

    override func tearDown() {
        dropModel.cleanup()
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // Helper to pump RunLoop until condition met
    @discardableResult
    private func wait(timeout: TimeInterval = 3.0, until condition: () -> Bool) -> Bool {
        let start = Date()
        while !condition() && Date().timeIntervalSince(start) < timeout {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    // 1. Empty State
    func testInitialEmptyState() {
        XCTAssertEqual(dropModel.state, .empty)
        XCTAssertFalse(dropModel.isTargeted)
    }

    // 2. Valid Staged File
    func testValidFileDropAndStaging() throws {
        let fixtureURL = tempDirectory.appendingPathComponent("test_doc.txt")
        let fixtureData = "Phase 3A DroppyKit Synthetic Test Payload".data(using: .utf8)!
        try fixtureData.write(to: fixtureURL)

        let provider = NSItemProvider(contentsOf: fixtureURL)!
        let accepted = dropModel.handleDrop(providers: [provider])
        XCTAssertTrue(accepted)

        let staged = wait(timeout: 3.0) {
            if case .staged(let info) = self.dropModel.state {
                return info.byteSize == Int64(fixtureData.count)
            }
            return false
        }
        XCTAssertTrue(staged, "Model failed to transition to .staged state")

        if case .staged(let info) = dropModel.state {
            XCTAssertEqual(info.originalName, "test_doc.txt")
            XCTAssertTrue(FileManager.default.fileExists(atPath: info.stagedURL.path))
            XCTAssertEqual(try? Data(contentsOf: info.stagedURL), fixtureData)
        }
    }

    // 3. Duplicate Drop Prevention
    func testDuplicateDropRejection() throws {
        let fixtureURL = tempDirectory.appendingPathComponent("test_doc.txt")
        try "payload".write(to: fixtureURL, atomically: true, encoding: .utf8)

        let provider1 = NSItemProvider(contentsOf: fixtureURL)!
        XCTAssertTrue(dropModel.handleDrop(providers: [provider1]))

        XCTAssertTrue(wait(timeout: 3.0) {
            if case .staged = self.dropModel.state { return true }
            return false
        })

        // Second drop must be rejected
        let provider2 = NSItemProvider(contentsOf: fixtureURL)!
        let secondAccepted = dropModel.handleDrop(providers: [provider2])
        XCTAssertFalse(secondAccepted)

        if case .error(let msg) = dropModel.state {
            XCTAssertTrue(msg.contains("already staged"))
        } else {
            XCTFail("Expected state to be .error on duplicate drop")
        }
    }

    // 4. Symlink Rejection
    func testSymlinkRejection() throws {
        let targetURL = tempDirectory.appendingPathComponent("real_target.txt")
        try "real data".write(to: targetURL, atomically: true, encoding: .utf8)

        let linkURL = tempDirectory.appendingPathComponent("link_pointer.txt")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let symlinkProvider = NSItemProvider(contentsOf: linkURL)!
        XCTAssertTrue(dropModel.handleDrop(providers: [symlinkProvider]))

        XCTAssertTrue(wait(timeout: 3.0) {
            if case .error(let msg) = self.dropModel.state {
                return msg.contains("Symlinks cannot be transferred")
            }
            return false
        }, "Symlink should have been rejected")
    }

    // 5. Directory Drop Rejection
    func testDirectoryRejection() throws {
        let folderURL = tempDirectory.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let dirProvider = NSItemProvider(contentsOf: folderURL)!
        XCTAssertTrue(dropModel.handleDrop(providers: [dirProvider]))

        XCTAssertTrue(wait(timeout: 3.0) {
            if case .error(let msg) = self.dropModel.state {
                return msg.contains("Folders are not supported")
            }
            return false
        }, "Directory drop should have been rejected")
    }

    // 6. Clear Staging Cleanup
    func testClearStaging() throws {
        let fixtureURL = tempDirectory.appendingPathComponent("clear_test.txt")
        try "test".write(to: fixtureURL, atomically: true, encoding: .utf8)

        let provider = NSItemProvider(contentsOf: fixtureURL)!
        XCTAssertTrue(dropModel.handleDrop(providers: [provider]))

        XCTAssertTrue(wait(timeout: 3.0) {
            if case .staged = self.dropModel.state { return true }
            return false
        })

        guard case .staged(let info) = dropModel.state else {
            XCTFail("Not in staged state")
            return
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: info.stagedURL.path))

        dropModel.clearStaging()
        XCTAssertEqual(dropModel.state, .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: info.stagedURL.path), "Staged file was not removed on clear")
    }

    // 7. Services Adapter Phase 3A Safety Gate
    func testServicesAdapterDispatchSafety() {
        XCTAssertFalse(BlipServicesAdapter.isDispatchCompiledIn, "Dispatch MUST be compiled out in Phase 3A")

        let dummyURL = tempDirectory.appendingPathComponent("dummy.txt")
        try? "dummy".write(to: dummyURL, atomically: true, encoding: .utf8)

        let expectation = self.expectation(description: "Handoff callback")
        BlipServicesAdapter.shared.requestHandoff(for: dummyURL) { result in
            switch result {
            case .success:
                XCTFail("Live dispatch must not succeed in Phase 3A")
            case .failure(let err):
                XCTAssertEqual(err, .dispatchDisabledInPhase3A)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    // 8. Droplet Widget Descriptor Compliance
    func testWidgetDescriptorTraits() {
        let droplet = BlipDroplet()
        let descriptors = droplet.widgetDescriptors
        XCTAssertEqual(descriptors.count, 1)

        let desc = descriptors[0]
        XCTAssertEqual(desc.id, "blip-shelf")
        XCTAssertEqual(desc.title, "Blip")
        XCTAssertEqual(desc.layoutTraits.preferredSoloWidth, 420)
        XCTAssertEqual(desc.layoutTraits.preferredPairedWidth, 210)
        XCTAssertEqual(desc.layoutTraits.contentHeight, .fixed(150))
    }
}
