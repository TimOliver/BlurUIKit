import XCTest
import UIKit
#if SWIFT_PACKAGE
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class ReflectionBlurViewTests: XCTestCase {
    @MainActor
    func testSourceControlsRemainInteractiveWhenReflectionVisibilityChanges() {
        let hierarchy = makeHierarchy()
        let button = UIButton(frame: CGRect(x: 50, y: 50, width: 100, height: 50))
        hierarchy.source.addSubview(button)

        for isHidden in [false, true, false] {
            hierarchy.reflection.isReflectionHidden = isHidden
            hierarchy.reflection.layoutIfNeeded()
            let state = isHidden ? "hidden" : "visible"

            XCTAssertFalse(hierarchy.source.isHidden, "Source visibility with reflection \(state)")
            XCTAssertTrue(hit(CGPoint(x: 150, y: 100), in: hierarchy) === hierarchy.source,
                          "Source hit with reflection \(state)")
            XCTAssertTrue(hit(CGPoint(x: 150, y: 300), in: hierarchy) === hierarchy.underlying,
                          "Reflection passthrough with reflection \(state)")
            XCTAssertTrue(hit(CGPoint(x: 150, y: 199), in: hierarchy) === hierarchy.source,
                          "Source side of seam with reflection \(state)")
            XCTAssertTrue(hit(CGPoint(x: 150, y: 201), in: hierarchy) === hierarchy.underlying,
                          "Reflected side of seam with reflection \(state)")
            XCTAssertTrue(hit(CGPoint(x: 75, y: 75), in: hierarchy) === button,
                          "Nested button hit with reflection \(state)")
            XCTAssertTrue(hit(CGPoint(x: 75, y: 325), in: hierarchy) === hierarchy.underlying,
                          "Mirrored button passthrough with reflection \(state)")
        }
    }

    @MainActor
    func testHitRegionsFollowResizingAndBoundsOrigin() {
        let hierarchy = makeHierarchy()
        let point = CGPoint(x: 150, y: 250)
        XCTAssertTrue(hit(point, in: hierarchy) === hierarchy.underlying)

        hierarchy.reflection.frame.size.height = 600
        hierarchy.reflection.layoutIfNeeded()

        XCTAssertEqual(hierarchy.source.bounds.size, CGSize(width: 300, height: 300))
        XCTAssertTrue(hit(point, in: hierarchy) === hierarchy.source)
        XCTAssertTrue(hit(CGPoint(x: 150, y: 450), in: hierarchy) === hierarchy.underlying)

        hierarchy.reflection.frame.size.height = 400
        hierarchy.reflection.layoutIfNeeded()

        XCTAssertEqual(hierarchy.source.bounds.size, CGSize(width: 300, height: 200))
        XCTAssertTrue(hit(point, in: hierarchy) === hierarchy.underlying)
        XCTAssertTrue(hit(CGPoint(x: 150, y: 100), in: hierarchy) === hierarchy.source)

        hierarchy.reflection.bounds.origin = CGPoint(x: 37, y: 29)
        hierarchy.reflection.layoutIfNeeded()
        let bounds = hierarchy.reflection.bounds

        XCTAssertTrue(hit(CGPoint(x: bounds.midX, y: bounds.minY + 100), in: hierarchy) === hierarchy.source)
        XCTAssertTrue(hit(CGPoint(x: bounds.midX, y: bounds.midY - 1), in: hierarchy) === hierarchy.source)
        XCTAssertTrue(hit(CGPoint(x: bounds.midX, y: bounds.midY + 1), in: hierarchy) === hierarchy.underlying)
        XCTAssertTrue(hit(CGPoint(x: bounds.midX, y: bounds.maxY - 100), in: hierarchy) === hierarchy.underlying)
    }

    @MainActor
    func testContentReassignmentAndReplacementPreserveTheExpectedAttachments() {
        let source = AttachmentTrackingControl()
        let hierarchy = makeHierarchy(source: source)
        let originalFrame = hierarchy.reflection.frame
        let originalParent = source.superview
        let originalMoveCount = source.superviewMoveCount
        let currentContent = hierarchy.reflection.contentView

        hierarchy.reflection.contentView = currentContent
        hierarchy.reflection.layoutIfNeeded()

        XCTAssertTrue(source.superview === originalParent, "Same content must keep its parent")
        XCTAssertEqual(source.superviewMoveCount, originalMoveCount, "Same content must not detach and reattach")
        XCTAssertTrue(hit(CGPoint(x: 150, y: 100), in: hierarchy) === source)

        let formerParent = UIView()
        let replacement = UIControl(frame: CGRect(x: 12, y: 34, width: 50, height: 60))
        formerParent.addSubview(replacement)

        hierarchy.reflection.contentView = replacement
        hierarchy.reflection.layoutIfNeeded()

        XCTAssertNil(hierarchy.source.superview)
        XCTAssertTrue(formerParent.subviews.isEmpty)
        XCTAssertTrue(replacement.isDescendant(of: hierarchy.reflection))
        XCTAssertEqual(hierarchy.reflection.frame, originalFrame)
        XCTAssertEqual(replacement.bounds.size, CGSize(width: 300, height: 200))
        XCTAssertTrue(hit(CGPoint(x: 150, y: 100), in: hierarchy) === replacement)
        XCTAssertTrue(hit(CGPoint(x: 150, y: 300), in: hierarchy) === hierarchy.underlying)
    }

    // MARK: - Helpers

    private struct Hierarchy {
        let host: UIView
        let underlying: UIControl
        let reflection: ReflectionBlurView
        let source: UIControl
    }

    @MainActor
    private func makeHierarchy(source: UIControl = UIControl()) -> Hierarchy {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 800))
        let underlying = UIControl(frame: host.bounds)
        host.addSubview(underlying)
        let reflection = ReflectionBlurView(contentView: source)
        reflection.frame = CGRect(x: 40, y: 60, width: 300, height: 400)
        host.addSubview(reflection)
        host.layoutIfNeeded()
        reflection.layoutIfNeeded()
        return Hierarchy(host: host, underlying: underlying, reflection: reflection, source: source)
    }

    @MainActor
    private func hit(_ point: CGPoint, in hierarchy: Hierarchy) -> UIView? {
        let hostPoint = hierarchy.reflection.convert(point, to: hierarchy.host)
        return hierarchy.host.hitTest(hostPoint, with: nil)
    }

    @MainActor
    private final class AttachmentTrackingControl: UIControl {
        private(set) var superviewMoveCount = 0

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            superviewMoveCount += 1
        }
    }
}
