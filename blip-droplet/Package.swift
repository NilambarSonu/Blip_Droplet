// swift-tools-version: 6.0
//
//  Package.swift
//  BlipDroplet
//

import PackageDescription

let package = Package(
    name: "BlipDroplet",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BlipDroplet", type: .dynamic, targets: ["BlipDroplet"])
    ],
    dependencies: [
        .package(url: "https://gitlab.com/droppyformac1/droppykit.git", exact: "1.20.1")
    ],
    targets: [
        .target(
            name: "BlipDroplet",
            dependencies: [.product(name: "DroppyKit", package: "droppykit")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "BlipDropletHarness",
            dependencies: [
                "BlipDroplet",
                .product(name: "DroppyKitHarness", package: "droppykit")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "BlipDropletTests",
            dependencies: ["BlipDroplet"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
