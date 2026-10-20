//
//  UIVisualEffectView+Blur.swift
//  Copyright (c) 2024-2026 Tim Oliver
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import ObjectiveC
import UIKit

// Adjusts a UIVisualEffectView's own UIBlurEffect in place: the radius of its blur and the
// opacity of the tint UIKit draws over it. Both animate when set inside a UIView.animate block.
extension UIVisualEffectView {

    /// The radius of the view's blur effect, in points. UIKit picks the default from the effect's style.
    ///
    /// The rest of the effect follows the radius. UIKit pairs its blur with a saturation boost (and,
    /// for the system materials, luminance and brightness changes) and captures the backdrop at a
    /// fraction of the screen's resolution. Setting a radius below UIKit's default scales those
    /// back in proportion and raises the capture resolution to match, so a few points reads as a
    /// crisp depth-of-field blur and zero is indistinguishable from no effect at all. At or above
    /// the default, everything stays as UIKit configured it.
    ///
    /// Set it inside a `UIView.animate` block to animate it with the block's duration, delay and
    /// curve, like any other view property. Set it outside a block to apply it immediately,
    /// cancelling any running animation.
    ///
    /// Reads as zero, and ignores assignments, when the view has no blur to adjust, including
    /// while Reduce Transparency is on. UIKit rebuilds the effect when `effect` or the
    /// appearance changes, so set the radius again afterwards.
    public var blurEffectRadius: CGFloat {
        get {
            backdropView?.layer.value(forKeyPath: blurEffectRadiusKeyPath) as? CGFloat ?? 0.0
        }
        set {
            guard let backdropView, let defaults = BlurEffectDefaults.remembered(for: backdropView) else { return }
            let layer = backdropView.layer
            let radius = max(newValue, 0.0)

            // How much of UIKit's effect to keep. Its companions shrink towards doing nothing as
            // the radius approaches zero, and the capture resolution rises towards the screen's.
            let fraction = defaults.radius > 0.0 ? min(radius / defaults.radius, 1.0) : 0.0
            var values = [(keyPath: blurEffectRadiusKeyPath, value: radius),
                          (keyPath: blurEffectScaleKey, value: 1.0 - (1.0 - defaults.scale) * fraction)]
            for companion in defaults.companions {
                values.append((companion.keyPath, companion.identity + (companion.amount - companion.identity) * fraction))
            }
            defaults.appliedRadius = radius

            guard UIView.areAnimationsEnabled, UIView.inheritedAnimationDuration > 0 else {
                for (keyPath, value) in values {
                    layer.removeAnimation(forKey: keyPath)
                    layer.setValue(value, forKeyPath: keyPath)
                }
                return
            }

            // Inside an animation block, UIKit animates these key paths itself, using the block's
            // settings. Should a system not do that, add equivalent animations instead.
            let timing = BlurAnimationTiming.automatic.timingFunction(from: inFlightBlurEffectRadius ?? defaults.radius,
                                                                      to: radius)
            for (keyPath, value) in values {
                let displayedValue = displayedValue(of: layer, at: keyPath)
                layer.setValue(value, forKeyPath: keyPath)
                guard layer.animation(forKey: keyPath) == nil else { continue }

                let animation = CABasicAnimation(keyPath: keyPath)
                animation.fromValue = displayedValue
                animation.toValue = value
                animation.duration = UIView.inheritedAnimationDuration
                animation.timingFunction = timing
                layer.add(animation, forKey: keyPath)
            }
        }
    }

    /// The opacity of the tint UIKit draws over the blur, from 0 (only the blur) to 1 (UIKit's default).
    ///
    /// It animates when set inside a `UIView.animate` block, like any view's alpha. Reads as 1 when
    /// the view has no tint to adjust; the system materials keep their tint in the blur's filters,
    /// which follow `blurEffectRadius` instead.
    public var dimmingAlpha: CGFloat {
        get { tintViews.first?.alpha ?? 1.0 }
        set { tintViews.forEach { $0.alpha = newValue } }
    }
}

// MARK: - Private

private let blurEffectRadiusKeyPath = "filters.gaussianBlur.inputRadius"
private let blurEffectScaleKey = "scale"

extension UIVisualEffectView {
    /// The view carrying the effect's filters, if UIKit built one.
    private var backdropView: UIView? {
        BlurFilterProvider.findSubview(in: self, containing: "backdrop")
    }

    /// The views UIKit tints the blur with. Some materials use more than one.
    private var tintViews: [UIView] {
        subviews.filter { NSStringFromClass(type(of: $0)).lowercased().contains("subview") }
    }

    /// The radius currently on screen while an animation runs, so an interruption continues from it.
    private var inFlightBlurEffectRadius: CGFloat? {
        guard let layer = backdropView?.layer else { return nil }
        return displayedValue(of: layer, at: blurEffectRadiusKeyPath, onlyWhileAnimating: true)
    }

    /// The value on screen for a key path: the presentation value while it is animating, else the model's.
    private func displayedValue(of layer: CALayer, at keyPath: String, onlyWhileAnimating: Bool = false) -> CGFloat? {
        let isAnimating = layer.animation(forKey: keyPath) != nil
        if onlyWhileAnimating, !isAnimating { return nil }
        let source = isAnimating ? (layer.presentation() ?? layer) : layer
        return source.value(forKeyPath: keyPath) as? CGFloat
    }
}

/// The values UIKit configured for a blur, captured before the first change and kept with the backdrop view.
@MainActor private final class BlurEffectDefaults {

    struct Companion {
        let keyPath: String
        /// The amount at which the filter does nothing.
        let identity: CGFloat
        /// The amount UIKit chose for the style.
        let amount: CGFloat
    }

    let radius: CGFloat
    let scale: CGFloat
    let companions: [Companion]

    /// The radius last applied through the extension. A live radius that differs means UIKit has
    /// rebuilt the effect, for an appearance change say, so its defaults are read again.
    var appliedRadius: CGFloat?

    /// The filters UIKit pairs with its blur, with the amount at which each does nothing.
    private static let companionFilters: [(name: String, identity: CGFloat)] = [
        ("colorSaturate", 1.0), ("colorBrightness", 0.0), ("luminanceCurveMap", 0.0), ("colorContrast", 1.0),
    ]

    static func remembered(for backdropView: UIView) -> BlurEffectDefaults? {
        let layer = backdropView.layer
        if let existing = objc_getAssociatedObject(backdropView, &blurEffectDefaultsHandle) as? BlurEffectDefaults,
           existing.appliedRadius == nil
            || existing.appliedRadius == layer.value(forKeyPath: blurEffectRadiusKeyPath) as? CGFloat {
            return existing
        }
        guard let defaults = BlurEffectDefaults(layer: layer) else { return nil }
        objc_setAssociatedObject(backdropView, &blurEffectDefaultsHandle, defaults, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return defaults
    }

    private init?(layer: CALayer) {
        guard let radius = layer.value(forKeyPath: blurEffectRadiusKeyPath) as? CGFloat else { return nil }
        self.radius = radius
        scale = layer.value(forKey: blurEffectScaleKey) as? CGFloat ?? 1.0
        companions = Self.companionFilters.compactMap { name, identity in
            let keyPath = "filters.\(name).inputAmount"
            guard let amount = layer.value(forKeyPath: keyPath) as? CGFloat else { return nil }
            return Companion(keyPath: keyPath, identity: identity, amount: amount)
        }
    }
}

// A global pointer to use as the associated object handle
@MainActor private var blurEffectDefaultsHandle: UInt8 = 0
