//
//  DroppyFileDropTarget.swift
//  BlipDroplet
//
//  Reusable native Droppy-styled file drop zone.
//

import SwiftUI
import DroppyKit
import UniformTypeIdentifiers

public struct DroppyFileDropTarget: View {
    @ObservedObject var model: FileDropModel
    let isCompact: Bool

    // Electric blue signature accent
    private let electricBlue = Color(red: 0.05, green: 0.60, blue: 1.0)

    public init(model: FileDropModel, isCompact: Bool) {
        self.model = model
        self.isCompact = isCompact
    }

    public var body: some View {
        ZStack {
            // Drop boundary card
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .fill(model.isTargeted ? electricBlue.opacity(0.12) : AdaptiveColors.buttonBackgroundAuto)
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .strokeBorder(
                            model.isTargeted ? electricBlue : AdaptiveColors.subtleBorderAuto,
                            style: StrokeStyle(lineWidth: model.isTargeted ? 1.5 : 1, dash: model.isTargeted ? [] : [4, 4])
                        )
                )

            // Content affordance
            if isCompact {
                compactContent
            } else {
                fullContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $model.isTargeted) { providers in
            model.handleDrop(providers: providers)
        }
        .animation(.easeInOut(duration: 0.18), value: model.isTargeted)
    }

    private var compactContent: some View {
        Button {
            BlipPanelController.shared.openPanel()
        } label: {
            HStack(spacing: DroppySpacing.sm) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(model.isTargeted ? electricBlue : AdaptiveColors.notchSurfaceSecondaryText)

                Text(model.isTargeted ? "Release to stage" : "Open Blip Send Panel")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(model.isTargeted ? electricBlue : AdaptiveColors.notchSurfaceSecondaryText)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DroppySpacing.md)
    }

    private var fullContent: some View {
        VStack(spacing: DroppySpacing.xsm) {
            Image(systemName: model.isTargeted ? "arrow.down.circle.fill" : "paperplane.circle.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(model.isTargeted ? electricBlue : AdaptiveColors.notchSurfaceSecondaryText)
                .scaleEffect(model.isTargeted ? 1.08 : 1.0)

            Text(model.isTargeted ? "Drop to stage locally" : "Send File to Android")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)

            Text("Drop file here or open the floating panel")
                .font(.system(size: 10))
                .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)

            Button {
                BlipPanelController.shared.openPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 9))
                    Text("Open Send Panel")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(DroppyQuietButtonStyle(size: .small))
            .padding(.top, 2)
        }
        .padding(DroppySpacing.md)
    }
}
