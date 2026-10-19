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

    // 9. Native File Picker Staging
    func testNativeFilePickerStaging() throws {
        let fixtureURL = tempDirectory.appendingPathComponent("picker_doc.pdf")
        let fixtureData = "Phase 3D Native File Picker Staged Data".data(using: .utf8)!
        try fixtureData.write(to: fixtureURL)

        let accepted = dropModel.handleFileChosen(url: fixtureURL)
        XCTAssertTrue(accepted, "handleFileChosen should accept valid regular file URL")

        let staged = wait(timeout: 3.0) {
            if case .staged(let info) = self.dropModel.state {
                return info.originalName == "picker_doc.pdf" && info.byteSize == Int64(fixtureData.count)
            }
            return false
        }
        XCTAssertTrue(staged, "Model failed to stage file chosen from picker")

        if case .staged(let info) = dropModel.state {
            XCTAssertTrue(FileManager.default.fileExists(atPath: info.stagedURL.path))
            XCTAssertFalse(info.sha256Hex.isEmpty)
        }
    }

    // 10. File Picker and Drag-and-Drop Staging Parity
    func testFilePickerAndDropValidationParity() throws {
        let fixtureURL = tempDirectory.appendingPathComponent("parity_doc.bin")
        let testBytes: [UInt8] = (0..<1024).map { UInt8($0 % 256) }
        let fixtureData = Data(testBytes)
        try fixtureData.write(to: fixtureURL)

        // Stage via drop
        let provider = NSItemProvider(contentsOf: fixtureURL)!
        XCTAssertTrue(dropModel.handleDrop(providers: [provider]))
        XCTAssertTrue(wait(timeout: 3.0) {
            if case .staged = self.dropModel.state { return true }
            return false
        })

        var dropSHA = ""
        var dropSize: Int64 = 0
        if case .staged(let info) = dropModel.state {
            dropSHA = info.sha256Hex
            dropSize = info.byteSize
        }
        dropModel.clearStaging()
        XCTAssertEqual(dropModel.state, .empty)

        // Stage via file picker
        XCTAssertTrue(dropModel.handleFileChosen(url: fixtureURL))
        XCTAssertTrue(wait(timeout: 3.0) {
            if case .staged = self.dropModel.state { return true }
            return false
        })

        var pickerSHA = ""
        var pickerSize: Int64 = 0
        if case .staged(let info) = dropModel.state {
            pickerSHA = info.sha256Hex
            pickerSize = info.byteSize
        }

        XCTAssertEqual(dropSHA, pickerSHA, "Both input methods must compute identical SHA-256")
        XCTAssertEqual(dropSize, pickerSize, "Both input methods must report identical byte size")
    }

    // 11. File Picker Rejection on Duplicate File
    func testFilePickerDuplicateRejection() throws {
        let fixtureURL = tempDirectory.appendingPathComponent("first.txt")
        try "first file".write(to: fixtureURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(dropModel.handleFileChosen(url: fixtureURL))

        XCTAssertTrue(wait(timeout: 3.0) {
            if case .staged = self.dropModel.state { return true }
            return false
        })

        let secondURL = tempDirectory.appendingPathComponent("second.txt")
        try "second file".write(to: secondURL, atomically: true, encoding: .utf8)
        let secondAccepted = dropModel.handleFileChosen(url: secondURL)
        XCTAssertFalse(secondAccepted)

        if case .error(let msg) = dropModel.state {
            XCTAssertTrue(msg.contains("already staged"))
        } else {
            XCTFail("Expected .error state on duplicate choose")
        }
    }

    // 12. File Picker Symlink and Directory Rejections
    func testFilePickerSymlinkAndDirectoryRejections() throws {
        let realFile = tempDirectory.appendingPathComponent("target_file.txt")
        try "data".write(to: realFile, atomically: true, encoding: .utf8)
        let linkFile = tempDirectory.appendingPathComponent("symlink_file.txt")
        try FileManager.default.createSymbolicLink(at: linkFile, withDestinationURL: realFile)

        XCTAssertTrue(dropModel.handleFileChosen(url: linkFile))
        XCTAssertTrue(wait(timeout: 3.0) {
            if case .error(let msg) = self.dropModel.state {
                return msg.contains("Symlinks cannot be transferred")
            }
            return false
        })

        dropModel.clearStaging()

        let folder = tempDirectory.appendingPathComponent("test_folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertTrue(dropModel.handleFileChosen(url: folder))
        XCTAssertTrue(wait(timeout: 3.0) {
            if case .error(let msg) = self.dropModel.state {
                return msg.contains("Folders are not supported")
            }
            return false
        })
    }

    // 13. Panel Controller Initial State
    func testPanelControllerInitialState() {
        let controller = BlipPanelController.shared
        XCTAssertFalse(controller.isOpen)
        XCTAssertFalse(controller.isPickerPresented)
    }

    // 14. Floating Panel Class Traits
    func testFloatingPanelClassTraits() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 320))
        var closed = false
        let panel = BlipFloatingPanel(contentView: view) {
            closed = true
        }

        XCTAssertTrue(panel.canBecomeKey, "Floating panel must be able to become key for keyboard focus")
        XCTAssertTrue(panel.canBecomeMain, "Floating panel must be able to become main")
        XCTAssertEqual(panel.level, .floating, "Floating panel must be at .floating level")
        XCTAssertTrue(panel.isFloatingPanel)

        // Test Escape key dismissal simulation
        panel.cancelOperation(nil)
        XCTAssertTrue(closed, "cancelOperation must invoke onClose handler")
    }
}
