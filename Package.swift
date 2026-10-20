// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BlurUIKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "BlurUIKit",
            targets: ["BlurUIKit"]
        ),
        .library(
            name: "BlurSwiftUI",
            targets: ["BlurSwiftUI"]
        ),
    ],
    targets: [
        .target(
            name: "BlurUIKit",
            path: "BlurUIKit/",
            exclude: ["SwiftUI"]
        ),
        .target(
            name: "BlurSwiftUI",
            dependencies: ["BlurUIKit"],
            path: "BlurUIKit/SwiftUI/"
        ),
        .testTarget(
            name: "BlurUIKitTests",
            dependencies: ["BlurUIKit", "BlurSwiftUI"],
            path: "Tests/BlurUIKitTests",
            // Rendering requires the example app's window scene and render server.
            exclude: ["ReflectionRenderingTests.swift", "VisualEffectRenderingTests.swift"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
