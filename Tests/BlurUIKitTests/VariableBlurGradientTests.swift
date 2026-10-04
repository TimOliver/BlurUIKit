import XCTest
import UIKit
import SwiftUI
import BlurSwiftUI
@testable import BlurUIKit

final class VariableBlurGradientTests: XCTestCase {
    @MainActor
    func testClearExtensionUsesAdditionalSpaceWithoutEnlargingBlur() throws {
        try withBlur { blur in
            assertFraction(blur.dimmingClearExtension, 0.25)
            blur.dimmingClearExtension = .relative(fraction: 0.5)
            assertFraction(blur.dimmingClearExtension, 0.5)
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(blur).frame, CGRect(x: 0, y: -100, width: 200, height: 300))
            XCTAssertEqual(try effectView(blur).frame, blur.bounds)

            blur.dimmingClearExtension = .absolute(position: 40)
            guard case .absolute(let value) = blur.dimmingClearExtension else { return XCTFail("Expected points") }
            XCTAssertEqual(value, 40)
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(blur).frame, CGRect(x: 0, y: -40, width: 200, height: 240))
            blur.dimmingClearExtension = nil
            XCTAssertNil(blur.dimmingClearExtension)
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(blur).frame, blur.bounds)
        }
    }

    @MainActor
    func testBlurInsetReachesMaximumEarlyAndFillsTheContainer() throws {
        try withBlur { blur in
            blur.minimumBlurRadius = 6
            blur.maximumBlurRadius = 30
            blur.blurMaximumRadiusInset = .relative(fraction: 0.5)
            assertFraction(blur.blurMaximumRadiusInset, 0.5)
            blur.layoutIfNeeded()
            let image = try mask(blur)
            XCTAssertEqual(image.height, 200)
            XCTAssertEqual(alphas(image).first, 51)
            XCTAssertEqual(alphas(image)[100], 255)
            XCTAssertEqual(alphas(image).last, 255)
        }
    }

    @MainActor
    func testDimmingInsetStaysAtMidpointWhenExtensionChanges() throws {
        try withBlur { blur in
            blur.dimmingFullColorInset = .relative(fraction: 0.5)
            blur.dimmingClearExtension = .relative(fraction: 0.5)
            blur.layoutIfNeeded()
            assertFraction(blur.dimmingFullColorInset, 0.5)
            XCTAssertEqual(try fullColorPosition(blur), 100)

            blur.dimmingClearExtension = .relative(fraction: 1)
            blur.layoutIfNeeded()
            assertFraction(blur.dimmingFullColorInset, 0.5)
            XCTAssertEqual(try fullColorPosition(blur), 100)
        }
    }

    @MainActor
    func testAbsoluteAndRelativeInsetsProduceTheSameImage() throws {
        try withBlur { blur in
            blur.dimmingClearExtension = .relative(fraction: 0.5)
            blur.dimmingFullColorInset = .relative(fraction: 0.2)
            blur.layoutIfNeeded()
            let image = try dimmingImage(blur)
            blur.dimmingFullColorInset = .absolute(position: 40)
            blur.layoutIfNeeded()
            XCTAssertTrue((try dimmingImage(blur)) === image)
            XCTAssertEqual(try fullColorPosition(blur), 160)
        }
    }

    @MainActor
    func testBoundsRelativeInsetTracksResizing() throws {
        try withBlur { blur in
            blur.dimmingFullColorInset = .relative(fraction: 0.5)
            blur.dimmingClearExtension = .relative(fraction: 0.5)
            blur.layoutIfNeeded()
            blur.bounds.size.height = 300
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingImage(blur).height, 450)
            XCTAssertEqual(try fullColorPosition(blur), 150)
        }
    }

    @MainActor
    func testExtensionUsesTheClearEdgeInEveryDirection() throws {
        for direction in [VariableBlurView.Direction.down, .up, .left, .right] {
            try withBlur { blur in
                blur.direction = direction
                blur.dimmingClearExtension = .absolute(position: 40)
                blur.layoutIfNeeded()
                let frame = try dimmingView(blur).frame
                let vertical = direction == .up || direction == .down
                let reversed = direction == .up || direction == .right
                XCTAssertEqual(vertical ? frame.height : frame.width, 240)
                XCTAssertEqual(vertical ? frame.minY : frame.minX, reversed ? -40 : 0)
                let values = alphas(try dimmingImage(blur))
                XCTAssertEqual(values.first, reversed ? 0 : 255)
                XCTAssertEqual(values.last, reversed ? 255 : 0)
            }
        }
    }

    @MainActor
    func testInvalidExtensionsDoNotCrashAndUseNoExtraSpace() throws {
        try withBlur { blur in
            for value: CGFloat in [.infinity, .nan, -1, .greatestFiniteMagnitude] {
                blur.dimmingClearExtension = .relative(fraction: value)
                blur.layoutIfNeeded()
                XCTAssertEqual(try dimmingImage(blur).height, 200)
            }
            for value: CGFloat in [.infinity, .nan, -1, .greatestFiniteMagnitude] {
                blur.dimmingClearExtension = .absolute(position: value)
                blur.layoutIfNeeded()
                XCTAssertEqual(try dimmingImage(blur).height, 200)
            }
        }
    }

    @MainActor
    func testInsetsAreClampedToTheContainer() throws {
        try withBlur { blur in
            blur.dimmingClearExtension = nil
            for value: CGFloat in [.infinity, .nan, -1] {
                blur.blurMaximumRadiusInset = .relative(fraction: value)
                blur.dimmingFullColorInset = .relative(fraction: value)
                blur.layoutIfNeeded()
                XCTAssertEqual(alphas(try mask(blur)).first, 0)
                XCTAssertEqual(alphas(try dimmingImage(blur)).first, 0)
            }
            blur.blurMaximumRadiusInset = .absolute(position: 400)
            blur.dimmingFullColorInset = .relative(fraction: 2)
            blur.layoutIfNeeded()
            XCTAssertTrue(alphas(try mask(blur)).allSatisfy { $0 == 255 })
            XCTAssertTrue(alphas(try dimmingImage(blur)).allSatisfy { $0 == 255 })
        }
    }

    @MainActor
    func testReflectionExtensionDoesNotEnlargeBlurBackdrop() throws {
        let reflection = ReflectionBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 800))
        reflection.minimumBlurRadius = 3
        reflection.maximumBlurRadius = 60
        reflection.blurMaximumRadiusInset = .relative(fraction: 0.25)
        reflection.dimmingFullColorInset = .relative(fraction: 0.5)
        reflection.dimmingClearExtension = .absolute(position: 40)
        reflection.layoutIfNeeded()
        let blur = try XCTUnwrap(reflection.subviews.compactMap { $0 as? VariableBlurView }.first)
        blur.layoutIfNeeded()
        XCTAssertEqual(blur.frame, CGRect(x: 0, y: 400, width: 300, height: 400))
        XCTAssertFalse(blur.clipsToBounds)
        XCTAssertTrue(try effectView(blur).clipsToBounds)
        XCTAssertEqual(try effectView(blur).bounds.size, CGSize(width: 300, height: 400))
        XCTAssertEqual(try mask(blur).height, 400)
        XCTAssertEqual(try dimmingView(blur).frame, CGRect(x: 0, y: -40, width: 300, height: 440))
        XCTAssertEqual(try fullColorPosition(blur), 200)
    }

    @MainActor
    func testMinimumRadiusDoesNotAffectDimmingInAnyDirection() throws {
        for direction in [VariableBlurView.Direction.down, .up, .left, .right] {
            try withBlur { blur in
                blur.direction = direction
                blur.dimmingClearExtension = nil
                blur.minimumBlurRadius = 3
                blur.maximumBlurRadius = 60
                blur.dimmingAlpha = .constant(alpha: 0.9)
                blur.layoutIfNeeded()
                let reversed = direction == .up || direction == .right
                let maskValues = alphas(try mask(blur))
                let dimmingValues = alphas(try dimmingImage(blur))
                XCTAssertEqual(maskValues.first, reversed ? 12 : 255)
                XCTAssertEqual(maskValues.last, reversed ? 255 : 12)
                XCTAssertEqual(dimmingValues.first, reversed ? 0 : 255)
                XCTAssertEqual(dimmingValues.last, reversed ? 255 : 0)
                XCTAssertEqual(try dimmingView(blur).alpha, 0.9, accuracy: 0.001)
            }
        }
    }

    @MainActor
    func testFreshFilterRefreshReusesBothGradientImages() throws {
        try withBlur { blur in
            blur.layoutIfNeeded()
            let firstFilter = try filter(blur)
            let firstMask = try mask(blur)
            let firstDimming = try dimmingImage(blur)
            blur.setNeedsBlurFilterUpdate()
            blur.layoutIfNeeded()
            XCTAssertFalse((try filter(blur)) === firstFilter)
            XCTAssertTrue((try mask(blur)) === firstMask)
            XCTAssertTrue((try dimmingImage(blur)) === firstDimming)
        }
    }

    @MainActor
    func testReassigningCurrentValuesKeepsTheInstalledBlur() throws {
        try withBlur { blur in
            blur.minimumBlurRadius = 3
            blur.maximumBlurRadius = 30
            blur.blurMaximumRadiusInset = .relative(fraction: 0.25)
            blur.dimmingAlpha = .constant(alpha: 0.6)
            blur.dimmingFullColorInset = .absolute(position: 20)
            blur.dimmingClearExtension = .relative(fraction: 0.5)

            let reassignments: [(String, (VariableBlurView) -> Void)] = [
                ("direction", { $0.direction = .up }),
                ("minimumBlurRadius", { $0.minimumBlurRadius = 3 }),
                ("maximumBlurRadius", { $0.maximumBlurRadius = 30 }),
                ("blurMaximumRadiusInset", { $0.blurMaximumRadiusInset = .relative(fraction: 0.25) }),
                ("dimmingAlpha", { $0.dimmingAlpha = .constant(alpha: 0.6) }),
                ("dimmingFullColorInset", { $0.dimmingFullColorInset = .absolute(position: 20) }),
                ("dimmingClearExtension", { $0.dimmingClearExtension = .relative(fraction: 0.5) }),
            ]
            for (name, reassign) in reassignments {
                blur.layoutIfNeeded()
                let installedFilter = try filter(blur)
                let installedDimming = try dimmingView(blur).image
                reassign(blur)
                blur.layoutIfNeeded()
                XCTAssertTrue((try filter(blur)) === installedFilter, "\(name) rebuilt the blur filter")
                XCTAssertTrue((try dimmingView(blur).image) === installedDimming, "\(name) rebuilt the dimming image")
            }
        }
    }

    func testConfigurationTypesAreHashableAndSendable() {
        // Compile-time check. Swift 6 clients need these to be Sendable to store them in static
        // constants, though Sendable is only enforced when this target is built in Swift 6 mode.
        requireHashableAndSendable(VariableBlurView.Direction.self)
        requireHashableAndSendable(VariableBlurView.GradientSizing.self)
        requireHashableAndSendable(VariableBlurView.DimmingAlpha.self)
        XCTAssertEqual(VariableBlurView.GradientSizing.relative(fraction: 0.5), .relative(fraction: 0.5))
        XCTAssertNotEqual(VariableBlurView.GradientSizing.relative(fraction: 0.5), .absolute(position: 0.5))
        XCTAssertNotEqual(VariableBlurView.DimmingAlpha.constant(alpha: 0.5),
                          .interfaceStyle(lightModeAlpha: 0.5, darkModeAlpha: 0.5))
    }

    @MainActor
    func testSwiftUIModifiersConfigureAndUpdateTheSameProperties() async throws {
        let root = VariableBlur(direction: .up)
            .minimumBlurRadius(3)
            .maximumBlurRadius(60)
            .blurMaximumRadiusInset(.relative(fraction: 0.25))
            .dimmingTintColor(.red)
            .dimmingAlpha(.constant(alpha: 0.9))
            .dimmingClearExtension(.relative(fraction: 0.5))
            .dimmingFullColorInset(.relative(fraction: 0.5))
        let controller = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        let blur = try XCTUnwrap(findBlur(in: controller.view))
        XCTAssertEqual(try fullColorPosition(blur), blur.bounds.height * 0.5, accuracy: 1)
        assertFraction(blur.blurMaximumRadiusInset, 0.25)
        assertFraction(blur.dimmingClearExtension, 0.5)

        controller.rootView = root.dimmingFullColorInset(.relative(fraction: 0.25))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(try fullColorPosition(blur), blur.bounds.height * 0.75, accuracy: 1)
    }

    @MainActor
    func testSwiftUIUpdateWithUnchangedConfigurationKeepsTheInstalledBlur() async throws {
        // Builds a fresh description each time, as a parent view's body evaluation does.
        func makeRoot() -> VariableBlur {
            VariableBlur(direction: .up)
                .minimumBlurRadius(3)
                .maximumBlurRadius(60)
                .blurMaximumRadiusInset(.relative(fraction: 0.25))
                .dimmingTintColor(.red)
                .dimmingAlpha(.constant(alpha: 0.9))
                .dimmingClearExtension(.relative(fraction: 0.5))
                .dimmingFullColorInset(.relative(fraction: 0.5))
        }
        let controller = UIHostingController(rootView: makeRoot())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        let blur = try XCTUnwrap(findBlur(in: controller.view))
        let installedFilter = try filter(blur)
        let installedDimming = try dimmingView(blur).image

        controller.rootView = makeRoot()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue((try filter(blur)) === installedFilter)
        XCTAssertTrue((try dimmingView(blur).image) === installedDimming)
    }

    @MainActor
    private func withBlur(_ body: (VariableBlurView) throws -> Void) rethrows {
        let host = UIView()
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        blur.direction = .up
        host.addSubview(blur)
        try withExtendedLifetime(host) { try body(blur) }
    }

    private func requireHashableAndSendable<T: Hashable & Sendable>(_: T.Type) {}

    private func assertFraction(_ sizing: VariableBlurView.GradientSizing?, _ expected: CGFloat,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard case .relative(let value) = sizing else { return XCTFail("Expected fraction", file: file, line: line) }
        XCTAssertEqual(value, expected, accuracy: 0.000001, file: file, line: line)
    }

    @MainActor
    private func findBlur(in view: UIView) -> VariableBlurView? {
        if let blur = view as? VariableBlurView { return blur }
        return view.subviews.lazy.compactMap { self.findBlur(in: $0) }.first
    }

    @MainActor
    private func fullColorPosition(_ blur: VariableBlurView) throws -> CGFloat {
        let image = try dimmingImage(blur)
        let firstFullPixel = try XCTUnwrap(alphas(image).firstIndex(of: 255))
        return CGFloat(firstFullPixel) + (try dimmingView(blur).frame.minY)
    }

    @MainActor
    private func dimmingView(_ blur: VariableBlurView) throws -> UIImageView {
        try XCTUnwrap(blur.subviews.compactMap { $0 as? UIImageView }.first)
    }

    @MainActor
    private func dimmingImage(_ blur: VariableBlurView) throws -> CGImage {
        try XCTUnwrap(dimmingView(blur).image?.cgImage)
    }

    @MainActor
    private func effectView(_ blur: VariableBlurView) throws -> UIVisualEffectView {
        try XCTUnwrap(blur.subviews.compactMap { $0 as? UIVisualEffectView }.first)
    }

    @MainActor
    private func filter(_ blur: VariableBlurView) throws -> NSObject {
        let backdrop = try XCTUnwrap(BlurFilterProvider.findSubview(in: effectView(blur), containing: "backdrop"))
        return try XCTUnwrap(backdrop.layer.filters?.first as? NSObject)
    }

    @MainActor
    private func mask(_ blur: VariableBlurView) throws -> CGImage {
        try XCTUnwrap(filter(blur).value(forKey: "inputMaskImage")) as! CGImage
    }

    private func alphas(_ image: CGImage) -> [UInt8] {
        let data = image.dataProvider!.data!
        let bytes = CFDataGetBytePtr(data)!
        return (0..<(image.width * image.height)).map { index in
            let x = index % image.width
            let y = index / image.width
            return bytes[y * image.bytesPerRow + x * 2 + 1]
        }
    }
}
