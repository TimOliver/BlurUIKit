import XCTest
import UIKit
#if SWIFT_PACKAGE
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class BlurAnimationTests: XCTestCase {

    private let animationKey = "filters.gaussianBlur.inputRadius"

    // MARK: - Automatic Timing

    @MainActor
    func testClearingTheBlurEasesOutByDefault() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.blurRadius = 20

        view.setBlurRadiusAnimated(radius: 0, duration: 1)

        let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
        XCTAssertEqual(view.blurRadius, 0)
        XCTAssertEqual(animation.fromValue as? CGFloat, 20)
        XCTAssertEqual(animation.duration, 1)
        XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), controlPoints(of: .blurEaseOut))
    }

    @MainActor
    func testApplyingTheBlurEasesInByDefault() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        view.setBlurRadiusAnimated(radius: 20, duration: 1)

        let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
        XCTAssertEqual(view.blurRadius, 20)
        XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), controlPoints(of: .blurEaseIn))
    }

    // MARK: - Interrupted Animations

    @MainActor
    func testRetargetingBeforePresentationStartsKeepsTheOriginalRadius() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.blurRadius = 4
        view.setBlurRadiusAnimated(radius: 20, duration: 1)
        XCTAssertNil(view.layer.presentation())

        view.setBlurRadiusAnimated(radius: 0, duration: 1)

        let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
        XCTAssertEqual(animation.fromValue as? CGFloat, 4)
    }

    @MainActor
    func testRetargetingStartsAtThePresentedRadius() throws {
        try withAnimatingBlur(from: 0, to: 20) { view, presentedRadius in
            view.setBlurRadiusAnimated(radius: 0, duration: 1)

            let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
            XCTAssertEqual(try XCTUnwrap(animation.fromValue as? CGFloat), presentedRadius, accuracy: 0.5)
            XCTAssertEqual(view.blurRadius, 0)
        }
    }

    @MainActor
    func testAutomaticTimingUsesThePresentedDirectionWhenRetargeting() throws {
        try withAnimatingBlur(from: 20, to: 0) { view, presentedRadius in
            // This target decreases the visible radius, but increases the old model radius of zero.
            view.setBlurRadiusAnimated(radius: presentedRadius / 2, duration: 1)

            let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
            XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)),
                           controlPoints(of: .blurEaseOut))
        }
    }

    @MainActor
    func testImmediateRadiusChangeCancelsOnlyTheBlurAnimation() throws {
        try withAnimatingBlur(from: 0, to: 20) { view, _ in
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 1
            opacity.toValue = 0.5
            opacity.duration = 2
            view.layer.add(opacity, forKey: "unrelatedOpacity")

            view.blurRadius = 40

            XCTAssertNil(view.layer.animation(forKey: animationKey))
            XCTAssertNotNil(view.layer.animation(forKey: "unrelatedOpacity"))
            XCTAssertEqual(view.blurRadius, 40)
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            XCTAssertEqual(try presentedRadius(of: view), 40, accuracy: 0.5)
        }
    }

    @MainActor
    func testClearingDuringAnimationDoesNotResumeAfterReapplyingBlur() throws {
        try withAnimatingBlur(from: 0, to: 20) { view, _ in
            view.blurRadius = 0
            XCTAssertNil(view.layer.animation(forKey: animationKey))
            XCTAssertNil(view.layer.filters)

            view.blurRadius = 10
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))

            XCTAssertNil(view.layer.animation(forKey: animationKey))
            XCTAssertEqual(try presentedRadius(of: view), 10, accuracy: 0.5)
        }
    }

    @MainActor
    func testInterruptedClearDoesNotRemoveTheReplacementFilter() throws {
        try withAnimatingBlur(from: 20, to: 0) { view, _ in
            view.blurRadius = 20
            let replacement = try XCTUnwrap(view.layer.filters?.first as? NSObject)
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))

            XCTAssertEqual(view.blurRadius, 20)
            XCTAssertEqual(view.layer.filters?.count, 1)
            XCTAssertTrue((view.layer.filters?.first as? NSObject) === replacement)
        }
    }

    // MARK: - Filter Cleanup

    @MainActor
    func testSettingZeroRadiusRemovesTheFilter() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.blurRadius = 20
        XCTAssertEqual(view.layer.filters?.count, 1)

        view.blurRadius = 0

        XCTAssertNil(view.layer.filters)
        XCTAssertEqual(view.blurRadius, 0)
    }

    @MainActor
    func testRemovingTheBlurLeavesOtherFiltersInPlace() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let otherFilter = try XCTUnwrap(BlurFilterProvider.blurFilter(named: "colorInvert"))
        view.layer.filters = [otherFilter]
        view.blurRadius = 20

        view.blurRadius = 0

        XCTAssertEqual(view.layer.filters?.count, 1)
        XCTAssertTrue((view.layer.filters?.first as? NSObject) === otherFilter)
    }

    @MainActor
    func testAnimatingToZeroKeepsTheFilterUntilTheAnimationEnds() {
        let window = makePinnedWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        defer { window.isHidden = true }
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        view.blurRadius = 20

        view.setBlurRadiusAnimated(radius: 0, duration: 0.05)
        XCTAssertEqual(view.layer.filters?.count, 1)

        let removed = expectation(for: NSPredicate { _, _ in view.layer.filters == nil },
                                  evaluatedWith: nil)
        wait(for: [removed], timeout: 2)
    }

    @MainActor
    func testAnimatingAwayFromZeroKeepsTheFilter() {
        let window = makePinnedWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        defer { window.isHidden = true }
        let view = UIView(frame: window.bounds)
        window.addSubview(view)

        view.setBlurRadiusAnimated(radius: 20, duration: 0.05)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        XCTAssertEqual(view.layer.filters?.count, 1)
        XCTAssertEqual(view.blurRadius, 20)
    }

    // MARK: - Timing Overrides

    @MainActor
    func testLinearTimingCanBeChosen() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.blurRadius = 20

        view.setBlurRadiusAnimated(radius: 0, duration: 1, timing: .linear)

        let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
        XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), [0, 0, 1, 1])
    }

    @MainActor
    func testEitherBlurCurveCanBeChosenRegardlessOfDirection() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        view.setBlurRadiusAnimated(radius: 20, duration: 1, timing: .easeOut)

        let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
        XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), controlPoints(of: .blurEaseOut))
    }

    @MainActor
    func testCustomTimingFunctionIsUsedAsSupplied() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let custom = CAMediaTimingFunction(name: .easeInEaseOut)

        view.setBlurRadiusAnimated(radius: 20, duration: 1, timing: .custom(custom))

        let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
        XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), controlPoints(of: custom))
    }

    // MARK: - Curves

    func testBlurEaseOutCurveFrontLoadsTheRadiusChange() {
        let points = controlPoints(of: .blurEaseOut)

        // The first control point sits high and early, so most of the radius goes in the first fifth.
        XCTAssertEqual(points[0], 0.2, accuracy: 0.001)
        XCTAssertEqual(points[1], 0.9, accuracy: 0.001)
        XCTAssertEqual(points[2], 0.4, accuracy: 0.001)
        XCTAssertEqual(points[3], 1.0, accuracy: 0.001)
    }

    func testBlurEaseInMirrorsBlurEaseOut() {
        let easeOut = controlPoints(of: .blurEaseOut)
        let easeIn = controlPoints(of: .blurEaseIn)

        // Reflecting the curve through its centre swaps and inverts the control points.
        XCTAssertEqual(easeIn[0], 1 - easeOut[2], accuracy: 0.001)
        XCTAssertEqual(easeIn[1], 1 - easeOut[3], accuracy: 0.001)
        XCTAssertEqual(easeIn[2], 1 - easeOut[0], accuracy: 0.001)
        XCTAssertEqual(easeIn[3], 1 - easeOut[1], accuracy: 0.001)
    }

    func testTimingIsSendable() {
        requireSendable(BlurAnimationTiming.self)
    }

    // MARK: - Helpers

    @MainActor
    private func withAnimatingBlur(from initialRadius: CGFloat,
                                   to targetRadius: CGFloat,
                                   _ body: (UIView, CGFloat) throws -> Void) throws {
        let window = makePinnedWindow()
        let view = UIView(frame: window.bounds)
        view.backgroundColor = .red
        window.addSubview(view)
        defer {
            view.layer.removeAllAnimations()
            window.isHidden = true
        }
        view.blurRadius = initialRadius
        view.setBlurRadiusAnimated(radius: targetRadius, duration: 2, timing: .linear)
        CATransaction.flush()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let radius = try presentedRadius(of: view)
        XCTAssertGreaterThan(radius, min(initialRadius, targetRadius))
        XCTAssertLessThan(radius, max(initialRadius, targetRadius))
        try body(view, radius)
    }

    @MainActor
    private func presentedRadius(of view: UIView) throws -> CGFloat {
        let filter = try XCTUnwrap(view.layer.presentation()?.filters?.first as? NSObject)
        return try XCTUnwrap(filter.value(forKey: "inputRadius") as? CGFloat)
    }

    private func requireSendable<T: Sendable>(_: T.Type) {}

    /// The two user-defined control points of a cubic timing function, as x1, y1, x2, y2.
    private func controlPoints(of timing: CAMediaTimingFunction) -> [Float] {
        (1...2).flatMap { index -> [Float] in
            var point: [Float] = [0, 0]
            point.withUnsafeMutableBufferPointer { timing.getControlPoint(at: index, values: $0.baseAddress!) }
            return point
        }
    }
}
