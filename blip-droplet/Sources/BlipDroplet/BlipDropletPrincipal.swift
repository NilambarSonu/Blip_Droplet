//
//  BlipDropletPrincipal.swift
//  BlipDroplet
//
//  The principal class instantiated by Droppy's droplet bundle loader.
//

import Foundation
import DroppyKit

@objc(BlipDropletPrincipal)
public final class BlipDropletPrincipal: NSObject, DropletPrincipal {
    public override init() {
        super.init()
    }

    @MainActor
    public func makeDroplet() -> AnyObject {
        BlipDroplet()
    }
}
