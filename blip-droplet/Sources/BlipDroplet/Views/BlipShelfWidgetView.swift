//
//  BlipShelfWidgetView.swift
//  BlipDroplet
//
//  Shelf widget view for Blip in solo and compact/paired shelf layouts.
//

import SwiftUI
import DroppyKit

public struct BlipShelfWidgetView: View {
    @ObservedObject var droplet: BlipDroplet
    @ObservedObject var model: FileDropModel
    let context: ShelfWidgetContext

    private let electricBlue = Color(red: 0.05, green: 0.60, blue: 1.0)

    public init(droplet: BlipDroplet, context: ShelfWidgetContext) {
        self.droplet = droplet
        self.model = droplet.dropModel
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            headerRow

            contentBody

            Spacer(minLength: 0)
        }
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: DroppySpacing.xsm) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(electricBlue)

            Text("Blip")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

            Spacer(minLength: 0)

            // Status Badge
            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch model.state {
        case .empty:
            Text("Ready")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
        case .validating:
            Text("Validating…")
                .font(.system(size: 10, weight: .medium))
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

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        switch model.state {
        case .empty:
            DroppyFileDropTarget(model: model, isCompact: context.isCompact)

        case .validating:
            VStack(spacing: DroppySpacing.sm) {
                ProgressView()
                    .controlSize(.small)
                Text("Validating file attributes…")
                    .font(.system(size: 11))
                    .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .staged(let info):
            if context.isCompact {
                compactStagedView(info: info)
            } else {
                fullStagedView(info: info)
            }

        case .handoffRequested(let info):
            VStack(spacing: DroppySpacing.sm) {
                ProgressView()
                    .controlSize(.small)
                Text("Calling official Blip…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
                Text(info.originalName)
                    .font(.system(size: 10))
                    .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .handoffAcknowledged(let info):
            VStack(spacing: DroppySpacing.xsm) {
                HStack(spacing: DroppySpacing.xsm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    Text("Services handoff accepted")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
                }

                Text(info.originalName)
                    .font(.system(size: 10))
                    .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
                    .lineLimit(1)

                Text("Select your Android device in Blip's picker.")
                    .font(.system(size: 11))
                    .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)

                Button("Done") {
                    model.clearStaging()
                }
                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                .padding(.top, DroppySpacing.xs)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            VStack(spacing: DroppySpacing.xs) {
                HStack(spacing: DroppySpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text(message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
                        .lineLimit(2)
                }
                Button("Dismiss") {
                    model.clearStaging()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(electricBlue)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Staged Views

    private func compactStagedView(info: StagedFileInfo) -> some View {
        HStack(spacing: DroppySpacing.sm) {
            Image(systemName: "doc.fill")
                .font(.system(size: 20))
                .foregroundColor(electricBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.originalName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)
                    .lineLimit(1)

                Text(ByteCountFormatter.string(fromByteCount: info.byteSize, countStyle: .file))
                    .font(.system(size: 10))
                    .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
            }

            Spacer(minLength: 0)

            Button {
                model.clearStaging()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 18))
            .help("Clear staged file")
        }
        .padding(.horizontal, DroppySpacing.xs)
    }

    private func fullStagedView(info: StagedFileInfo) -> some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            // File item banner
            HStack(spacing: DroppySpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous)
                        .fill(electricBlue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 18))
                        .foregroundColor(electricBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.originalName)
                        .font(.system(size: 13, weight: .medium))
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
                    .fill(AdaptiveColors.buttonBackgroundAuto)
            )

            // Actions row
            HStack(spacing: DroppySpacing.sm) {
                Button("Cancel") {
                    model.clearStaging()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AdaptiveColors.notchSurfaceSecondaryText)
                .buttonStyle(DroppyQuietButtonStyle(size: .small))

                Spacer(minLength: 0)

                // Continue in Blip (Safety Gated in Phase 3)
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
        }
    }
}
