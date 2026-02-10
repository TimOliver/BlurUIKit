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

/// A SwiftUI wrapper for ``VariableBlurView`` that provides a blur overlay whose intensity
/// gradually ramps from one edge to the other. This is useful for softly separating layers of
/// content (such as beneath the iOS status bar or above a toolbar) without hard border lines.
///
/// `VariableBlur` exposes the same configuration options as ``VariableBlurView`` through
/// chainable modifier methods, following standard SwiftUI conventions:
///
/// ```swift
/// VariableBlur(direction: .down)
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
    private var maximumBlurRadius: CGFloat = 3.5
    private var blurStartingInset: GradientSizing?
    private var dimmingTintColor: UIColor? = .systemBackground
    private var dimmingAlpha: DimmingAlpha? = .interfaceStyle(lightModeAlpha: 0.5, darkModeAlpha: 0.25)
    private var dimmingOvershoot: GradientSizing? = .relative(fraction: 0.25)
    private var dimmingStartingInset: GradientSizing?

    // MARK: - Initializer

    /// Creates a new variable blur view.
    /// - Parameter direction: The direction the blur gradient flows, determining which edge
    ///   starts transparent and which reaches full blur intensity. For example, `.down` starts
    ///   transparent at the top and reaches full blur at the bottom, making it ideal for
    ///   status bar overlays. Defaults to `.down`.
    public init(direction: Direction = .down) {
        self.direction = direction
    }

    // MARK: - Modifier Methods

    /// Sets the maximum blur radius applied at the fully-opaque end of the gradient.
    ///
    /// Higher values produce a stronger blur effect. The blur intensity ramps linearly
    /// from zero at the transparent edge up to this value at the opaque edge.
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
    public func blurStartingInset(_ inset: GradientSizing?) -> VariableBlur {
        var copy = self
        copy.blurStartingInset = inset
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
    public func dimmingTintColor(_ color: UIColor?) -> VariableBlur {
        var copy = self
        copy.dimmingTintColor = color
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

    /// Sets an overshoot distance that extends the dimming gradient beyond the blur view's bounds.
    ///
    /// This allows the colored gradient to bleed past the edge of the blur view, creating a
    /// smoother visual transition into the surrounding content. The view's `clipsToBounds` is
    /// disabled to allow this.
    ///
    /// - Parameter overshoot: The overshoot distance, expressed as either an absolute point
    ///   value or a fraction of the view's size. Pass `nil` to confine the dimming gradient
    ///   to the view's bounds. Defaults to `.relative(fraction: 0.25)`.
    /// - Returns: A modified `VariableBlur` with the updated dimming overshoot.
    public func dimmingOvershoot(_ overshoot: GradientSizing?) -> VariableBlur {
        var copy = self
        copy.dimmingOvershoot = overshoot
        return copy
    }

    /// Sets an inset from the opaque edge where the dimming gradient reaches full intensity.
    ///
    /// Similar to ``blurStartingInset(_:)``, but applied to the dimming gradient independently.
    /// This allows the dimming and blur gradients to have different transition profiles.
    ///
    /// - Parameter inset: The distance from the opaque edge, expressed as either an absolute
    ///   point value or a fraction of the view's size. Pass `nil` to span the full view.
    ///   Defaults to `nil`.
    /// - Returns: A modified `VariableBlur` with the updated dimming inset.
    public func dimmingStartingInset(_ inset: GradientSizing?) -> VariableBlur {
        var copy = self
        copy.dimmingStartingInset = inset
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
        view.maximumBlurRadius = maximumBlurRadius
        view.blurStartingInset = blurStartingInset
        view.dimmingTintColor = dimmingTintColor
        view.dimmingAlpha = dimmingAlpha
        view.dimmingOvershoot = dimmingOvershoot
        view.dimmingStartingInset = dimmingStartingInset
    }
}
