import XCTest
import UIKit
@testable import BlurUIKit

final class IncreaseContrastTests: XCTestCase {

    // MARK: - Dimming Strength

    @MainActor
    func testDefaultDimmingIsStrengthenedInLightMode() throws {
        try withBlur(style: .light, contrast: .high) { blur in
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.75, accuracy: 0.001)
        }
    }

    @MainActor
    func testDefaultDimmingIsStrengthenedInDarkMode() throws {
        try withBlur(style: .dark, contrast: .high) { blur in
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.625, accuracy: 0.001)
        }
    }

    @MainActor
    func testConstantDimmingIsStrengthened() throws {
        try withBlur(style: .light, contrast: .high) { blur in
            blur.dimmingAlpha = .constant(alpha: 0.9)
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.95, accuracy: 0.001)
        }
    }

    @MainActor
    func testNormalContrastLeavesDimmingUnchanged() throws {
        try withBlur(style: .light, contrast: .normal) { blur in
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.5, accuracy: 0.001)
        }
    }

    @MainActor
    func testDisabledDimmingStaysHidden() throws {
        try withBlur(style: .light, contrast: .high) { blur in
            blur.dimmingAlpha = nil
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.0)
        }
    }

    @MainActor
    func testReduceTransparencyStillUsesFullDimming() throws {
        try withBlur(style: .light, contrast: .high, reduceTransparency: true) { blur in
            XCTAssertEqual(try dimmingView(in: blur).alpha, 1.0)
        }
    }

    // MARK: - Trait Changes

    @MainActor
    func testChangingContrastUpdatesTheDimming() throws {
        guard #available(iOS 17, *) else { throw XCTSkip("Trait overrides require iOS 17") }

        try withBlur(style: .light, contrast: .normal) { blur in
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.5, accuracy: 0.001)

            blur.traitOverrides.accessibilityContrast = .high
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.75, accuracy: 0.001)

            blur.traitOverrides.accessibilityContrast = .normal
            blur.layoutIfNeeded()
            XCTAssertEqual(try dimmingView(in: blur).alpha, 0.5, accuracy: 0.001)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func withBlur(style: UIUserInterfaceStyle,
                          contrast: UIAccessibilityContrast,
                          reduceTransparency: Bool = false,
                          _ body: (VariableBlurView) throws -> Void) throws {
        guard #available(iOS 17, *) else { throw XCTSkip("Trait overrides require iOS 17") }

        // Pin Reduce Transparency so these tests don't depend on the simulator's configuration
        VariableBlurView.isReduceTransparencyEnabled = { reduceTransparency }
        defer { VariableBlurView.isReduceTransparencyEnabled = { UIAccessibility.isReduceTransparencyEnabled } }

        let window = makePinnedWindow(style: style, contrast: contrast)
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        window.addSubview(blur)
        blur.layoutIfNeeded()
        try withExtendedLifetime(window) { try body(blur) }
    }

    @MainActor
    private func dimmingView(in blur: VariableBlurView) throws -> UIImageView {
        try XCTUnwrap(blur.subviews.compactMap { $0 as? UIImageView }.first)
    }
}
