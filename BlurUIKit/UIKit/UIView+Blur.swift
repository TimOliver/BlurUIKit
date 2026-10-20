//
//  UIView+Blur.swift
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

// Applies a gaussian blur to a UIView without blurring the content below it.
extension UIView {

    /// Set the gaussian blur radius of this view, cancelling any running blur animation.
    /// If a replacement filter cannot be created, the current blur and animation are preserved.
    public var blurRadius: CGFloat {
        get {
            guard let filter = blurFilter else { return 0.0 }
            return filter.value(forKey: "inputRadius") as? CGFloat ?? 0.0
        }

        set {
            // A filter with no radius still forces offscreen rendering, so remove it entirely.
            guard newValue > 0.0 else {
                layer.removeAnimation(forKey: blurAnimationKey)
                removeBlurFilter()
                return
            }
            guard installBlurFilter(radius: newValue) != nil else { return }
            layer.removeAnimation(forKey: blurAnimationKey)
        }
    }

    /// Apply a gaussian blur to this view with an animation.
    /// An interrupted blur animation continues from its currently displayed radius, and a
    /// radius that is already showing is applied without an animation.
    /// If a replacement filter cannot be created, the current blur and animation are preserved.
    /// - Parameters:
    ///   - radius: The blur radius to animate to.
    ///   - duration: How long the animation runs. Defaults to 0.45 seconds.
    ///     Zero or negative durations apply the radius immediately, whatever the delay.
    ///   - delay: How long the current radius holds before the animation starts. Defaults to zero.
    ///     The filter stays in place throughout, so a blur that clears after a delay is still
    ///     showing while it waits.
    ///   - timing: How the radius is paced over the duration. Defaults to `.automatic`, which
    ///     eases out when clearing a blur and eases in when applying one, so the visible change
    ///     is spread evenly either way. Choose `.linear` for a constant rate, or `.custom` to
    ///     supply any timing function.
    public func setBlurRadiusAnimated(radius: CGFloat,
                                      duration: TimeInterval = 0.45,
                                      delay: TimeInterval = 0,
                                      timing: BlurAnimationTiming = .automatic) {
        if duration <= 0 {
            blurRadius = radius
            return
        }

        let currentRadius = inFlightBlurRadius ?? blurRadius

        // Nothing to animate when that radius is already showing. Pin an in-flight animation
        // where it is; otherwise leave the layer alone rather than install an idle filter.
        guard radius != currentRadius else {
            if layer.animation(forKey: blurAnimationKey) != nil { blurRadius = radius }
            return
        }

        // Keep a filter in place even when clearing the blur, so there is something to animate.
        guard let filter = installBlurFilter(radius: radius) else { return }

        let blurAnimation = CABasicAnimation(keyPath: blurAnimationKey)
        blurAnimation.fromValue = currentRadius
        blurAnimation.toValue = radius
        blurAnimation.duration = duration
        blurAnimation.timingFunction = timing.timingFunction(from: currentRadius, to: radius)
        if delay > 0 {
            // Fill backwards so the starting radius shows during the delay, rather than the
            // model's new radius, which the layer already holds.
            blurAnimation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
            blurAnimation.fillMode = .backwards
        }

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            // Once the blur has fully cleared, remove the now-idle filter, unless
            // another blur change has replaced it in the meantime.
            guard let self, radius <= 0.0, self.blurFilter === filter else { return }
            self.removeBlurFilter()
        }
        self.layer.add(blurAnimation, forKey: blurAnimationKey)
        CATransaction.commit()
    }
}

// MARK: - Animation Timing

/// How an animated change of blur radius is paced over its duration.
///
/// Perceived sharpness is not linear in a gaussian blur's radius: a view looks almost equally
/// blurred at a radius of 24 or 12, and only the last few points bring its detail back. Pacing
/// the radius at a constant rate therefore looks uneven: holding and then snapping sharp when
/// clearing, or snapping blurred and then idling when applying. The blur curves bend the radius
/// so the visible change is spread evenly, in whichever direction it runs.
///
/// This is `@unchecked Sendable` only because `CAMediaTimingFunction` isn't marked `Sendable`.
/// It's safe to share, since a timing function's control points can't change after it's created.
public enum BlurAnimationTiming: @unchecked Sendable {

    /// `.easeOut` when the radius is decreasing and `.easeIn` when it is increasing. The default.
    case automatic

    /// A constant rate of radius change.
    case linear

    /// `CAMediaTimingFunction.blurEaseOut`, which suits clearing a blur.
    case easeOut

    /// `CAMediaTimingFunction.blurEaseIn`, which suits applying a blur.
    case easeIn

    /// Any Core Animation timing function.
    case custom(CAMediaTimingFunction)

    /// The timing function to apply to a change between two radii.
    /// - Parameters:
    ///   - currentRadius: The radius the animation starts from.
    ///   - radius: The radius it ends at.
    /// - Returns: The curve for this timing, resolved by direction for `.automatic`.
    func timingFunction(from currentRadius: CGFloat, to radius: CGFloat) -> CAMediaTimingFunction {
        switch self {
        case .automatic:
            return radius < currentRadius ? .blurEaseOut : .blurEaseIn
        case .linear:
            return CAMediaTimingFunction(name: .linear)
        case .easeOut:
            return .blurEaseOut
        case .easeIn:
            return .blurEaseIn
        case .custom(let timingFunction):
            return timingFunction
        }
    }
}

// MARK: - Timing Curves

extension CAMediaTimingFunction {

    /// A cubic Bézier ease-out for clearing a blur, steeper than the system `.easeOut`.
    ///
    /// Its control points are (0.2, 0.9) and (0.4, 1): the curve covers most of its distance in
    /// the first fifth of the duration, then decelerates for the rest. The system `.easeOut`,
    /// with control points (0, 0) and (0.58, 1), is far gentler and leaves too much radius late.
    ///
    /// The steepness is deliberate. Clearing a blur means passing quickly through the large
    /// radii, where nothing visible changes, and slowly through the last few points, where the
    /// detail returns. See `BlurAnimationTiming` for why a constant rate looks uneven.
    public static var blurEaseOut: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.4, 1)
    }

    /// A cubic Bézier ease-in for applying a blur: `blurEaseOut` reflected through its centre.
    ///
    /// Its control points are (0.6, 0) and (0.8, 0.1). Applying a blur runs the radius the other
    /// way, so the curve must linger through the first few points, where every point of radius
    /// shows, and then race through the large radii, where nothing visible changes. Using the
    /// ease-out in this direction would look like an instant blur followed by nothing.
    public static var blurEaseIn: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.6, 0, 0.8, 0.1)
    }
}

// MARK: - Private

private let blurAnimationKey = "filters.gaussianBlur.inputRadius"

// A global pointer to use as the associated object handle
@MainActor private var BlurFilterObjectHandle: UInt8 = 0

extension UIView {
    // Only use presentation values while our blur animation is running. Otherwise the
    // presentation layer may still contain an earlier, uncommitted model value.
    private var inFlightBlurRadius: CGFloat? {
        guard let animation = layer.animation(forKey: blurAnimationKey) else { return nil }
        let filter = layer.presentation()?.filters?.compactMap { $0 as? NSObject }.first {
            $0.value(forKey: "name") as? String == "gaussianBlur"
        }
        // Before the first transaction commits there may be no presentation filter yet.
        // In that case, the existing animation is still at its starting radius.
        return filter?.value(forKey: "inputRadius") as? CGFloat
            ?? (animation as? CABasicAnimation)?.fromValue as? CGFloat
    }

    // Save the associated filter with this view so it's quicker to fetch on subsequent calls
    private var blurFilter: NSObject? {
        get {
            return objc_getAssociatedObject(self, &BlurFilterObjectHandle) as? NSObject
        }
        set {
            objc_setAssociatedObject(self, &BlurFilterObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // We can't update the radius of an existing filter. Prepare its replacement
    // before removing it, so an unavailable filter leaves the working blur intact.
    private func installBlurFilter(radius: CGFloat) -> NSObject? {
        guard let newFilter = BlurFilterProvider.shared.makeFilter(named: "gaussianBlur") else { return nil }
        newFilter.setValue(radius, forKey: "inputRadius")
        removeBlurFilter()
        self.layer.filters = (self.layer.filters ?? []) + [newFilter]
        self.blurFilter = newFilter
        return newFilter
    }

    // Remove the blur filter from this view's layer, leaving any other filters untouched
    private func removeBlurFilter() {
        guard let filter = self.blurFilter else { return }
        self.layer.filters?.removeAll { ($0 as? NSObject) == filter }
        if self.layer.filters?.isEmpty == true {
            self.layer.filters = nil
        }
        self.blurFilter = nil
    }
}
