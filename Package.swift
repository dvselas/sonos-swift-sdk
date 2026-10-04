// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SonosSDK",
    platforms: [.iOS(.v17),
                .macOS(.v14)],
    products: [
        .library(
            name: "SonosSDK",
            targets: ["SonosSDK"]),
        // Observable household state over the players' local sockets.
        .library(
            name: "SonosLive",
            targets: ["SonosLive"]),
        // A simulated household for demo mode, UI tests and previews.
        .library(
            name: "SonosDemo",
            targets: ["SonosDemo"]),
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
        .target(
            name: "SonosLive",
            dependencies: ["SonosSDK"]),
        .target(
            name: "SonosDemo",
            dependencies: ["SonosSDK", "SonosLive"]),
        .testTarget(
            name: "SonosSDKTests",
            dependencies: ["SonosSDK"]),
        .testTarget(
            name: "SonosLiveTests",
            dependencies: ["SonosSDK", "SonosLive", "SonosDemo"]),
    ]
)
