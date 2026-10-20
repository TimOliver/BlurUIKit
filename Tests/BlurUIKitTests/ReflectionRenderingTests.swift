import XCTest
import UIKit
@testable import BlurUIKitExample

/// These tests need the example app's window scene and render server. Unhosted package
/// tests cannot capture a UIVisualEffectView backdrop reliably with drawHierarchy.
final class ReflectionRenderingTests: XCTestCase {
    @MainActor
    func testReflectionFlipsVerticallyAfterResizingAndChangingBoundsOrigin() async throws {
        let host = try makeHost()
        defer { host.close() }
        host.reflection.contentView = UIImageView(image: quadrants())

        for size in [CGSize(width: 280, height: 400),
                     CGSize(width: 330, height: 400),
                     CGSize(width: 260, height: 500)] {
            host.reflection.frame.size = size
            let snapshot = try await capture(host, name: "quadrants-\(size)")
            assertQuadrants(snapshot, in: host.reflection)
        }

        host.reflection.bounds.origin = CGPoint(x: 37, y: 29)
        let snapshot = try await capture(host, name: "quadrants-shifted-bounds")
        assertQuadrants(snapshot, in: host.reflection)
    }

    @MainActor
    func testBlurSoftensOnlyTheReflectedContent() async throws {
        let host = try makeHost()
        defer { host.close() }
        host.reflection.minimumBlurRadius = 12
        host.reflection.maximumBlurRadius = 12
        host.reflection.contentView = UIImageView(image: stripes())

        let snapshot = try await capture(host, name: "blurred-stripes")
        // Four-point stripes: x=98 is black and x=102 is white. Check both an interior
        // row and one just above the seam so backdrop overflow cannot blur the source.
        for y: CGFloat in [80, 196] {
            let dark = snapshot.pixel(in: host.reflection, x: 98, y: y).red
            let light = snapshot.pixel(in: host.reflection, x: 102, y: y).red
            XCTAssertGreaterThan(light - dark, 0.8, "Source detail must remain sharp")
        }
        let reflectedDark = snapshot.pixel(in: host.reflection, x: 98, y: 320).red
        let reflectedLight = snapshot.pixel(in: host.reflection, x: 102, y: 320).red
        XCTAssertLessThan(abs(reflectedLight - reflectedDark), 0.2,
                          "The reflected stripes must actually be blurred")
        let meanIntensity = (reflectedDark + reflectedLight) / 2
        XCTAssertGreaterThan(meanIntensity, 0.25, "The reflection must not disappear into the background")
        XCTAssertLessThan(meanIntensity, 0.75)
    }

    @MainActor
    func testReflectionOpacityDoesNotFadeTheSource() async throws {
        let host = try makeHost()
        defer { host.close() }
        host.reflection.contentView.backgroundColor = .white
        host.reflection.reflectionAlpha = 0.5
        var snapshot = try await capture(host, name: "half-opacity-reflection")
        assertColor(.white, snapshot.pixel(in: host.reflection, x: 140, y: 100))
        let reflectedIntensity = snapshot.pixel(in: host.reflection, x: 140, y: 300).red
        XCTAssertGreaterThan(reflectedIntensity, 0.3)
        XCTAssertLessThan(reflectedIntensity, 0.8)

        host.reflection.reflectionAlpha = 0
        snapshot = try await capture(host, name: "zero-opacity-reflection")
        assertColor(.white, snapshot.pixel(in: host.reflection, x: 140, y: 100))
        assertColor(.black, snapshot.pixel(in: host.reflection, x: 140, y: 300))
    }

    @MainActor
    func testScrollingReplacementAndVisibilityRefreshTheBlurredReflection() async throws {
        let host = try makeHost(blurRadius: 20)
        defer { host.close() }
        let scrollView = UIScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentSize = CGSize(width: 560, height: 200)
        for (index, color) in [UIColor.red, .blue].enumerated() {
            let page = UIView(frame: CGRect(x: index * 280, y: 0, width: 280, height: 200))
            page.backgroundColor = color
            scrollView.addSubview(page)
        }
        host.reflection.contentView = scrollView
        var snapshot = try await capture(host, name: "lifecycle-initial-red")
        assertSolid(.red, snapshot: snapshot, reflection: host.reflection)

        scrollView.contentOffset.x = 280
        host.reflection.setNeedsReflectionUpdate()
        snapshot = try await capture(host, name: "lifecycle-scrolled-blue")
        assertSolid(.blue, snapshot: snapshot, reflection: host.reflection)

        let replacement = UIView()
        replacement.backgroundColor = .red
        host.reflection.contentView = replacement
        snapshot = try await capture(host, name: "lifecycle-replaced-red")
        assertSolid(.red, snapshot: snapshot, reflection: host.reflection)

        host.reflection.isReflectionHidden = true
        snapshot = try await capture(host, name: "lifecycle-hidden-reflection")
        assertColor(.red, snapshot.pixel(in: host.reflection, x: 140, y: 100))
        assertColor(.black, snapshot.pixel(in: host.reflection, x: 140, y: 300))

        replacement.backgroundColor = .blue
        host.reflection.isReflectionHidden = false
        snapshot = try await capture(host, name: "lifecycle-reshown-blue")
        assertSolid(.blue, snapshot: snapshot, reflection: host.reflection)
    }

    @MainActor
    func testDimmingExtensionRendersBehindTheSource() async throws {
        let host = try makeHost()
        defer { host.close() }
        host.reflection.dimmingTintColor = .red
        host.reflection.dimmingAlpha = .constant(alpha: 1)
        host.reflection.dimmingClearExtension = .relative(fraction: 0.5)
        host.reflection.dimmingFullColorInset = .relative(fraction: 1)
        let patch = UIView(frame: CGRect(x: 100, y: 150, width: 80, height: 40))
        patch.backgroundColor = .white
        host.reflection.contentView.addSubview(patch)

        let snapshot = try await capture(host, name: "dimming-behind-source")
        assertColor(.white, snapshot.pixel(in: host.reflection, x: 140, y: 170))
        let extendedDimming = snapshot.pixel(in: host.reflection, x: 40, y: 190)
        XCTAssertGreaterThan(extendedDimming.red, 0.8)
        XCTAssertLessThan(extendedDimming.green, 0.1)
        assertColor(.black, snapshot.pixel(in: host.reflection, x: 40, y: 80))
    }

    @MainActor
    func testUnavailableFilterKeepsNativeMaterialAndRecoversOnLaterLayout() async throws {
        let originalProvider = BlurFilterProvider.shared
        let originalReduceTransparency = VariableBlurView.isReduceTransparencyEnabled
        defer {
            BlurFilterProvider.shared = originalProvider
            VariableBlurView.isReduceTransparencyEnabled = originalReduceTransparency
        }
        VariableBlurView.isReduceTransparencyEnabled = { false }
        BlurFilterProvider.shared = BlurFilterProvider(discover: { nil })

        let host = try makeHost()
        defer { host.close() }
        host.reflection.removeFromSuperview()
        let rootView = try XCTUnwrap(host.window.rootViewController?.view)
        let fixtureImage = stripes()
        let nativeFixture = UIImageView(image: fixtureImage)
        nativeFixture.frame = CGRect(x: 24, y: 100, width: 280, height: 200)
        rootView.addSubview(nativeFixture)
        let fixture = UIImageView(image: fixtureImage)
        fixture.frame = CGRect(x: 24, y: 320, width: 280, height: 200)
        rootView.addSubview(fixture)

        let nativeBlur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        nativeBlur.frame = nativeFixture.frame
        rootView.addSubview(nativeBlur)

        let blur = VariableBlurView(frame: fixture.frame)
        blur.minimumBlurRadius = 0
        blur.maximumBlurRadius = 0
        blur.dimmingTintColor = nil
        rootView.addSubview(blur)
        let fallbackSnapshot = try await capture(host, name: "native-material-and-unavailable-filter")
        let nativeDark = fallbackSnapshot.pixel(in: nativeFixture, x: 98, y: 80).red
        let nativeLight = fallbackSnapshot.pixel(in: nativeFixture, x: 102, y: 80).red
        XCTAssertLessThan(abs(nativeLight - nativeDark), 0.2)
        XCTAssertGreaterThan((nativeDark + nativeLight) / 2, 0.25)

        // Compare matching positions in identical fixtures captured in the same frame.
        // Blur alone would miss a fallback that accidentally hides UIKit's material tint.
        for y: CGFloat in [80, 120] {
            for x: CGFloat in [98, 102] {
                let expected = fallbackSnapshot.pixel(in: nativeFixture, x: x, y: y)
                let actual = fallbackSnapshot.pixel(in: fixture, x: x, y: y)
                XCTAssertEqual(actual.red, expected.red, accuracy: 0.03)
                XCTAssertEqual(actual.green, expected.green, accuracy: 0.03)
                XCTAssertEqual(actual.blue, expected.blue, accuracy: 0.03)
            }
        }

        BlurFilterProvider.shared = originalProvider
        blur.setNeedsLayout()
        let recoveredSnapshot = try await capture(host, name: "filter-recovery-zero-radius")
        for y: CGFloat in [80, 120] {
            let dark = recoveredSnapshot.pixel(in: fixture, x: 98, y: y)
            let light = recoveredSnapshot.pixel(in: fixture, x: 102, y: y)
            assertColor(.black, dark)
            assertColor(.white, light)
            XCTAssertGreaterThan(light.red - dark.red, 0.8,
                                 "A later layout must replace native fallback with the requested zero-radius blur")
        }

        let effect = try XCTUnwrap(blur.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        let backdrop = try XCTUnwrap(BlurFilterProvider.findSubview(in: effect, containing: "backdrop"))
        let filter = try XCTUnwrap(backdrop.layer.filters?.first as? NSObject)
        XCTAssertEqual(filter.value(forKey: "name") as? String, "variableBlur")
        XCTAssertEqual(filter.value(forKey: "inputRadius") as? CGFloat, 0)
        let overlay = try XCTUnwrap(BlurFilterProvider.findSubview(in: effect, containing: "subview"))
        XCTAssertTrue(overlay.isHidden, "Recovery must install the custom blur and hide the native material tint")
    }

    // MARK: - Hosted Rendering

    @MainActor
    private struct Host {
        let window: UIWindow
        let previousKeyWindow: UIWindow?
        let reflection: ReflectionBlurView

        func close() {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
    }

    @MainActor
    private func makeHost(blurRadius: CGFloat = 0) throws -> Host {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive },
            "Run this suite in the example app, with an active window scene.")
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .light
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.makeKeyAndVisible()

        let reflection = ReflectionBlurView(frame: CGRect(x: 24, y: 100, width: 280, height: 400))
        reflection.reflectionAlpha = 1
        reflection.minimumBlurRadius = blurRadius
        reflection.maximumBlurRadius = blurRadius
        reflection.dimmingTintColor = nil
        controller.view.addSubview(reflection)
        return Host(window: window, previousKeyWindow: previousKeyWindow, reflection: reflection)
    }

    @MainActor
    private func capture(_ host: Host, name: String) async throws -> Snapshot {
        host.window.layoutIfNeeded()
        // Yield to the render server; inspecting the model/filter tree alone does not
        // establish that the reflected pixels or the backdrop capture have updated.
        try await Task.sleep(nanoseconds: 300_000_000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        var rendered = false
        let image = UIGraphicsImageRenderer(bounds: host.window.bounds, format: format).image { _ in
            rendered = host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
        XCTAssertTrue(rendered, "A failed capture cannot validate reflection rendering")
        return try Snapshot(image: image, window: host.window)
    }

    @MainActor
    private func quadrants() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 280, height: 200)).image { context in
            for (index, color) in [UIColor.red, .green, .blue, .yellow].enumerated() {
                color.setFill()
                context.fill(CGRect(x: (index % 2) * 140, y: (index / 2) * 100, width: 140, height: 100))
            }
        }
    }

    @MainActor
    private func stripes() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 280, height: 200)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 280, height: 200))
            UIColor.black.setFill()
            for x in stride(from: 0, to: 280, by: 8) {
                context.fill(CGRect(x: x, y: 0, width: 4, height: 200))
            }
        }
    }

    // MARK: - Pixel Assertions

    @MainActor
    private func assertQuadrants(_ snapshot: Snapshot, in reflection: ReflectionBlurView,
                                 file: StaticString = #filePath, line: UInt = #line) {
        for (row, colors) in [[Pixel.red, .green], [.blue, .yellow],
                              [.blue, .yellow], [.red, .green]].enumerated() {
            for (column, color) in colors.enumerated() {
                assertColor(color, snapshot.pixel(in: reflection,
                    x: reflection.bounds.width * (column == 0 ? 0.25 : 0.75),
                    y: reflection.bounds.height * (CGFloat(row) + 0.5) / 4),
                    file: file, line: line)
            }
        }
    }

    @MainActor
    private func assertSolid(_ color: Pixel, snapshot: Snapshot, reflection: ReflectionBlurView,
                             file: StaticString = #filePath, line: UInt = #line) {
        assertColor(color, snapshot.pixel(in: reflection, x: 140, y: 100), file: file, line: line)
        assertColor(color, snapshot.pixel(in: reflection, x: 140, y: 300), file: file, line: line)
    }

    private func assertColor(_ expected: Pixel, _ actual: Pixel,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.red, expected.red, accuracy: 0.15, file: file, line: line)
        XCTAssertEqual(actual.green, expected.green, accuracy: 0.15, file: file, line: line)
        XCTAssertEqual(actual.blue, expected.blue, accuracy: 0.15, file: file, line: line)
    }

    private struct Pixel {
        let red: Double
        let green: Double
        let blue: Double
        static let red = Pixel(red: 1, green: 0, blue: 0)
        static let green = Pixel(red: 0, green: 1, blue: 0)
        static let blue = Pixel(red: 0, green: 0, blue: 1)
        static let yellow = Pixel(red: 1, green: 1, blue: 0)
        static let white = Pixel(red: 1, green: 1, blue: 1)
        static let black = Pixel(red: 0, green: 0, blue: 0)
    }

    @MainActor
    private struct Snapshot {
        let window: UIWindow
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init(image: UIImage, window: UIWindow) throws {
            self.window = window
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

        func pixel(in view: UIView, x: CGFloat, y: CGFloat) -> Pixel {
            let point = view.convert(CGPoint(x: view.bounds.minX + x, y: view.bounds.minY + y), to: window)
            let column = min(max(Int(point.x), 0), width - 1)
            let row = min(max(Int(point.y), 0), height - 1)
            let offset = (row * width + column) * 4
            return Pixel(red: Double(bytes[offset]) / 255, green: Double(bytes[offset + 1]) / 255,
                         blue: Double(bytes[offset + 2]) / 255)
        }
    }
}
