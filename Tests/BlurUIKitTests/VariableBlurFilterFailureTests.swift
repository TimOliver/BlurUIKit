import XCTest
import UIKit
#if SWIFT_PACKAGE
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class VariableBlurFilterFailureTests: XCTestCase {
    @MainActor
    func testInitialFailureKeepsSystemMaterialAndRecoversOnLaterLayout() throws {
        let provider = BlurFilterProvider.shared
        BlurFilterProvider.shared = BlurFilterProvider(discover: { nil })
        defer { BlurFilterProvider.shared = provider }

        let window = makePinnedWindow()
        defer { window.isHidden = true }
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 280, height: 200))
        blur.dimmingTintColor = nil
        let effect = try effectView(in: blur)
        let backdrop = try XCTUnwrap(BlurFilterProvider.findSubview(in: effect, containing: "backdrop"))
        let originalFilters = try XCTUnwrap(backdrop.layer.filters as? [NSObject])
        XCTAssertFalse(originalFilters.isEmpty)
        window.addSubview(blur)
        blur.layoutIfNeeded()

        XCTAssertFalse(try overlay(in: effect).isHidden, "Keep UIKit's material tint when custom blur is unavailable")
        assertFilters(originalFilters, on: backdrop)

        BlurFilterProvider.shared = provider
        blur.setNeedsLayout()
        blur.layoutIfNeeded()

        XCTAssertEqual(try filter(on: backdrop).value(forKey: "name") as? String, "variableBlur")
        XCTAssertTrue(try overlay(in: effect).isHidden)
    }

    @MainActor
    func testFailedReplacementPreservesCustomBlurAndRetriesPendingRadius() throws {
        let provider = BlurFilterProvider.shared
        defer { BlurFilterProvider.shared = provider }
        let window = makePinnedWindow()
        defer { window.isHidden = true }
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 280, height: 200))
        window.addSubview(blur)
        blur.layoutIfNeeded()
        let effect = try effectView(in: blur)
        let backdrop = try XCTUnwrap(BlurFilterProvider.findSubview(in: effect, containing: "backdrop"))
        let original = try filter(on: backdrop)
        let originalRadius = original.value(forKey: "inputRadius") as? CGFloat
        XCTAssertEqual(original.value(forKey: "name") as? String, "variableBlur")

        BlurFilterProvider.shared = BlurFilterProvider(discover: { { _ in nil } })
        blur.maximumBlurRadius = 20
        blur.layoutIfNeeded()

        XCTAssertTrue(try filter(on: backdrop) === original)
        XCTAssertEqual(original.value(forKey: "inputRadius") as? CGFloat, originalRadius)
        XCTAssertTrue(try overlay(in: effect).isHidden)

        BlurFilterProvider.shared = provider
        blur.setNeedsLayout()
        blur.layoutIfNeeded()

        XCTAssertFalse(try filter(on: backdrop) === original)
        XCTAssertEqual(try filter(on: backdrop).value(forKey: "inputRadius") as? CGFloat, 20)
    }

    @MainActor
    func testSystemMaterialIsRestoredIfUIKitReplacesTheCustomFilterDuringFailure() throws {
        let provider = BlurFilterProvider.shared
        defer { BlurFilterProvider.shared = provider }
        let window = makePinnedWindow()
        defer { window.isHidden = true }
        let blur = VariableBlurView(frame: CGRect(x: 0, y: 0, width: 280, height: 200))
        window.addSubview(blur)
        blur.layoutIfNeeded()
        let effect = try effectView(in: blur)
        let backdrop = try XCTUnwrap(BlurFilterProvider.findSubview(in: effect, containing: "backdrop"))
        XCTAssertEqual(try filter(on: backdrop).value(forKey: "name") as? String, "variableBlur")

        let systemEffect = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        let systemBackdrop = try XCTUnwrap(BlurFilterProvider.findSubview(in: systemEffect, containing: "backdrop"))
        let systemFilters = try XCTUnwrap(systemBackdrop.layer.filters as? [NSObject])
        XCTAssertFalse(systemFilters.isEmpty)
        // Retain the old filter to ensure recovery tests the actual layer, not just the weak cache.
        let original = try filter(on: backdrop)
        BlurFilterProvider.shared = BlurFilterProvider(discover: { { _ in nil } })
        backdrop.layer.filters = systemFilters
        blur.setNeedsLayout()
        blur.layoutIfNeeded()

        assertFilters(systemFilters, on: backdrop)
        XCTAssertFalse(try overlay(in: effect).isHidden)

        BlurFilterProvider.shared = provider
        blur.setNeedsLayout()
        blur.layoutIfNeeded()

        XCTAssertEqual(try filter(on: backdrop).value(forKey: "name") as? String, "variableBlur")
        XCTAssertFalse(try filter(on: backdrop) === original)
        XCTAssertTrue(try overlay(in: effect).isHidden)
        withExtendedLifetime(systemEffect) {}
    }

    @MainActor
    private func effectView(in blur: VariableBlurView) throws -> UIVisualEffectView {
        try XCTUnwrap(blur.subviews.compactMap { $0 as? UIVisualEffectView }.first)
    }

    @MainActor
    private func overlay(in effect: UIVisualEffectView) throws -> UIView {
        try XCTUnwrap(BlurFilterProvider.findSubview(in: effect, containing: "subview"))
    }

    @MainActor
    private func filter(on backdrop: UIView) throws -> NSObject {
        try XCTUnwrap(backdrop.layer.filters?.first as? NSObject)
    }

    @MainActor
    private func assertFilters(_ expected: [NSObject], on backdrop: UIView,
                               file: StaticString = #filePath, line: UInt = #line) {
        let actual = backdrop.layer.filters?.compactMap { $0 as? NSObject } ?? []
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actual, expected) in zip(actual, expected) {
            XCTAssertTrue(actual === expected, file: file, line: line)
        }
    }
}
