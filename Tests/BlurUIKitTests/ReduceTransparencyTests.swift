import XCTest
import UIKit
import SwiftUI
#if SWIFT_PACKAGE
import BlurSwiftUI
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class ReduceTransparencyTests: XCTestCase {

    /// Replaces the system Reduce Transparency setting for the rest of the current test.
    @MainActor
    private func stubReduceTransparency(_ isEnabled: @escaping () -> Bool) {
        VariableBlurView.isReduceTransparencyEnabled = isEnabled
        addTeardownBlock { @MainActor in
            VariableBlurView.isReduceTransparencyEnabled = { UIAccessibility.isReduceTransparencyEnabled }
        }
    }

    // MARK: - Fallback

    @MainActor
    func testReflectionKeepsItsBlurWhenReduceTransparencyIsOn() throws {
        stubReduceTransparency { true }

        let reflection = ReflectionBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        reflection.layoutIfNeeded()
        let blur = try XCTUnwrap(reflection.subviews.compactMap { $0 as? VariableBlurView }.first)
        blur.layoutIfNeeded()

        XCTAssertFalse(try effectView(in: blur).isHidden)
    }

    // MARK: - Opting Out

    @MainActor
    func testFallbackRespectsOptingOutAndDisabledDimming() throws {
        stubReduceTransparency { true }

        try withBlur { blur in
            XCTAssertTrue(try effectView(in: blur).isHidden, "Initial fallback")
            XCTAssertEqual(try dimmingView(in: blur).alpha, 1.0, "Initial fallback")

            blur.replacesBlurWhenReducingTransparency = false
            blur.layoutIfNeeded()
            XCTAssertFalse(try effectView(in: blur).isHidden, "Opting out")
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.5, "Opting out")

            blur.replacesBlurWhenReducingTransparency = true
            blur.layoutIfNeeded()
            XCTAssertTrue(try effectView(in: blur).isHidden, "Restoring the fallback")
            XCTAssertEqual(try dimmingView(in: blur).alpha, 1.0, "Restoring the fallback")

            blur.dimmingAlpha = nil
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.0, "Disabled dimming")
        }
    }

    @MainActor
    func testSwiftUIModifierControlsTheReduceTransparencyFallback() async throws {
        stubReduceTransparency { true }

        let root = VariableBlur().replacesBlurWhenReducingTransparency(false)
        let controller = UIHostingController(rootView: root)
        let window = makePinnedWindow()
        window.rootViewController = controller
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)

        let blur = try XCTUnwrap(findBlur(in: controller.view))
        XCTAssertFalse(blur.replacesBlurWhenReducingTransparency)
        XCTAssertFalse(try effectView(in: blur).isHidden)

        controller.rootView = VariableBlur()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(blur.replacesBlurWhenReducingTransparency)
        XCTAssertTrue(try effectView(in: blur).isHidden)
    }

    // MARK: - Status Changes

    @MainActor
    func testStatusChangeNotificationSwapsBetweenBlurAndFallback() throws {
        var isEnabled = false
        stubReduceTransparency { isEnabled }

        try withBlur { blur in
            XCTAssertFalse(try effectView(in: blur).isHidden)
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.5, "Initial normal state")

            isEnabled = true
            NotificationCenter.default.post(name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
            blur.layoutIfNeeded()
            XCTAssertTrue(try effectView(in: blur).isHidden)
            XCTAssertEqual(try dimmingView(in: blur).alpha, 1.0)

            isEnabled = false
            NotificationCenter.default.post(name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
            blur.layoutIfNeeded()
            XCTAssertFalse(try effectView(in: blur).isHidden)
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.5)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func withBlur(_ body: (VariableBlurView) throws -> Void) rethrows {
        let window = makePinnedWindow()
        defer { window.isHidden = true }
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        blur.dimmingAlpha = .constant(alpha: 0.5)
        window.addSubview(blur)
        blur.layoutIfNeeded()
        try withExtendedLifetime(window) { try body(blur) }
    }

    @MainActor
    private func findBlur(in view: UIView) -> VariableBlurView? {
        if let blur = view as? VariableBlurView { return blur }
        return view.subviews.lazy.compactMap { self.findBlur(in: $0) }.first
    }

    @MainActor
    private func effectView(in blur: VariableBlurView) throws -> UIVisualEffectView {
        try XCTUnwrap(blur.subviews.compactMap { $0 as? UIVisualEffectView }.first)
    }

    @MainActor
    private func dimmingView(in blur: VariableBlurView) throws -> UIImageView {
        try XCTUnwrap(blur.subviews.compactMap { $0 as? UIImageView }.first)
    }
}
