//
//  BlipDroplet.swift
//  BlipDroplet
//
//  Official Droplet entry point and ShelfWidgetProviding implementation for Blip.
//

import SwiftUI
import Combine
import DroppyKit

@MainActor
public final class BlipDroplet: NSObject, ObservableObject, Droplet {
    /// Must match droplet.json id and bundle DroppyDropletID
    public nonisolated static let id: DropletID = "blip"

    public let dropModel = FileDropModel()
    private var host: DropletHost?
    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
    }

    // MARK: - Droplet Lifecycle

    public func activate(host: DropletHost) throws {
        self.host = host
        host.log.info("Blip droplet activated on Droppy shelf.")

        // Listen for staging state changes to manage shelf hold-open
        dropModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self, let host = self.host else { return }
                switch state {
                case .staged:
                    _ = host.shelf.setHoldsOpen(true)
                case .empty, .error, .handoffAcknowledged:
                    _ = host.shelf.setHoldsOpen(false)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    public func deactivate() {
        cancellables.removeAll()
        _ = host?.shelf.setHoldsOpen(false)
        dropModel.cleanup()
        host = nil
    }

    // MARK: - Actions

    public func requestHandoff() {
        guard case .staged = dropModel.state else { return }

        do {
            let handedOffInfo = try dropModel.markHandoffRequested()

            BlipServicesAdapter.shared.requestHandoff(for: handedOffInfo.stagedURL) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        self.dropModel.markHandoffAcknowledged()
                    case .failure(let error):
                        if error == .dispatchDisabledInPhase3A {
                            // Truthful safety build explanation: clean up staged copy since no external handoff occurred
                            self.dropModel.clearStaging()
                            self.host?.log.info("Services dispatch compiled out in Phase 3 safety build.")
                        } else {
                            // Other error
                            self.dropModel.markError("Blip handoff failed: \(error)")
                            self.host?.log.error("Blip handoff failed: \(error)")
                        }
                    }
                }
            }
        } catch {
            dropModel.markError("Failed to prepare handoff: \(error.localizedDescription)")
        }
    }
}

// MARK: - ShelfWidgetProviding

extension BlipDroplet: ShelfWidgetProviding {
    public var widgetDescriptors: [ShelfWidgetDescriptor] {
        [
            ShelfWidgetDescriptor(
                id: "blip-shelf",
                title: "Blip",
                systemImage: "paperplane",
                layoutTraits: ShelfWidgetLayoutTraits(
                    preferredSoloWidth: 420,
                    preferredPairedWidth: 210,
                    contentHeight: .fixed(150)
                ),
                searchKeywords: ["blip", "transfer", "android", "file", "drop"]
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        AnyView(BlipShelfWidgetView(droplet: self, context: context))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? {
        nil
    }
}
