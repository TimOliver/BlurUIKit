import XCTest
import UIKit
@testable import BlurUIKit

final class VariableBlurLayoutTests: XCTestCase {
    @MainActor
    func testInitialFrameInstallsVariableBlurWithoutDimming() throws {
        let host = UIView()
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 160))
        blur.dimmingTintColor = nil
        host.addSubview(blur)

        try withExtendedLifetime(host) {
            blur.layoutIfNeeded()
            XCTAssertEqual(try blurMask(in: blur).height, 160)
        }
    }

    @MainActor
    func testAutoLayoutSizingInstallsVariableBlurAfterZeroSizedLayout() throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 160))
        let blur = VariableBlurView()
        blur.dimmingTintColor = nil
        blur.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(blur)
        blur.setNeedsLayout()
        blur.layoutIfNeeded()

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            blur.topAnchor.constraint(equalTo: host.topAnchor),
            blur.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        host.layoutIfNeeded()
        blur.layoutIfNeeded()

        let mask = try blurMask(in: blur)
        XCTAssertEqual(blur.bounds.size, host.bounds.size)
        XCTAssertEqual(mask.height, 160)
    }

    @MainActor
    func testZeroSizedLayoutThenBoundsSizingInstallsVariableBlur() throws {
        try withBlur { blur in
            blur.setNeedsLayout()
            blur.layoutIfNeeded()

            blur.bounds.size = CGSize(width: 300, height: 160)
            blur.layoutIfNeeded()

            let mask = try blurMask(in: blur)
            XCTAssertEqual(mask.width, 1)
            XCTAssertEqual(mask.height, 160)
        }
    }

    @MainActor
    func testBoundsResizeRegeneratesVerticalMask() throws {
        try withBlur { blur in
            blur.frame = CGRect(x: 0, y: 0, width: 300, height: 160)
            blur.layoutIfNeeded()
            XCTAssertEqual(try blurMask(in: blur).height, 160)

            blur.bounds.size.height = 240
            blur.layoutIfNeeded()
            XCTAssertEqual(try blurMask(in: blur).height, 240)
        }
    }

    @MainActor
    func testBoundsResizeRegeneratesHorizontalMask() throws {
        try withBlur { blur in
            blur.direction = .right
            blur.frame = CGRect(x: 0, y: 0, width: 160, height: 300)
            blur.layoutIfNeeded()
            XCTAssertEqual(try blurMask(in: blur).width, 160)

            blur.bounds.size.width = 240
            blur.layoutIfNeeded()
            let mask = try blurMask(in: blur)
            XCTAssertEqual(mask.width, 240)
            XCTAssertEqual(mask.height, 1)
        }
    }

    @MainActor
    func testZeroWidthLayoutKeepsMaskGenerationPending() throws {
        try withBlur { blur in
            blur.bounds.size = CGSize(width: 0, height: 160)
            blur.layoutIfNeeded()

            // Only the dimension perpendicular to the gradient changes here.
            blur.bounds.size.width = 300
            blur.layoutIfNeeded()
            XCTAssertEqual(try blurMask(in: blur).height, 160)
        }
    }

    @MainActor
    func testZeroHeightLayoutKeepsHorizontalMaskGenerationPending() throws {
        try withBlur { blur in
            blur.direction = .right
            blur.bounds.size = CGSize(width: 160, height: 0)
            blur.layoutIfNeeded()

            blur.bounds.size.height = 300
            blur.layoutIfNeeded()
            XCTAssertEqual(try blurMask(in: blur).width, 160)
        }
    }

    @MainActor
    private func withBlur(_ body: (VariableBlurView) throws -> Void) rethrows {
        let host = UIView()
        let blur = VariableBlurView()
        blur.dimmingTintColor = nil
        host.addSubview(blur)
        try withExtendedLifetime(host) { try body(blur) }
    }

    @MainActor
    private func blurMask(in blur: VariableBlurView) throws -> CGImage {
        let effectView = try XCTUnwrap(blur.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        let backdrop = try XCTUnwrap(BlurFilterProvider.findSubview(in: effectView, containing: "backdrop"))
        let filter = try XCTUnwrap(backdrop.layer.filters?.first as? NSObject)
        let name = try XCTUnwrap(filter.value(forKey: "name") as? String)
        XCTAssertEqual(name, "variableBlur")
        guard name == "variableBlur" else { throw NSError(domain: "VariableBlurLayoutTests", code: 1) }
        return try XCTUnwrap(filter.value(forKey: "inputMaskImage")) as! CGImage
    }
}
