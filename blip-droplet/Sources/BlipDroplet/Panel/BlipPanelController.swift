//
//  BlipPanelController.swift
//  BlipDroplet
//
//  Native floating panel management for Blip.
//  Uses DroppyKit's officially documented DroppyPanelActivation session,
//  anchors top-center below the notch, and provides native macOS focus/escape handling.
//

import AppKit
import SwiftUI
import DroppyKit

@MainActor
public final class BlipFloatingPanel: NSPanel {
    private var onClose: (() -> Void)?

    public init(contentView: NSView, onClose: @escaping () -> Void) {
        self.onClose = onClose

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.becomesKeyOnlyIfNeeded = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.contentView = contentView
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public override func cancelOperation(_ sender: Any?) {
        // Native Escape key dismissal
        onClose?()
    }
}

@MainActor
public final class BlipPanelController: ObservableObject {
    public static let shared = BlipPanelController()

    @Published public private(set) var isOpen: Bool = false
    @Published public private(set) var isPickerPresented: Bool = false

    private var panel: BlipFloatingPanel?
    private var activation: DroppyPanelActivation?
    private weak var droplet: BlipDroplet?
    private var previousApp: NSRunningApplication?

    public init() {}

    public func configure(droplet: BlipDroplet) {
        self.droplet = droplet
    }

    public func togglePanel() {
        if isOpen {
            closePanel()
        } else {
            openPanel()
        }
    }

    public func openPanel() {
        guard !isOpen, let droplet = self.droplet else { return }

        // Capture previous frontmost application for clean focus restoration
        previousApp = NSWorkspace.shared.frontmostApplication

        if panel == nil {
            let rootView = BlipSendPanelView(droplet: droplet, controller: self)
            let hostingView = NSHostingView(rootView: rootView)
            panel = BlipFloatingPanel(contentView: hostingView) { [weak self] in
                self?.closePanel()
            }
        }

        guard let panel = self.panel else { return }

        // Position panel centered horizontally, just beneath top notch / menu bar
        positionPanel(panel)

        panel.makeKeyAndOrderFront(nil)
        activation = DroppyPanelActivation.begin(for: panel, returningTo: previousApp)
        isOpen = true
    }

    public func closePanel() {
        guard isOpen, let panel = self.panel else { return }

        activation?.finish()
        activation = nil
        panel.orderOut(nil)
        isOpen = false
    }

    private func positionPanel(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else {
            panel.center()
            return
        }

        let panelSize = CGSize(width: 380, height: 320)
        let screenFrame = screen.visibleFrame

        // Center horizontally
        let x = screenFrame.midX - (panelSize.width / 2.0)
        // Position top-center, safely below notch / menu bar clearance (14pt margin)
        let y = screenFrame.maxY - panelSize.height - 14.0

        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    /// Presents native macOS Open Dialog for choosing a single regular file
    public func presentFilePicker() {
        guard !isPickerPresented, let droplet = self.droplet else { return }
        isPickerPresented = true

        let openPanel = NSOpenPanel()
        openPanel.title = "Select File to Send with Blip"
        openPanel.prompt = "Choose"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        openPanel.resolvesAliases = true
        openPanel.level = .modalPanel

        openPanel.begin { [weak self] response in
            Task { @MainActor in
                guard let self = self else { return }
                self.isPickerPresented = false
                if response == .OK, let url = openPanel.url {
                    _ = droplet.dropModel.handleFileChosen(url: url)
                }
            }
        }
    }
}
