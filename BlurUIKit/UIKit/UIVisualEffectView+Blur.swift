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
// opacity of the tint UIKit draws over it. Both animate when set inside a UIView.animate block,
// and both are kept in place across the appearance changes that make UIKit reset its effect.
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
    /// while Reduce Transparency is on. Setting either this or `dimmingAlpha` adds a hidden,
    /// zero-sized helper view to `contentView`, which restores both values whenever UIKit resets
    /// its effect for an appearance change. Changing `effect` builds a new blur, so set them again.
    public var blurEffectRadius: CGFloat {
        get {
            backdropView?.layer.value(forKeyPath: blurEffectRadiusKeyPath) as? CGFloat ?? 0.0
        }
        set {
            let radius = max(newValue, 0.0)
            BlurEffectState.state(for: self).requestedRadius = radius
            applyBlurEffectRadius(radius)
        }
    }

    /// The opacity of the tint UIKit draws over the blur, from 0 (only the blur) to 1 (UIKit's default).
    ///
    /// It animates when set inside a `UIView.animate` block, like any view's alpha, and is kept in
    /// place across appearance changes. Reads as 1 when the view has no tint to adjust; the system
    /// materials keep their tint in the blur's filters, which follow `blurEffectRadius` instead.
    public var dimmingAlpha: CGFloat {
        get { tintViews.first?.alpha ?? 1.0 }
        set {
            BlurEffectState.state(for: self).requestedDimmingAlpha = newValue
            tintViews.forEach { $0.alpha = newValue }
        }
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

    /// Sets the radius, and the companion filters and capture scale that follow it.
    private func applyBlurEffectRadius(_ radius: CGFloat) {
        guard let backdropView, let defaults = BlurEffectDefaults.remembered(for: backdropView) else { return }
        let layer = backdropView.layer

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

    /// Puts back whatever UIKit reset while re-resolving its effect for new traits.
    fileprivate func restoreBlurEffectValuesIfReset() {
        guard let state = BlurEffectState.existing(for: self) else { return }
        if let radius = state.requestedRadius, blurEffectRadius != radius {
            applyBlurEffectRadius(radius)
        }
        if let alpha = state.requestedDimmingAlpha {
            for tintView in tintViews where tintView.alpha != alpha {
                tintView.alpha = alpha
            }
        }
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

/// What the app asked for, kept with the effect view so it can be restored after UIKit resets the effect.
@MainActor private final class BlurEffectState {
    var requestedRadius: CGFloat?
    var requestedDimmingAlpha: CGFloat?
    private var observer: BlurEffectTraitObserver?

    static func existing(for effectView: UIVisualEffectView) -> BlurEffectState? {
        objc_getAssociatedObject(effectView, &blurEffectStateHandle) as? BlurEffectState
    }

    static func state(for effectView: UIVisualEffectView) -> BlurEffectState {
        if let existing = existing(for: effectView) { return existing }
        let state = BlurEffectState()
        state.observer = BlurEffectTraitObserver.install(in: effectView)
        objc_setAssociatedObject(effectView, &blurEffectStateHandle, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }
}

/// A hidden view inside the content view. UIKit re-resolves its effect for new traits before the
/// content view's subviews hear about them, so this is the earliest point at which the values can
/// be restored without a frame of UIKit's defaults showing.
@MainActor private final class BlurEffectTraitObserver: UIView {
    weak var effectView: UIVisualEffectView?

    static func install(in effectView: UIVisualEffectView) -> BlurEffectTraitObserver {
        let observer = BlurEffectTraitObserver(frame: .zero)
        observer.effectView = effectView
        observer.isHidden = true
        observer.isUserInteractionEnabled = false
        if #available(iOS 17, *) {
            observer.registerForTraitChanges(UITraitCollection.systemTraitsAffectingColorAppearance) {
                (observer: BlurEffectTraitObserver, _: UITraitCollection) in
                observer.effectView?.restoreBlurEffectValuesIfReset()
            }
        }
        effectView.contentView.addSubview(observer)
        return observer
    }

    // Only needed below iOS 17. Marked deprecated to match the superclass and silence the warning.
    @available(iOS, deprecated: 17.0, message: "Use the trait change registration APIs declared in the UITraitChangeObservable protocol")
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17) {
            effectView?.restoreBlurEffectValuesIfReset()
        }
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
    /// re-resolved the effect, for an appearance change say, so its filter values are read again.
    var appliedRadius: CGFloat?

    /// The filters UIKit pairs with its blur, with the amount at which each does nothing.
    private static let companionFilters: [(name: String, identity: CGFloat)] = [
        ("colorSaturate", 1.0), ("colorBrightness", 0.0), ("luminanceCurveMap", 0.0), ("colorContrast", 1.0),
    ]

    static func remembered(for backdropView: UIView) -> BlurEffectDefaults? {
        let layer = backdropView.layer
        let existing = objc_getAssociatedObject(backdropView, &blurEffectDefaultsHandle) as? BlurEffectDefaults
        if let existing,
           existing.appliedRadius == nil
            || existing.appliedRadius == layer.value(forKeyPath: blurEffectRadiusKeyPath) as? CGFloat {
            return existing
        }
        // UIKit leaves the capture scale alone when it re-resolves its filters, so the scale on
        // the layer may be ours. Keep the one captured first for this backdrop.
        guard let defaults = BlurEffectDefaults(layer: layer, scale: existing?.scale) else { return nil }
        objc_setAssociatedObject(backdropView, &blurEffectDefaultsHandle, defaults, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return defaults
    }

    private init?(layer: CALayer, scale: CGFloat?) {
        guard let radius = layer.value(forKeyPath: blurEffectRadiusKeyPath) as? CGFloat else { return nil }
        self.radius = radius
        self.scale = scale ?? layer.value(forKey: blurEffectScaleKey) as? CGFloat ?? 1.0
        companions = Self.companionFilters.compactMap { name, identity in
            let keyPath = "filters.\(name).inputAmount"
            guard let amount = layer.value(forKeyPath: keyPath) as? CGFloat else { return nil }
            return Companion(keyPath: keyPath, identity: identity, amount: amount)
        }
    }
}

// Global pointers to use as the associated object handles
@MainActor private var blurEffectStateHandle: UInt8 = 0
@MainActor private var blurEffectDefaultsHandle: UInt8 = 0
