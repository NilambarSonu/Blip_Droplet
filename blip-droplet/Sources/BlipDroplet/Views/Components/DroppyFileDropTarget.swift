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
        HStack(spacing: DroppySpacing.sm) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(model.isTargeted ? electricBlue : AdaptiveColors.notchSurfaceSecondaryText)

            Text(model.isTargeted ? "Release file" : "Drop file to Blip")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(model.isTargeted ? electricBlue : AdaptiveColors.notchSurfaceSecondaryText)
        }
        .padding(.horizontal, DroppySpacing.md)
    }

    private var fullContent: some View {
        VStack(spacing: DroppySpacing.xsm) {
            Image(systemName: model.isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(model.isTargeted ? electricBlue : AdaptiveColors.notchSurfaceSecondaryText)
                .scaleEffect(model.isTargeted ? 1.08 : 1.0)

            Text(model.isTargeted ? "Drop to stage locally" : "Drag file here to stage")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AdaptiveColors.notchSurfacePrimaryText)

            Text("Coordinates single file handoff to official Blip")
                .font(.system(size: 10))
                .foregroundColor(AdaptiveColors.notchSurfaceTertiaryText)
        }
        .padding(DroppySpacing.md)
    }
}
