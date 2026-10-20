import XCTest
import UIKit
#if SWIFT_PACKAGE
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class BlurFilterReuseTests: XCTestCase {

    // MARK: - Reuse

    @MainActor
    func testPlainAndCrossAxisLayoutsKeepTheInstalledFilter() throws {
        try withBlur { blur, _ in
            let installed = try filter(in: blur)
            blur.setNeedsLayout()
            blur.layoutIfNeeded()
            XCTAssertTrue(try filter(in: blur) === installed)

            // The gradient runs vertically, so a width change doesn't affect the mask
            blur.frame.size.width = 200
            blur.layoutIfNeeded()
            XCTAssertTrue(try filter(in: blur) === installed)
        }
    }

    // MARK: - Rebuilds

    @MainActor
    func testRadiusAndAlongAxisSizeChangesInstallNewFilters() throws {
        try withBlur { blur, _ in
            let installed = try filter(in: blur)
            blur.maximumBlurRadius = 20
            blur.layoutIfNeeded()
            let rebuilt = try filter(in: blur)
            XCTAssertFalse(rebuilt === installed)
            XCTAssertEqual(rebuilt.value(forKey: "inputRadius") as? CGFloat, 20)

            blur.frame.size.height = 150
            blur.layoutIfNeeded()
            XCTAssertFalse(try filter(in: blur) === rebuilt)
        }
    }

    @MainActor
    func testFilterIsReinstalledAfterUIKitReplacementAndWindowChanges() throws {
        try withBlur { blur, _ in
            let backdrop = try backdropView(in: blur)
            let installed = try filter(in: blur)
            backdrop.layer.filters = [try XCTUnwrap(BlurFilterProvider.shared.makeFilter(named: "gaussianBlur"))]

            blur.setNeedsLayout()
            blur.layoutIfNeeded()
            let reinstalled = try filter(in: blur)
            XCTAssertFalse(reinstalled === installed)
            XCTAssertEqual(reinstalled.value(forKey: "name") as? String, "variableBlur")

            let otherWindow = makePinnedWindow()
            defer { otherWindow.isHidden = true }
            otherWindow.addSubview(blur)
            blur.layoutIfNeeded()
            XCTAssertFalse(try filter(in: blur) === reinstalled)
            withExtendedLifetime(otherWindow) {}
        }
    }

    // MARK: - Helpers

    @MainActor
    private func withBlur(_ body: (VariableBlurView, UIWindow) throws -> Void) throws {
        let window = makePinnedWindow()
        defer { window.isHidden = true }
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        window.addSubview(blur)
        blur.layoutIfNeeded()
        try withExtendedLifetime(window) { try body(blur, window) }
    }

    @MainActor
    private func backdropView(in blur: VariableBlurView) throws -> UIView {
        let effectView = try XCTUnwrap(blur.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        return try XCTUnwrap(BlurFilterProvider.findSubview(in: effectView, containing: "backdrop"))
    }

    @MainActor
    private func filter(in blur: VariableBlurView) throws -> NSObject {
        try XCTUnwrap(try backdropView(in: blur).layer.filters?.first as? NSObject)
    }
}
