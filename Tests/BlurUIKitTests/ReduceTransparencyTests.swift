import XCTest
import UIKit
@testable import BlurUIKit

final class ReduceTransparencyTests: XCTestCase {

    @MainActor
    override func tearDown() {
        VariableBlurView.isReduceTransparencyEnabled = { UIAccessibility.isReduceTransparencyEnabled }
        super.tearDown()
    }

    // MARK: - Fallback

    @MainActor
    func testBlurIsShownWhenReduceTransparencyIsOff() throws {
        VariableBlurView.isReduceTransparencyEnabled = { false }

        try withBlur { blur in
            XCTAssertFalse(try effectView(in: blur).isHidden)
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.5)
        }
    }

    @MainActor
    func testBlurIsReplacedByFullDimmingWhenReduceTransparencyIsOn() throws {
        VariableBlurView.isReduceTransparencyEnabled = { true }

        try withBlur { blur in
            XCTAssertTrue(try effectView(in: blur).isHidden)
            XCTAssertEqual(try dimmingView(in: blur).alpha, 1.0)
        }
    }

    @MainActor
    func testDisabledDimmingStaysHiddenWhenReduceTransparencyIsOn() throws {
        VariableBlurView.isReduceTransparencyEnabled = { true }

        try withBlur { blur in
            blur.dimmingAlpha = nil
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.0)
        }
    }

    @MainActor
    func testReflectionKeepsItsBlurWhenReduceTransparencyIsOn() throws {
        VariableBlurView.isReduceTransparencyEnabled = { true }

        let reflection = ReflectionBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        reflection.layoutIfNeeded()
        let blur = try XCTUnwrap(reflection.subviews.compactMap { $0 as? VariableBlurView }.first)
        blur.layoutIfNeeded()

        XCTAssertFalse(try effectView(in: blur).isHidden)
    }

    // MARK: - Status Changes

    @MainActor
    func testStatusChangeNotificationSwapsBetweenBlurAndFallback() throws {
        var isEnabled = false
        VariableBlurView.isReduceTransparencyEnabled = { isEnabled }

        try withBlur { blur in
            XCTAssertFalse(try effectView(in: blur).isHidden)

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
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        blur.dimmingAlpha = .constant(alpha: 0.5)
        window.addSubview(blur)
        blur.layoutIfNeeded()
        try withExtendedLifetime(window) { try body(blur) }
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
