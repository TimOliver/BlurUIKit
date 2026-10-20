import XCTest
import UIKit
#if SWIFT_PACKAGE
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class VisualEffectViewBlurTests: XCTestCase {

    private let radiusKeyPath = "filters.gaussianBlur.inputRadius"
    private let saturationKeyPath = "filters.colorSaturate.inputAmount"

    // MARK: - Blur Radius

    @MainActor
    func testBlurEffectRadiusRoundTripsThroughTheEffectsOwnFilter() throws {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        let backdrop = try backdropLayer(of: effectView)
        let defaultRadius = try XCTUnwrap(backdrop.value(forKeyPath: radiusKeyPath) as? CGFloat)
        XCTAssertGreaterThan(defaultRadius, 0)
        XCTAssertEqual(effectView.blurEffectRadius, defaultRadius)

        effectView.blurEffectRadius = 12
        XCTAssertEqual(effectView.blurEffectRadius, 12)
        XCTAssertEqual(backdrop.value(forKeyPath: radiusKeyPath) as? CGFloat, 12)
        XCTAssertNil(backdrop.animation(forKey: radiusKeyPath), "A plain assignment must not animate")
    }

    @MainActor
    func testBlurEffectRadiusAnimatesInsideAnimationBlocks() throws {
        let window = makePinnedWindow()
        defer { window.isHidden = true }
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        effectView.frame = window.bounds
        window.addSubview(effectView)
        let backdrop = try backdropLayer(of: effectView)
        effectView.blurEffectRadius = 20

        UIView.animate(withDuration: 1, delay: 0, options: .curveLinear) { effectView.blurEffectRadius = 0 }

        let animation = try XCTUnwrap(backdrop.animation(forKey: radiusKeyPath) as? CABasicAnimation)
        XCTAssertEqual(animation.fromValue as? CGFloat, 20)
        XCTAssertEqual(animation.duration, 1)
        XCTAssertEqual(controlPoints(of: try XCTUnwrap(animation.timingFunction)), [0, 0, 1, 1],
                       "The block's own duration and curve drive the change")
        XCTAssertEqual(effectView.blurEffectRadius, 0)
        XCTAssertNotNil(backdrop.animation(forKey: "scale"), "The capture resolution animates alongside")
        XCTAssertNotNil(backdrop.animation(forKey: saturationKeyPath), "The saturation boost animates alongside")

        XCTContext.runActivity(named: "A plain assignment cancels the animation") { _ in
            effectView.blurEffectRadius = 8
            XCTAssertNil(backdrop.animation(forKey: radiusKeyPath))
            XCTAssertNil(backdrop.animation(forKey: "scale"))
            XCTAssertNil(backdrop.animation(forKey: saturationKeyPath))
            XCTAssertEqual(effectView.blurEffectRadius, 8)
        }

        XCTContext.runActivity(named: "Disabled animations are respected inside a block") { _ in
            UIView.animate(withDuration: 1) {
                UIView.performWithoutAnimation { effectView.blurEffectRadius = 4 }
            }
            XCTAssertNil(backdrop.animation(forKey: radiusKeyPath))
            XCTAssertEqual(effectView.blurEffectRadius, 4)
        }
    }

    // MARK: - Companion Filters

    @MainActor
    func testBlurEffectRadiusScalesTheOtherFiltersAndCaptureResolution() throws {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        let backdrop = try backdropLayer(of: effectView)
        let defaultRadius = try value(of: backdrop, at: radiusKeyPath)
        let defaultSaturation = try value(of: backdrop, at: saturationKeyPath)
        let defaultScale = try value(of: backdrop, at: "scale")
        XCTAssertGreaterThan(defaultSaturation, 1, "UIKit boosts saturation under its blur")
        XCTAssertLessThan(defaultScale, 1, "UIKit captures the backdrop at a reduced resolution")

        effectView.blurEffectRadius = defaultRadius / 2
        XCTAssertEqual(try value(of: backdrop, at: saturationKeyPath), 1 + (defaultSaturation - 1) / 2, accuracy: 0.001)
        XCTAssertEqual(try value(of: backdrop, at: "scale"), defaultScale + (1 - defaultScale) / 2, accuracy: 0.001)

        effectView.blurEffectRadius = 0
        XCTAssertEqual(try value(of: backdrop, at: saturationKeyPath), 1, accuracy: 0.001, "No saturation boost without blur")
        XCTAssertEqual(try value(of: backdrop, at: "scale"), 1, accuracy: 0.001, "Full resolution without blur")

        effectView.blurEffectRadius = defaultRadius * 2
        XCTAssertEqual(try value(of: backdrop, at: saturationKeyPath), defaultSaturation, accuracy: 0.001,
                       "At or beyond UIKit's radius, its own values stay")
        XCTAssertEqual(try value(of: backdrop, at: "scale"), defaultScale, accuracy: 0.001)
    }

    @MainActor
    func testZeroRadiusNeutralisesTheSystemMaterialFilters() throws {
        // Light mode, where the material also carries a brightness filter
        let window = makePinnedWindow(style: .light)
        defer { window.isHidden = true }
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        effectView.frame = window.bounds
        window.addSubview(effectView)
        window.layoutIfNeeded()
        let backdrop = try backdropLayer(of: effectView)
        let amountKeyPaths = ["filters.colorBrightness.inputAmount", "filters.luminanceCurveMap.inputAmount"]
        for keyPath in amountKeyPaths {
            XCTAssertNotEqual(try value(of: backdrop, at: keyPath), 0, "\(keyPath) is in use by default")
        }

        effectView.blurEffectRadius = 0

        for keyPath in amountKeyPaths {
            XCTAssertEqual(try value(of: backdrop, at: keyPath), 0, accuracy: 0.001, keyPath)
        }
        XCTAssertEqual(try value(of: backdrop, at: saturationKeyPath), 1, accuracy: 0.001)
    }

    // MARK: - Appearance Changes

    @MainActor
    func testValuesSurviveAnAppearanceChange() throws {
        let window = makePinnedWindow(style: .light)
        defer { window.isHidden = true }
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        effectView.frame = window.bounds
        window.addSubview(effectView)
        window.layoutIfNeeded()
        let backdrop = try backdropLayer(of: effectView)
        let lightScale = try value(of: backdrop, at: "scale")

        // UIKit's own dark-mode values, from an untouched view, to derive the expectations from
        let darkWindow = makePinnedWindow(style: .dark)
        defer { darkWindow.isHidden = true }
        let reference = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        reference.frame = darkWindow.bounds
        darkWindow.addSubview(reference)
        darkWindow.layoutIfNeeded()
        let darkRadius = try value(of: try backdropLayer(of: reference), at: radiusKeyPath)
        let darkSaturation = try value(of: try backdropLayer(of: reference), at: saturationKeyPath)

        effectView.blurEffectRadius = 5
        effectView.dimmingAlpha = 0.3
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17, *) { window.updateTraitsIfNeeded() }
        window.layoutIfNeeded()

        XCTAssertEqual(effectView.blurEffectRadius, 5)
        XCTAssertEqual(effectView.dimmingAlpha, 0.3, accuracy: 0.001)
        let fraction = 5 / darkRadius
        XCTAssertEqual(try value(of: backdrop, at: saturationKeyPath), 1 + (darkSaturation - 1) * fraction, accuracy: 0.001,
                       "Companions follow the radius against UIKit's values for the new appearance")
        XCTAssertEqual(try value(of: backdrop, at: "scale"), 1 - (1 - lightScale) * fraction, accuracy: 0.001,
                       "The capture scale is still measured against UIKit's original, not a previous adjustment")
    }

    @MainActor
    func testUntouchedViewsFollowUIKitAcrossAppearanceChanges() throws {
        let window = makePinnedWindow(style: .light)
        defer { window.isHidden = true }
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        effectView.frame = window.bounds
        window.addSubview(effectView)
        window.layoutIfNeeded()
        let lightRadius = effectView.blurEffectRadius
        XCTAssertTrue(effectView.contentView.subviews.isEmpty, "Reading the properties adds nothing to the view")

        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17, *) { window.updateTraitsIfNeeded() }
        window.layoutIfNeeded()

        XCTAssertNotEqual(effectView.blurEffectRadius, lightRadius, "UIKit's dark-mode radius differs and must win")
        XCTAssertEqual(effectView.dimmingAlpha, 1)
        XCTAssertTrue(effectView.contentView.subviews.isEmpty)
    }

    // MARK: - Dimming

    @MainActor
    func testDimmingAlphaControlsTheTintOverlay() throws {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        let overlay = try XCTUnwrap(BlurFilterProvider.findSubview(in: effectView, containing: "subview"))
        XCTAssertEqual(effectView.dimmingAlpha, 1)

        effectView.dimmingAlpha = 0.25
        XCTAssertEqual(overlay.alpha, 0.25, accuracy: 0.001)
        XCTAssertEqual(effectView.dimmingAlpha, 0.25, accuracy: 0.001)
    }

    @MainActor
    func testDimmingAlphaAnimatesInsideAnimationBlocks() throws {
        let window = makePinnedWindow()
        defer { window.isHidden = true }
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        effectView.frame = window.bounds
        window.addSubview(effectView)
        let overlay = try XCTUnwrap(BlurFilterProvider.findSubview(in: effectView, containing: "subview"))

        UIView.animate(withDuration: 1) { effectView.dimmingAlpha = 0 }

        let animation = try XCTUnwrap(overlay.layer.animation(forKey: "opacity") as? CABasicAnimation)
        XCTAssertEqual(animation.duration, 1)
        XCTAssertEqual(overlay.alpha, 0)
    }

    // MARK: - No Blur Effect

    @MainActor
    func testViewsWithoutABlurEffectIgnoreBothProperties() {
        let effectView = UIVisualEffectView(effect: nil)
        XCTAssertEqual(effectView.blurEffectRadius, 0)
        effectView.blurEffectRadius = 10
        XCTAssertEqual(effectView.blurEffectRadius, 0)
        XCTAssertEqual(effectView.dimmingAlpha, 1)
        effectView.dimmingAlpha = 0
    }

    // MARK: - Helpers

    @MainActor
    private func backdropLayer(of effectView: UIVisualEffectView) throws -> CALayer {
        try XCTUnwrap(BlurFilterProvider.findSubview(in: effectView, containing: "backdrop")).layer
    }

    @MainActor
    private func value(of layer: CALayer, at keyPath: String) throws -> CGFloat {
        try XCTUnwrap(layer.value(forKeyPath: keyPath) as? CGFloat, "No value at \(keyPath)")
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
