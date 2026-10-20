import XCTest
import UIKit
@testable import BlurUIKit

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
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        window.isHidden = false
        view.blurRadius = 20

        view.setBlurRadiusAnimated(radius: 0, duration: 0.05)
        XCTAssertEqual(view.layer.filters?.count, 1)

        let removed = expectation(for: NSPredicate { _, _ in view.layer.filters == nil },
                                  evaluatedWith: nil)
        wait(for: [removed], timeout: 2)
    }

    @MainActor
    func testAnimatingAwayFromZeroKeepsTheFilter() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        window.isHidden = false

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

    /// The two user-defined control points of a cubic timing function, as x1, y1, x2, y2.
    private func controlPoints(of timing: CAMediaTimingFunction) -> [Float] {
        (1...2).flatMap { index -> [Float] in
            var point: [Float] = [0, 0]
            point.withUnsafeMutableBufferPointer { timing.getControlPoint(at: index, values: $0.baseAddress!) }
            return point
        }
    }
}
