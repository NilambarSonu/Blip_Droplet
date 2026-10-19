//
//  BlipSendPanelView.swift
//  BlipDroplet
//
//  Premium native macOS floating send panel for Blip.
//  Features native traffic lights, draggable title bar, rich dark appearance,
//  file drop target, and native file picker integration.
//

import SwiftUI
import DroppyKit
import UniformTypeIdentifiers

public struct BlipSendPanelView: View {
    @ObservedObject var droplet: BlipDroplet
    @ObservedObject var model: FileDropModel
    @ObservedObject var controller: BlipPanelController

    @State private var isTargeted: Bool = false
    private let electricBlue = Color(red: 0.05, green: 0.60, blue: 1.0)

    public init(droplet: BlipDroplet, controller: BlipPanelController) {
        self.droplet = droplet
        self.model = droplet.dropModel
        self.controller = controller
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerRow

            Divider()
                .opacity(0.25)

            mainContent
                .padding(DroppySpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .opacity(0.25)

            footerRow
                .padding(.horizontal, DroppySpacing.md)
                .padding(.vertical, DroppySpacing.sm)
        }
        .frame(
            width: controller.isZoomed ? 440 : 380,
            height: controller.isZoomed ? 400 : 320
        )
        .background(
            ZStack {
                // Deep dark base material for excellent contrast on any wallpaper
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraDarkMaterial)
                    )

                // Droppy native glass surface for sheen and host theme harmony
                DroppyPanelSurface(cornerRadius: 24)
                    .opacity(0.70)

                // Crisp hairline border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: controller.isZoomed)
    }

    // MARK: - Header (with Traffic Light clearance & Draggable background)

    private var headerRow: some View {
        HStack(spacing: DroppySpacing.sm) {
            // Draggable leading region: clearance for traffic lights + icon badge + title + flex spacer
            HStack(spacing: DroppySpacing.sm) {
                // Clearance for top-left native AppKit traffic lights (Red, Yellow, Green)
                Spacer()
                    .frame(width: 58)

                // Blip icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(electricBlue.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(electricBlue)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Blip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
                    Text("Send to your Android device")
                        .font(.system(size: 11))
                        .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .background(DraggableHeaderArea())

            // Reset Position button (smoothly returns panel below the notch)
            Button {
                controller.resetPosition()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
            }
            .buttonStyle(DroppyQuietButtonStyle(size: .small))
            .help("Reset position below notch")
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.top, 14)
        .padding(.bottom, DroppySpacing.sm)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch model.state {
        case .empty:
            emptyDropAndChooseView

        case .validating:
            validatingView

        case .staged(let info):
            stagedView(info: info)

        case .handoffRequested(let info):
            handoffRequestedView(info: info)

        case .handoffAcknowledged(let info):
            handoffAcknowledgedView(info: info)

        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Empty State (Drop Target + Choose File Button)

    private var emptyDropAndChooseView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .fill(isTargeted ? electricBlue.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .strokeBorder(
                            isTargeted ? electricBlue : Color.white.opacity(0.10),
                            style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: isTargeted ? [] : [5, 5])
                        )
                )

            VStack(spacing: DroppySpacing.sm) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(isTargeted ? electricBlue : AdaptiveColors.notchSurfaceSecondaryText)
                    .scaleEffect(isTargeted ? 1.1 : 1.0)

                VStack(spacing: 2) {
                    Text(isTargeted ? "Release to stage file" : "Drop a file here")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)

                    Text("Or choose one from your Mac")
                        .font(.system(size: 11))
                        .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
                }

                Button {
                    controller.presentFilePicker()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                        Text("Choose File…")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: electricBlue, size: .medium))
                .padding(.top, DroppySpacing.xs)
            }
            .padding(DroppySpacing.md)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            model.handleDrop(providers: providers)
        }
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
    }

    // MARK: - Validating State

    private var validatingView: some View {
        VStack(spacing: DroppySpacing.sm) {
            ProgressView()
                .controlSize(.regular)
            Text("Validating & staging locally…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
            Text("Enforcing 500 MB quota & computing SHA-256")
                .font(.system(size: 10))
                .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
        }
    }

    // MARK: - Staged State

    private func stagedView(info: StagedFileInfo) -> some View {
        VStack(spacing: DroppySpacing.md) {
            // File summary card
            HStack(spacing: DroppySpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous)
                        .fill(electricBlue.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 22))
                        .foregroundColor(electricBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(info.originalName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
                        .lineLimit(1)

                    HStack(spacing: DroppySpacing.sm) {
                        Text(ByteCountFormatter.string(fromByteCount: info.byteSize, countStyle: .file))
                        Text("•")
                        Text("SHA: \(info.sha256Hex.prefix(8))…")
                            .font(.system(size: 10).monospaced())
                    }
                    .font(.system(size: 11))
                    .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(DroppySpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )

            // Status chip
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("Staged locally in pending partition")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
            }

            Spacer(minLength: 0)

            // Actions row with truthful safety explanatory message
            VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                HStack(spacing: DroppySpacing.sm) {
                    Button("Change File") {
                        model.clearStaging()
                    }
                    .buttonStyle(DroppyQuietButtonStyle(size: .small))

                    Spacer(minLength: 0)

                    Button {
                        droplet.requestHandoff()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Continue in Blip")
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(DroppyQuietButtonStyle(size: .small))
                    .foregroundColor(BlipServicesAdapter.isDispatchCompiledIn ? electricBlue : AdaptiveColors.notchSurfaceTertiaryText)
                    .disabled(!BlipServicesAdapter.isDispatchCompiledIn)
                    .help(BlipServicesAdapter.isDispatchCompiledIn ? "Hand off to official Blip" : "Services dispatch compiled out in Phase 3 safety build")
                }

                // Truthful explanatory message required by Phase 3E
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 10))
                        .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
                    Text("File staged locally. Sending is not enabled in this test build.")
                        .font(.system(size: 10))
                        .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
                        .lineLimit(2)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Handoff States

    private func handoffRequestedView(info: StagedFileInfo) -> some View {
        VStack(spacing: DroppySpacing.sm) {
            ProgressView()
                .controlSize(.regular)
            Text("Calling official Blip Services…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
            Text(info.originalName)
                .font(.system(size: 10))
                .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
                .lineLimit(1)
        }
    }

    private func handoffAcknowledgedView(info: StagedFileInfo) -> some View {
        VStack(spacing: DroppySpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 28))

            Text("Handed Off to Blip")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)

            Text("Select your Android device in Blip's picker.")
                .font(.system(size: 11))
                .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)

            Button("Done") {
                model.clearStaging()
                controller.closePanel()
            }
            .buttonStyle(DroppyQuietButtonStyle(size: .small))
            .padding(.top, DroppySpacing.xs)
        }
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(spacing: DroppySpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 26))

            Text("Could Not Stage File")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button("Try Again") {
                model.clearStaging()
            }
            .buttonStyle(DroppyQuietButtonStyle(size: .small))
            .padding(.top, DroppySpacing.xs)
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            Text("Single file transfer")
                .font(.system(size: 10))
                .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)

            Spacer()

            statusFooterBadge
        }
    }

    @ViewBuilder
    private var statusFooterBadge: some View {
        switch model.state {
        case .empty:
            Text("Ready")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
        case .validating:
            Text("Validating…")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(electricBlue)
        case .staged:
            Text("Staged Locally")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(electricBlue)
        case .handoffRequested:
            Text("Handoff…")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(electricBlue)
        case .handoffAcknowledged:
            Text("In Blip")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.green)
        case .error:
            Text("Error")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.orange)
        }
    }
}
