import XCTest
import UIKit
#if SWIFT_PACKAGE
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class BlurFilterFailureTests: XCTestCase {
    private let animationKey = "filters.gaussianBlur.inputRadius"

    @MainActor
    func testInitialDiscoveryFailureDoesNotInstallAFilterOrAnimation() {
        let provider = BlurFilterProvider.shared
        BlurFilterProvider.shared = BlurFilterProvider(discover: { nil })
        defer { BlurFilterProvider.shared = provider }
        let view = UIView()

        view.blurRadius = 20
        XCTAssertEqual(view.blurRadius, 0)
        XCTAssertNil(view.layer.filters)

        view.setBlurRadiusAnimated(radius: 20)
        XCTAssertEqual(view.blurRadius, 0)
        XCTAssertNil(view.layer.filters)
        XCTAssertNil(view.layer.animation(forKey: animationKey))
    }

    @MainActor
    func testFailedReplacementsPreserveTheBlurUntilItIsExplicitlyCleared() throws {
        let (view, otherFilter) = try makeViewWithUnrelatedFilter()
        view.blurRadius = 4
        view.setBlurRadiusAnimated(radius: 20, duration: 10, timing: .linear)
        let installedFilter = try XCTUnwrap(view.layer.filters?.last as? NSObject)

        try withFailedFilterCreation {
            try XCTContext.runActivity(named: "A failed direct replacement preserves the running blur") { _ in
                view.blurRadius = 40
                try assertOriginalBlur(on: view, filter: installedFilter, otherFilter: otherFilter)
            }
            try XCTContext.runActivity(named: "A failed animated replacement preserves the running blur") { _ in
                view.setBlurRadiusAnimated(radius: 40, duration: 1)
                try assertOriginalBlur(on: view, filter: installedFilter, otherFilter: otherFilter)
            }
            XCTContext.runActivity(named: "Zero still clears the blur while filter creation is unavailable") { _ in
                view.blurRadius = 0
                XCTAssertEqual(view.blurRadius, 0)
                XCTAssertNil(view.layer.animation(forKey: animationKey))
                XCTAssertEqual(view.layer.filters?.count, 1)
                XCTAssertTrue((view.layer.filters?.first as? NSObject) === otherFilter)
            }
        }
    }

    @MainActor
    func testFailedAnimatedClearDoesNotScheduleRemovalOfTheExistingFilter() throws {
        let window = makePinnedWindow()
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        defer { window.isHidden = true }
        view.blurRadius = 20
        let installedFilter = try XCTUnwrap(view.layer.filters?.first as? NSObject)

        withFailedFilterCreation {
            view.setBlurRadiusAnimated(radius: 0, duration: 0.05)

            XCTAssertNil(view.layer.animation(forKey: animationKey))
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))

            XCTAssertEqual(view.blurRadius, 20)
            XCTAssertTrue((view.layer.filters?.first as? NSObject) === installedFilter)
        }
    }

    @MainActor
    private func assertOriginalBlur(on view: UIView, filter: NSObject, otherFilter: NSObject,
                                    file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(view.blurRadius, 20, file: file, line: line)
        XCTAssertEqual(view.layer.filters?.count, 2, file: file, line: line)
        XCTAssertTrue((view.layer.filters?.first as? NSObject) === otherFilter, file: file, line: line)
        XCTAssertTrue((view.layer.filters?.last as? NSObject) === filter, file: file, line: line)
        let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation,
                                     file: file, line: line)
        XCTAssertEqual(animation.fromValue as? CGFloat, 4, file: file, line: line)
        XCTAssertEqual(animation.toValue as? CGFloat, 20, file: file, line: line)
        XCTAssertEqual(animation.duration, 10, file: file, line: line)
    }

    @MainActor
    private func makeViewWithUnrelatedFilter() throws -> (UIView, NSObject) {
        let otherFilter = try XCTUnwrap(BlurFilterProvider.shared.makeFilter(named: "colorInvert"))
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.layer.filters = [otherFilter]
        return (view, otherFilter)
    }

    @MainActor
    private func withFailedFilterCreation(_ body: () throws -> Void) rethrows {
        let provider = BlurFilterProvider.shared
        BlurFilterProvider.shared = BlurFilterProvider(discover: { { _ in nil } })
        defer { BlurFilterProvider.shared = provider }
        try body()
    }
}
