// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "BlurUIKit",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "BlurUIKit",
            targets: ["BlurUIKit"]
        ),
    ],
    targets: [
        .target(
            name: "BlurUIKit",
            path: "BlurUIKit/",
        )
    ]
)
