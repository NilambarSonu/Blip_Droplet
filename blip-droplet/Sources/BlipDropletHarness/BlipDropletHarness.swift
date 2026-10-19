//
//  BlipDropletHarness.swift
//  BlipDropletHarness
//
//  Standalone DroppyKit development harness entry point.
//

import DroppyKit
import DroppyKitHarness
import BlipDroplet

@main
struct BlipDropletHarness: DropletHarnessApp {
    static func makeDroplet() -> any Droplet {
        BlipDroplet()
    }
}
