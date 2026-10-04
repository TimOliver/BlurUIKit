//
//  VariableBlur.swift
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

import SwiftUI
#if canImport(BlurSwiftUI)
import BlurUIKit
#endif

/// A SwiftUI wrapper for ``VariableBlurView`` that provides a blur overlay whose intensity
/// gradually ramps from one edge to the other. This is useful for softly separating layers of
/// content (such as beneath the iOS status bar or above a toolbar) without hard border lines.
///
/// `VariableBlur` exposes the same configuration options as ``VariableBlurView`` through
/// chainable modifier methods, following standard SwiftUI conventions:
///
/// ```swift
/// VariableBlur(direction: .down)
///     .minimumBlurRadius(1)
///     .maximumBlurRadius(5)
///     .dimmingTintColor(.black)
///     .dimmingAlpha(.constant(alpha: 0.3))
/// ```
///
/// All default values match those of ``VariableBlurView``, so a plain `VariableBlur()` produces
/// the same result as a default `VariableBlurView`.
@available(iOS 14, *)
public struct VariableBlur: UIViewRepresentable {

    public typealias Direction = VariableBlurView.Direction
    public typealias GradientSizing = VariableBlurView.GradientSizing
    public typealias DimmingAlpha = VariableBlurView.DimmingAlpha

    // MARK: - Stored Properties

    private var direction: Direction
    private var minimumBlurRadius: CGFloat = 0.0
    private var maximumBlurRadius: CGFloat = 3.5
    private var blurMaximumRadiusInset: GradientSizing?
    private var dimmingTintColor: UIColor? = .systemBackground
    private var dimmingAlpha: DimmingAlpha? = .interfaceStyle(lightModeAlpha: 0.5, darkModeAlpha: 0.25)
    private var dimmingClearExtension: GradientSizing? = .relative(fraction: 0.25)
    private var dimmingFullColorInset: GradientSizing?
    private var passesTouchesThrough: Bool = true

    /// Set by the deprecated `dimmingStartingInset(_:)` to apply its inset through the matching
    /// deprecated `VariableBlurView` property, which preserves the inset's original meaning.
    private var applyDeprecatedDimmingStartingInset: ((VariableBlurView) -> Void)?

    // MARK: - Initializer

    /// Creates a new variable blur view.
    /// - Parameter direction: The direction the blur gradient flows, determining which edge
    ///   starts at minimum intensity and which reaches full blur intensity. For example, `.down`
    ///   starts at maximum intensity at the top and reaches minimum blur at the bottom, making it ideal for
    ///   status bar overlays. Defaults to `.down`.
    public init(direction: Direction = .down) {
        self.direction = direction
    }

    // MARK: - Modifier Methods

    /// Sets the minimum blur radius applied at the normally transparent end of the gradient.
    ///
    /// Use a value above zero when the blur should remain active across the full view rather
    /// than fading away completely.
    ///
    /// - Parameter radius: The minimum blur radius in points. Defaults to `0.0`.
    /// - Returns: A modified `VariableBlur` with the updated minimum blur radius.
    public func minimumBlurRadius(_ radius: CGFloat) -> VariableBlur {
        var copy = self
        copy.minimumBlurRadius = radius
        return copy
    }

    /// Sets the maximum blur radius applied at the fully-opaque end of the gradient.
    ///
    /// Higher values produce a stronger blur effect. The blur intensity ramps linearly
    /// from ``minimumBlurRadius(_:)`` up to this value at the opaque edge.
    ///
    /// - Parameter radius: The maximum blur radius in points. Defaults to `3.5`.
    /// - Returns: A modified `VariableBlur` with the updated blur radius.
    public func maximumBlurRadius(_ radius: CGFloat) -> VariableBlur {
        var copy = self
        copy.maximumBlurRadius = radius
        return copy
    }

    /// Sets an inset from the opaque edge where the blur gradient reaches full intensity.
    ///
    /// By default, the blur gradient spans the entire length of the view. Setting an inset
    /// causes the blur to reach its maximum intensity before the opaque edge, leaving the
    /// remaining portion at full blur.
    ///
    /// - Parameter inset: The distance from the opaque edge, expressed as either an absolute
    ///   point value or a fraction of the view's size. Pass `nil` to span the full view. Defaults to `nil`.
    /// - Returns: A modified `VariableBlur` with the updated blur inset.
    public func blurMaximumRadiusInset(_ inset: GradientSizing?) -> VariableBlur {
        var copy = self
        copy.blurMaximumRadiusInset = inset
        return copy
    }

    /// Sets the tint color used for the optional dimming gradient overlaid on top of the blur.
    ///
    /// The dimming gradient provides additional contrast between the blurred region and
    /// the content beneath it. It uses the same directional flow as the blur gradient.
    ///
    /// - Parameter color: The color for the dimming gradient, rendered as a template image
    ///   so its tint can adapt to trait changes. Pass `nil` to remove the dimming gradient
    ///   entirely. Defaults to `.systemBackground`.
    /// - Returns: A modified `VariableBlur` with the updated dimming color.
    public func dimmingTintColor(_ color: Color?) -> VariableBlur {
        var copy = self
        copy.dimmingTintColor = color.map { UIColor($0) }
        return copy
    }

    /// Sets the alpha value of the dimming gradient overlay.
    ///
    /// This controls the opacity of the colored gradient specified by ``dimmingTintColor(_:)``.
    /// You can supply a single constant alpha, or separate values for light and dark mode
    /// to fine-tune contrast in each appearance.
    ///
    /// - Parameter alpha: The alpha configuration for the dimming gradient. Pass `nil` to
    ///   hide the dimming overlay (alpha 0). Defaults to
    ///   `.interfaceStyle(lightModeAlpha: 0.5, darkModeAlpha: 0.25)`.
    /// - Returns: A modified `VariableBlur` with the updated dimming alpha.
    public func dimmingAlpha(_ alpha: DimmingAlpha?) -> VariableBlur {
        var copy = self
        copy.dimmingAlpha = alpha
        return copy
    }

    /// Adds dimming space outside the clear edge, without extending the blur backdrop.
    /// Relative values are extra fractions of the view's size (0.25 means 25% extra).
    /// Absolute values are extra points. Nil disables extension; the default is 25% extra.
    /// Negative/non-finite amounts use zero. Ancestors must allow overflow to display it.
    public func dimmingClearExtension(_ extensionAmount: GradientSizing?) -> VariableBlur {
        var copy = self
        copy.dimmingClearExtension = extensionAmount
        return copy
    }

    /// Sets the distance inward from the full-color edge where dimming reaches full strength.
    /// Fractions use the original view's bounds, independent of the clear-side extension.
    /// The remaining region stays at full color. Insets are clamped to the view's size.
    /// Nil means full color at the edge.
    public func dimmingFullColorInset(_ inset: GradientSizing?) -> VariableBlur {
        var copy = self
        copy.dimmingFullColorInset = inset
        copy.applyDeprecatedDimmingStartingInset = nil
        return copy
    }
    
    /// Controls whether touch events pass through this blur view to underlying views.
    ///
    /// When set to `true`, the blur view does not intercept touch events,
    /// allowing interactions (such as taps and gestures) to reach the views
    /// beneath it. When set to `false`, the blur view blocks touch events,
    /// preventing underlying views from receiving them.
    ///
    /// This is particularly useful when using `VariableBlur` as a purely
    /// decorative overlay that should not interfere with user interaction.
    ///
    /// - Parameter bool: A Boolean value indicating whether touches should
    ///   pass through the blur view. Defaults to `true`.
    /// - Returns: A modified `VariableBlur` with updated touch pass-through behavior.
    public func passesTouchesThrough(_ bool: Bool) -> VariableBlur {
        var copy = self
        copy.passesTouchesThrough = bool
        return copy
    }

    // MARK: - UIViewRepresentable

    /// Creates the underlying ``VariableBlurView`` and applies the current configuration.
    public func makeUIView(context: Context) -> VariableBlurView {
        let view = VariableBlurView()
        applyProperties(to: view)
        return view
    }

    /// Called by SwiftUI whenever the view's state changes, syncing all
    /// properties to the underlying ``VariableBlurView``.
    public func updateUIView(_ uiView: VariableBlurView, context: Context) {
        applyProperties(to: uiView)
    }

    /// Transfers all stored properties from this struct onto the given view instance.
    private func applyProperties(to view: VariableBlurView) {
        view.direction = direction
        view.minimumBlurRadius = minimumBlurRadius
        view.maximumBlurRadius = maximumBlurRadius
        view.blurMaximumRadiusInset = blurMaximumRadiusInset
        view.dimmingTintColor = dimmingTintColor
        view.dimmingAlpha = dimmingAlpha
        view.dimmingClearExtension = dimmingClearExtension
        if let applyDeprecatedDimmingStartingInset {
            applyDeprecatedDimmingStartingInset(view)
        } else {
            view.dimmingFullColorInset = dimmingFullColorInset
        }
        view.isUserInteractionEnabled = !passesTouchesThrough
    }
}

// MARK: - Deprecated Modifiers

@available(iOS 14, *)
extension VariableBlur {
    /// Sets an inset from the opaque edge where the blur gradient reaches full intensity.
    @available(*, deprecated, renamed: "blurMaximumRadiusInset(_:)")
    public func blurStartingInset(_ inset: GradientSizing?) -> VariableBlur {
        blurMaximumRadiusInset(inset)
    }

    /// Sets the total length of the dimming gradient, extending past the view's clear edge.
    /// Relative values include the view itself, so `.relative(fraction: 1.25)` adds 25%.
    @available(*, deprecated, message: "Use dimmingClearExtension(_:), whose relative values measure only the extra space: .relative(fraction: 1.25) becomes .relative(fraction: 0.25).")
    public func dimmingOvershoot(_ overshoot: GradientSizing?) -> VariableBlur {
        guard case .relative(let fraction) = overshoot else { return dimmingClearExtension(overshoot) }
        return dimmingClearExtension(.relative(fraction: fraction - 1.0))
    }

    /// Sets an inset from the opaque edge where the dimming gradient reaches full intensity.
    /// Relative values are fractions of the whole dimming gradient, including any overshoot.
    @available(*, deprecated, message: "Use dimmingFullColorInset(_:), whose relative values are fractions of the view's size rather than of the extended dimming gradient.")
    public func dimmingStartingInset(_ inset: GradientSizing?) -> VariableBlur {
        var copy = dimmingFullColorInset(inset)
        copy.applyDeprecatedDimmingStartingInset = { $0.dimmingStartingInset = inset }
        return copy
    }
}
