//
//  BlipPanelController.swift
//  BlipDroplet
//
//  Native floating panel management for Blip.
//  Uses DroppyKit's officially documented DroppyPanelActivation session,
//  anchors top-center below the notch, and provides native macOS focus,
//  window controls (traffic lights), and window dragging.
//

import AppKit
import SwiftUI
import Combine
import DroppyKit

@MainActor
public final class BlipFloatingPanel: NSPanel {
    private var onClose: (() -> Void)?

    public init(contentView: NSView, onClose: @escaping () -> Void) {
        self.onClose = onClose

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.becomesKeyOnlyIfNeeded = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.contentView = contentView

        // Configure standard macOS traffic lights
        if let close = standardWindowButton(.closeButton) {
            close.target = self
            close.action = #selector(handleClose)
            close.toolTip = "Close (Esc)"
        }
        if let mini = standardWindowButton(.miniaturizeButton) {
            mini.isEnabled = true
            mini.target = self
            mini.action = #selector(handleMiniaturize)
            mini.toolTip = "Hide Blip Panel"
        }
        if let zoom = standardWindowButton(.zoomButton) {
            zoom.isEnabled = true
            zoom.target = self
            zoom.action = #selector(handleZoom)
            zoom.toolTip = "Toggle Expanded View"
        }
    }

    @objc public func handleClose() {
        onClose?()
    }

    @objc public func handleMiniaturize() {
        // Floating panels do not dock into the macOS Dock tile.
        // An honest, accessible equivalent is to hide the panel back to the notch.
        onClose?()
    }

    @objc public func handleZoom() {
        BlipPanelController.shared.toggleZoom()
    }

    public override func performClose(_ sender: Any?) {
        handleClose()
    }

    public override func miniaturize(_ sender: Any?) {
        handleMiniaturize()
    }

    public override func zoom(_ sender: Any?) {
        handleZoom()
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public override func cancelOperation(_ sender: Any?) {
        // Native Escape key dismissal
        handleClose()
    }
}

/// AppKit view for initiating a native window drag session on mouseDown
@MainActor
final class DraggableHeaderNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Double-click title bar toggles zoom
            BlipPanelController.shared.toggleZoom()
        } else if let window = self.window {
            window.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}

/// SwiftUI wrapper for the draggable title bar region
public struct DraggableHeaderArea: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        DraggableHeaderNSView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
public final class BlipPanelController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = BlipPanelController()

    @Published public private(set) var isOpen: Bool = false
    @Published public private(set) var isPickerPresented: Bool = false
    @Published public private(set) var isZoomed: Bool = false

    private var panel: BlipFloatingPanel?
    private var activation: DroppyPanelActivation?
    private weak var droplet: BlipDroplet?
    private var previousApp: NSRunningApplication?
    private var savedOrigin: NSPoint?
    private var screenObserver: AnyCancellable?

    public override init() {
        super.init()

        // Restore previously remembered origin if available
        if let coords = UserDefaults.standard.array(forKey: "BlipDroplet.PanelOrigin") as? [CGFloat], coords.count == 2 {
            savedOrigin = NSPoint(x: coords[0], y: coords[1])
        }

        // Listen for screen parameter changes (display connect/disconnect/resolution changes)
        screenObserver = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.handleScreenParametersChanged()
            }
    }

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
            let newPanel = BlipFloatingPanel(contentView: hostingView) { [weak self] in
                self?.closePanel()
            }
            newPanel.delegate = self
            self.panel = newPanel
        }

        guard let panel = self.panel else { return }

        // Position panel: use clamped saved position if available, or default top-center
        applySavedOrDefaultPosition(to: panel)

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

    public func toggleZoom() {
        guard let panel = panel else { return }
        isZoomed.toggle()
        let targetSize = isZoomed ? CGSize(width: 440, height: 400) : CGSize(width: 380, height: 320)
        let currentOrigin = panel.frame.origin
        // Expand downwards and outward symmetrically
        let deltaW = targetSize.width - panel.frame.width
        let deltaH = targetSize.height - panel.frame.height
        let newOrigin = NSPoint(x: currentOrigin.x - deltaW / 2.0, y: currentOrigin.y - deltaH)
        let clamped = clampToVisibleScreen(origin: newOrigin, size: targetSize)
        panel.setFrame(NSRect(origin: clamped, size: targetSize), display: true, animate: true)
    }

    public func resetPosition() {
        guard let panel = panel else { return }
        savedOrigin = nil
        UserDefaults.standard.removeObject(forKey: "BlipDroplet.PanelOrigin")
        let targetSize = isZoomed ? CGSize(width: 440, height: 400) : CGSize(width: 380, height: 320)
        let defaultOrigin = computeDefaultOrigin(for: targetSize)
        panel.setFrame(NSRect(origin: defaultOrigin, size: targetSize), display: true, animate: true)
    }

    private func applySavedOrDefaultPosition(to panel: NSPanel) {
        let targetSize = isZoomed ? CGSize(width: 440, height: 400) : CGSize(width: 380, height: 320)
        let origin: NSPoint
        if let saved = savedOrigin {
            origin = clampToVisibleScreen(origin: saved, size: targetSize)
        } else {
            origin = computeDefaultOrigin(for: targetSize)
        }
        panel.setFrame(NSRect(origin: origin, size: targetSize), display: true)
    }

    public func computeDefaultOrigin(for size: CGSize) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else {
            return NSPoint(x: 200, y: 200)
        }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - (size.width / 2.0)
        let y = screenFrame.maxY - size.height - 14.0
        return NSPoint(x: x, y: y)
    }

    public func clampToVisibleScreen(origin: NSPoint, size: CGSize) -> NSPoint {
        let targetRect = NSRect(origin: origin, size: size)
        let centerPoint = NSPoint(x: targetRect.midX, y: targetRect.midY)

        let targetScreen = NSScreen.screens.first { NSMouseInRect(centerPoint, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else { return origin }
        let visible = screen.visibleFrame

        var x = origin.x
        var y = origin.y

        // Clamp horizontally: at least 12pt margin from visible screen edges
        if x < visible.minX + 12 {
            x = visible.minX + 12
        } else if x + size.width > visible.maxX - 12 {
            x = visible.maxX - size.width - 12
        }

        // Clamp vertically: at least 12pt margin from dock/menu bar
        if y < visible.minY + 12 {
            y = visible.minY + 12
        } else if y + size.height > visible.maxY - 12 {
            y = visible.maxY - size.height - 12
        }

        return NSPoint(x: x, y: y)
    }

    private func handleScreenParametersChanged() {
        guard let panel = panel, panel.isVisible else { return }
        let clamped = clampToVisibleScreen(origin: panel.frame.origin, size: panel.frame.size)
        panel.setFrame(NSRect(origin: clamped, size: panel.frame.size), display: true, animate: true)
    }

    // MARK: - NSWindowDelegate

    public func windowDidMove(_ notification: Notification) {
        guard let panel = panel else { return }
        savedOrigin = panel.frame.origin
        UserDefaults.standard.set([panel.frame.origin.x, panel.frame.origin.y], forKey: "BlipDroplet.PanelOrigin")
    }

    // MARK: - File Picker

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
