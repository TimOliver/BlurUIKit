// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "BlurUIKit",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "BlurUIKit",
            targets: ["BlurUIKit"]
        ),
    ],
    targets: [
        .target(
            name: "BlurUIKit",
            path: "BlurUIKit/"
        )
    ]
)
