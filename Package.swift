// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SonosSDK",
    platforms: [.iOS(.v15),
                .macOS(.v12)],
    products: [
        .library(
            name: "SonosSDK",
            targets: ["SonosSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stleamist/BetterSafariView.git", .upToNextMajor(from: "2.3.1")),
    ],
    targets: [
        .target(
            name: "SonosSDK",
            dependencies: [
                "BetterSafariView",
            ]),
        .testTarget(
            name: "SonosSDKTests",
            dependencies: ["SonosSDK"]),
    ]
)
