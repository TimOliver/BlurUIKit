import XCTest
import UIKit
@testable import BlurUIKitExample

/// Hosted in the example app, like ReflectionRenderingTests, so that backdrops render.
final class VisualEffectRenderingTests: XCTestCase {

    /// Both filter families: a tinted blur, and a material whose tint lives in its filters.
    private let styles: [UIBlurEffect.Style] = [.regular, .systemMaterial]

    @MainActor
    func testZeroRadiusRendersTheContentUnchanged() async throws {
        for style in styles {
            let host = try makeHost()
            defer { host.close() }
            let bare = host.addFixture(at: CGPoint(x: 20, y: 120))
            let covered = host.addFixture(at: CGPoint(x: 20, y: 260))
            let effectView = UIVisualEffectView(effect: UIBlurEffect(style: style))
            effectView.frame = covered.frame
            host.root.view.addSubview(effectView)
            effectView.blurEffectRadius = 0
            effectView.dimmingAlpha = 0

            let snapshot = try await host.capture()
            for x in stride(from: 4, to: 200, by: 8) {
                for y in [20, 60] {
                    let expected = snapshot.pixel(x: Int(bare.frame.minX) + x, y: Int(bare.frame.minY) + y)
                    let actual = snapshot.pixel(x: Int(covered.frame.minX) + x, y: Int(covered.frame.minY) + y)
                    for (channel, (actualValue, expectedValue)) in zip(["red", "green", "blue"],
                                                                        zip(actual, expected)) {
                        XCTAssertEqual(actualValue, expectedValue, accuracy: 0.04,
                                       "\(style.rawValue) \(channel) at (\(x), \(y))")
                    }
                }
            }
        }
    }

    // MARK: - Hosted Rendering

    @MainActor
    private struct Host {
        let window: UIWindow
        let root: UIViewController
        let previousKeyWindow: UIWindow?

        /// A 200x80 fixture of coloured bands, so blur, saturation and brightness changes all show.
        func addFixture(at origin: CGPoint) -> UIImageView {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 80)).image { context in
                let colors: [UIColor] = [.red, UIColor(white: 0.5, alpha: 1), UIColor(red: 0.2, green: 0.6, blue: 0.5, alpha: 1),
                                         .white, UIColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 1), .black,
                                         UIColor(red: 0.3, green: 0.3, blue: 0.9, alpha: 1), UIColor(white: 0.8, alpha: 1),
                                         .green, UIColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)]
                for (index, color) in colors.enumerated() {
                    color.setFill()
                    context.fill(CGRect(x: index * 20, y: 0, width: 20, height: 80))
                }
            }
            let imageView = UIImageView(image: image)
            imageView.frame = CGRect(origin: origin, size: image.size)
            root.view.addSubview(imageView)
            return imageView
        }

        func capture() async throws -> Snapshot {
            window.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 300_000_000)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            var rendered = false
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertTrue(rendered, "A failed capture cannot validate rendering")
            return try Snapshot(image: image)
        }

        func close() {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
    }

    @MainActor
    private func makeHost() throws -> Host {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive },
            "Run this suite in the example app, with an active window scene.")
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        root.view.backgroundColor = .black
        window.rootViewController = root
        window.overrideUserInterfaceStyle = .light
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.makeKeyAndVisible()
        return Host(window: window, root: root, previousKeyWindow: previousKeyWindow)
    }

    private struct Snapshot {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init(image: UIImage) throws {
            let image = try XCTUnwrap(image.cgImage)
            width = image.width
            height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress,
                    width: image.width, height: image.height, bitsPerComponent: 8,
                    bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            self.bytes = bytes
        }

        /// The red, green and blue components at a point, from 0 to 1.
        func pixel(x: Int, y: Int) -> [Double] {
            let offset = (y * width + x) * 4
            return (0..<3).map { Double(bytes[offset + $0]) / 255 }
        }
    }
}
