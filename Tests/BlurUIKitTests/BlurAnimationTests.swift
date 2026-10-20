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
    func testDefaultTimingFollowsTheDirectionOfTheRadiusChange() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.blurRadius = 20

        try XCTContext.runActivity(named: "Clearing eases out") { _ in
            view.setBlurRadiusAnimated(radius: 0, duration: 1)
            let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
            XCTAssertEqual(view.blurRadius, 0)
            XCTAssertEqual(animation.fromValue as? CGFloat, 20)
            XCTAssertEqual(animation.duration, 1)
            XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), controlPoints(of: .blurEaseOut))
        }

        try XCTContext.runActivity(named: "Applying eases in") { _ in
            view.blurRadius = 0
            view.setBlurRadiusAnimated(radius: 20, duration: 1)
            let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
            XCTAssertEqual(view.blurRadius, 20)
            XCTAssertEqual(animation.fromValue as? CGFloat, 0)
            XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), controlPoints(of: .blurEaseIn))
        }
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
    func testRetargetingUsesThePresentedRadiusAndDirection() throws {
        try withAnimatingBlur(from: 20, to: 0) { view, presentedRadius in
            // This target decreases the visible radius, but increases the old model radius of zero.
            let targetRadius = presentedRadius / 2
            view.setBlurRadiusAnimated(radius: targetRadius, duration: 1)

            let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
            XCTAssertEqual(try XCTUnwrap(animation.fromValue as? CGFloat), presentedRadius, accuracy: 0.5)
            XCTAssertEqual(view.blurRadius, targetRadius)
            XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)),
                           controlPoints(of: .blurEaseOut))
        }
    }

    @MainActor
    func testImmediateRadiusChangeCancelsOnlyTheBlurAnimation() throws {
        try withAnimatingBlur(from: 20, to: 0) { view, _ in
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 1
            opacity.toValue = 0.5
            opacity.duration = 2
            view.layer.add(opacity, forKey: "unrelatedOpacity")

            view.blurRadius = 40
            let replacement = try XCTUnwrap(view.layer.filters?.first as? NSObject)

            XCTAssertNil(view.layer.animation(forKey: animationKey))
            XCTAssertNotNil(view.layer.animation(forKey: "unrelatedOpacity"))
            XCTAssertEqual(view.blurRadius, 40)
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            XCTAssertEqual(try presentedRadius(of: view), 40, accuracy: 0.5)
            XCTAssertEqual(view.layer.filters?.count, 1)
            XCTAssertTrue((view.layer.filters?.first as? NSObject) === replacement,
                          "The interrupted clearing animation must not remove its replacement.")

            for duration: TimeInterval in [0, -1] {
                XCTContext.runActivity(named: "Duration \(duration) applies and clears immediately") { _ in
                    // Start from a blurred view, so clearing it has an animation to interrupt.
                    view.blurRadius = 40
                    view.setBlurRadiusAnimated(radius: 0, duration: 2)
                    XCTAssertNotNil(view.layer.animation(forKey: animationKey))

                    view.setBlurRadiusAnimated(radius: 40, duration: duration)
                    XCTAssertNil(view.layer.animation(forKey: animationKey))
                    XCTAssertEqual(view.blurRadius, 40)
                    XCTAssertEqual(view.layer.filters?.count, 1)
                    XCTAssertNotNil(view.layer.animation(forKey: "unrelatedOpacity"))

                    view.setBlurRadiusAnimated(radius: 0, duration: duration)
                    XCTAssertEqual(view.blurRadius, 0)
                    XCTAssertNil(view.layer.animation(forKey: animationKey))
                    XCTAssertNil(view.layer.filters)
                    XCTAssertNotNil(view.layer.animation(forKey: "unrelatedOpacity"))
                }
            }
        }
    }

    @MainActor
    func testClearingDuringAnimationDoesNotResumeAfterReapplyingBlur() throws {
        try withAnimatingBlur(from: 0, to: 20) { view, _ in
            view.blurRadius = 0
            XCTAssertEqual(view.blurRadius, 0)
            XCTAssertNil(view.layer.animation(forKey: animationKey))
            XCTAssertNil(view.layer.filters)

            view.blurRadius = 10
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))

            XCTAssertNil(view.layer.animation(forKey: animationKey))
            XCTAssertEqual(try presentedRadius(of: view), 10, accuracy: 0.5)
        }
    }

    // MARK: - Redundant Changes

    @MainActor
    func testAnimatingToTheCurrentRadiusAppliesItWithoutAnimating() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        XCTContext.runActivity(named: "Clearing an unblurred view installs nothing") { _ in
            view.setBlurRadiusAnimated(radius: 0, duration: 1)
            XCTAssertNil(view.layer.filters)
            XCTAssertNil(view.layer.animation(forKey: animationKey))
        }

        XCTContext.runActivity(named: "Re-applying the current radius keeps the existing filter") { _ in
            view.blurRadius = 20
            let installed = view.layer.filters?.first as? NSObject
            view.setBlurRadiusAnimated(radius: 20, duration: 1)
            XCTAssertEqual(view.blurRadius, 20)
            XCTAssertTrue((view.layer.filters?.first as? NSObject) === installed)
            XCTAssertEqual(view.layer.filters?.count, 1)
            XCTAssertNil(view.layer.animation(forKey: animationKey))
        }

        XCTContext.runActivity(named: "Retargeting to the start radius before presentation cancels the animation") { _ in
            view.blurRadius = 4
            view.setBlurRadiusAnimated(radius: 20, duration: 1)
            XCTAssertNotNil(view.layer.animation(forKey: animationKey))

            view.setBlurRadiusAnimated(radius: 4, duration: 1)
            XCTAssertEqual(view.blurRadius, 4)
            XCTAssertNil(view.layer.animation(forKey: animationKey))
        }
    }

    // MARK: - Filter Cleanup

    @MainActor
    func testFinishedAnimationsKeepPositiveBlurAndRemoveClearedBlur() {
        let window = makePinnedWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        defer { window.isHidden = true }
        let view = UIView(frame: window.bounds)
        window.addSubview(view)

        XCTContext.runActivity(named: "A finished positive-radius animation keeps its filter") { _ in
            view.setBlurRadiusAnimated(radius: 20, duration: 0.05)
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            XCTAssertEqual(view.layer.filters?.count, 1)
            XCTAssertEqual(view.blurRadius, 20)
        }

        XCTContext.runActivity(named: "Clearing keeps its filter until the animation finishes") { _ in
            view.setBlurRadiusAnimated(radius: 0, duration: 0.05)
            XCTAssertEqual(view.layer.filters?.count, 1)
            let removed = expectation(for: NSPredicate { _, _ in view.layer.filters == nil },
                                      evaluatedWith: nil)
            wait(for: [removed], timeout: 2)
        }
    }

    // MARK: - Timing Overrides

    @MainActor
    func testExplicitTimingChoicesAreUsedAsSupplied() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let custom = CAMediaTimingFunction(name: .easeInEaseOut)
        let cases: [(name: String, from: CGFloat, to: CGFloat,
                     timing: BlurAnimationTiming, expected: [Float])] = [
            ("Linear clearing", 20, 0, .linear, [0, 0, 1, 1]),
            ("Ease-out while applying blur", 0, 20, .easeOut, controlPoints(of: .blurEaseOut)),
            ("Custom curve", 0, 20, .custom(custom), controlPoints(of: custom))
        ]
        for testCase in cases {
            try XCTContext.runActivity(named: testCase.name) { _ in
                view.blurRadius = testCase.from
                view.setBlurRadiusAnimated(radius: testCase.to, duration: 1, timing: testCase.timing)
                let animation = try XCTUnwrap(view.layer.animation(forKey: animationKey) as? CABasicAnimation)
                XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), testCase.expected)
            }
        }
    }

    // MARK: - Curves

    func testBlurEaseInMirrorsBlurEaseOut() {
        let easeOut = controlPoints(of: .blurEaseOut)
        let easeIn = controlPoints(of: .blurEaseIn)

        // Reflecting the curve through its centre swaps and inverts the control points.
        XCTAssertEqual(easeIn[0], 1 - easeOut[2], accuracy: 0.001)
        XCTAssertEqual(easeIn[1], 1 - easeOut[3], accuracy: 0.001)
        XCTAssertEqual(easeIn[2], 1 - easeOut[0], accuracy: 0.001)
        XCTAssertEqual(easeIn[3], 1 - easeOut[1], accuracy: 0.001)
    }

    // The compiler checks this constraint without creating a runnable test.
    private func checkTimingIsSendable() {
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
