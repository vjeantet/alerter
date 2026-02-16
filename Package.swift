// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Alerter",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "BundleHook",
            path: "Sources/BundleHook",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "alerter",
            dependencies: [
                "BundleHook",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/Alerter",
            exclude: ["Info.plist"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-suppress-warnings"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Alerter/Info.plist",
                ]),
            ]
        ),
    ]
)
