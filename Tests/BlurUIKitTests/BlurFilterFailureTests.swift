import XCTest
import UIKit
@testable import BlurUIKit

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
    func testFailedDirectReplacementPreservesTheFilterAndRunningAnimation() throws {
        let (view, otherFilter) = try makeViewWithUnrelatedFilter()
        view.blurRadius = 4
        view.setBlurRadiusAnimated(radius: 20, duration: 10, timing: .linear)
        let installedFilter = try XCTUnwrap(view.layer.filters?.last as? NSObject)

        try withFailedFilterCreation {
            view.blurRadius = 40

            XCTAssertEqual(view.blurRadius, 20)
            XCTAssertEqual(view.layer.filters?.count, 2)
            XCTAssertTrue((view.layer.filters?.first as? NSObject) === otherFilter)
            XCTAssertTrue((view.layer.filters?.last as? NSObject) === installedFilter)
            let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
            XCTAssertEqual(animation.fromValue as? CGFloat, 4)
            XCTAssertEqual(animation.toValue as? CGFloat, 20)
            XCTAssertEqual(animation.duration, 10)
        }
    }

    @MainActor
    func testFailedAnimatedReplacementPreservesTheFilterAndRunningAnimation() throws {
        let (view, otherFilter) = try makeViewWithUnrelatedFilter()
        view.blurRadius = 4
        view.setBlurRadiusAnimated(radius: 20, duration: 10, timing: .linear)
        let installedFilter = try XCTUnwrap(view.layer.filters?.last as? NSObject)

        try withFailedFilterCreation {
            view.setBlurRadiusAnimated(radius: 40, duration: 1)

            XCTAssertEqual(view.blurRadius, 20)
            XCTAssertEqual(view.layer.filters?.count, 2)
            XCTAssertTrue((view.layer.filters?.first as? NSObject) === otherFilter)
            XCTAssertTrue((view.layer.filters?.last as? NSObject) === installedFilter)
            let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
            XCTAssertEqual(animation.fromValue as? CGFloat, 4)
            XCTAssertEqual(animation.toValue as? CGFloat, 20)
            XCTAssertEqual(animation.duration, 10)
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
    func testZeroStillClearsTheBlurWhenFilterCreationFails() throws {
        let (view, otherFilter) = try makeViewWithUnrelatedFilter()
        view.setBlurRadiusAnimated(radius: 20, duration: 10)

        withFailedFilterCreation {
            view.blurRadius = 0

            XCTAssertEqual(view.blurRadius, 0)
            XCTAssertNil(view.layer.animation(forKey: animationKey))
            XCTAssertEqual(view.layer.filters?.count, 1)
            XCTAssertTrue((view.layer.filters?.first as? NSObject) === otherFilter)
        }
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
