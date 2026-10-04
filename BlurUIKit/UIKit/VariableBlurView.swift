//
//  VariableBlurView.swift
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

import UIKit

/// A UIView that contains a blur overlay that gradually 'ramps' up
/// in blur intensity from one edge to the other.
/// This is great for separating separate layers of content (such as the iOS status bar)
/// without any hard border lines.
@available(iOS 14, *)
public class VariableBlurView: UIView {

    /// The possible directions that the gradient of this blur view may flow in.
    public enum Direction {
        case down   // Downwards. Useful for the iOS status bar
        case up     // Upwards. Useful for view controller toolbars
        case left   // Left. Useful for iPadOS sidebar
        case right  // Right. iPadOS sidebar in right-to-left locales
    }

    /// An absolute or relative amount of sizing used to customize the appearance of the blur and gradient views.
    public enum GradientSizing {
        // A distance in on-screen UI points.
        case absolute(position: CGFloat)
        // A relative fraction of this view's size along the gradient direction. (0.0 = 0%, 1.5 = 150%)
        case relative(fraction: CGFloat)
    }

    /// The amount of alpha applied to the colored gradient view over the blur view to add more contrast
    public enum DimmingAlpha {
        // A constant value shared between light and dark mode
        case constant(alpha: CGFloat)
        // Different values between light mode and dark mode.
        case interfaceStyle(lightModeAlpha: CGFloat, darkModeAlpha: CGFloat)
    }

    /// The current direction of the gradient for this blur view
    public var direction: Direction = .down {
        didSet { reset() }
    }

    /// The minimum blur radius at the normally transparent end of the gradient.
    public var minimumBlurRadius = 0.0 {
        didSet { resetBlurMask() }
    }

    /// The maximum blur radius of the blur view when its gradient is at full opacity.
    public var maximumBlurRadius = 3.5 {
        didSet { resetBlurMask() }
    }

    /// Distance inward from the maximum-radius edge where maximum blur is reached.
    /// The remaining region stays at maximum blur. Fractions use the view's bounds.
    /// Insets are clamped to the view's size. Nil means maximum blur at the edge.
    public var blurMaximumRadiusInset: GradientSizing? {
        didSet { resetBlurMask() }
    }

    /// An optional colored gradient to dim the underlying content for better contrast.
    public var dimmingTintColor: UIColor? = .systemBackground {
        didSet {
            makeDimmingViewIfNeeded()
            dimmingView?.tintColor = dimmingTintColor
        }
    }

    /// The alpha value of the colored gradient
    public var dimmingAlpha: DimmingAlpha? = .interfaceStyle(lightModeAlpha: 0.5,
                                                             darkModeAlpha: 0.25) {
        didSet { setNeedsLayout() }
    }

    /// Distance inward from the full-color edge where dimming reaches full strength.
    /// Absolute values are points; fractions use the original view's bounds,
    /// independent of `dimmingClearExtension`. The remaining region stays at full color.
    /// Insets are clamped to the view's size. Nil means full color at the edge.
    public var dimmingFullColorInset: GradientSizing? {
        didSet { resetDimmingImage() }
    }

    /// Extra space outside the clear edge over which dimming transitions from alpha zero.
    /// Absolute values add points; relative values add a fraction of the view's size
    /// (0.25 means 25% extra). Nil means no extension. Negative/non-finite amounts use zero.
    /// Defaults to 25% extra. This never enlarges the blur backdrop.
    /// The receiver and its ancestors must allow overflow for the extension to be visible.
    public var dimmingClearExtension: GradientSizing? = .relative(fraction: 0.25) {
        didSet { resetDimmingImage() }
    }

    /// Allows reflection dimming to overflow while clipping only the actual blur backdrop.
    internal var clipsBlurToBounds: Bool {
        get { blurEffectView.clipsToBounds }
        set { blurEffectView.clipsToBounds = newValue }
    }

    /// The internal visual effect view that provides the blur
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

    /// The current image being used as the gradient mask
    private var gradientMaskImage: CGImage?

    /// Track when the images need to be regenerated
    private var needsUpdate = false

    /// Track the laid-out size, including sizing performed through bounds by SwiftUI or Auto Layout.
    private var lastLayoutSize: CGSize = .zero

    /// An optional dimming gradient shown along with the blur view
    private var dimmingView: UIImageView?

    /// Cached references to internal UIVisualEffectView subviews
    private weak var backdropView: UIView?
    private weak var overlayView: UIView?

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Disable interaction so touches will pass through it
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false

        // Add the visual effect view as a subview
        addSubview(blurEffectView)

        // On iOS 17+, use the modern trait change registration
        if #available(iOS 17, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: VariableBlurView, _: UITraitCollection) in
                self.setNeedsLayout()
            }
        }
    }

    // MARK: - View Lifecycle

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        configureView()
        makeDimmingViewIfNeeded()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        resetForBoundsChange(oldSize: lastLayoutSize)
        lastLayoutSize = bounds.size

        blurEffectView.frame = bounds
        dimmingView?.frame = dimmingViewFrame()

        updateDimmingViewAlpha()
        configureView()

        // A zero-sized layout cannot generate masks. Keep the update pending until we're sized.
        guard needsUpdate, bounds.width > 0.0, bounds.height > 0.0 else { return }
        generateImagesAsNeeded()
        needsUpdate = false
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // On iOS 17+, trait changes are handled via registerForTraitChanges in commonInit()
        if #unavailable(iOS 17) {
            setNeedsLayout()
        }
    }

    // MARK: - Private

    // Configure the blur view by finding internal subviews and applying a fresh blur filter.
    // Subviews are cached via weak references and re-looked-up when needed, since
    // UIVisualEffectView may rebuild its subview hierarchy on trait changes.
    private func configureView() {
        guard superview != nil else { return }

        // Find the overlay view (The one that lightens or darkens these blur views) and hide it.
        if overlayView == nil {
            overlayView = BlurFilterProvider.findSubview(in: blurEffectView, containing: "subview")
        }
        overlayView?.isHidden = true

        // Create a fresh filter and apply it to the backdrop view
        updateBlurFilter()
    }

    // Sets up (or tears down) an image view to display the dimming gradient as needed
    private func makeDimmingViewIfNeeded() {
        guard let dimmingTintColor else {
            dimmingView?.removeFromSuperview()
            dimmingView = nil
            return
        }

        // Don't bother spinning up this view until we're added to a superview
        // to save on the churn of setting a default value, and then promptly changing it.
        guard superview != nil, dimmingView == nil else {
            return
        }

        let imageView = UIImageView()
        imageView.tintColor = dimmingTintColor
        addSubview(imageView)

        dimmingView = imageView
        setNeedsUpdate()
    }

    // Update the parameters of the blur filter when the state in this view changes
    private func updateBlurFilter() {
        guard let gradientMaskImage, let variableBlurFilter = BlurFilterProvider.blurFilter(named: "variableBlur") else { return }
        variableBlurFilter.setValue(gradientMaskImage, forKey: "inputMaskImage")
        variableBlurFilter.setValue(effectiveMaximumBlurRadius, forKey: "inputRadius")
        variableBlurFilter.setValue(true, forKey: "inputNormalizeEdges")

        if backdropView == nil {
            backdropView = BlurFilterProvider.findSubview(in: blurEffectView, containing: "backdrop")
        }
        backdropView?.layer.filters = [variableBlurFilter]
        backdropView?.layer.setValue(0.75, forKey: "scale")
    }

    // Update the alpha value of the colored gradient as needed
    private func updateDimmingViewAlpha() {
        guard let dimmingAlpha else {
            dimmingView?.alpha = 0.0
            return
        }

        switch dimmingAlpha {
        case .constant(alpha: let alpha):
            dimmingView?.alpha = alpha
        case .interfaceStyle(lightModeAlpha: let lightModeAlpha,
                             darkModeAlpha: let darkModeAlpha):
            let isDarkMode = traitCollection.userInterfaceStyle == .dark
            dimmingView?.alpha = isDarkMode ? darkModeAlpha : lightModeAlpha
        }
    }

    // Extend only the clear edge of the dimming view.
    private func dimmingViewFrame() -> CGRect {
        var frame = bounds
        switch direction {
        case .down, .up:
            let adjustedHeight = gradientLength(clearExtension: dimmingClearExtension)
            frame.size.height = adjustedHeight
            if direction == .up { frame.origin.y -= adjustedHeight - bounds.height }
        case .left, .right:
            let adjustedWidth = gradientLength(clearExtension: dimmingClearExtension)
            frame.size.width = adjustedWidth
            if direction == .right { frame.origin.x -= adjustedWidth - bounds.width }
        }
        return frame
    }
}

// MARK: Image Reset

@available(iOS 14, *)
extension VariableBlurView {
    /// Schedules the backdrop filter to be recreated without invalidating its gradient images.
    internal func setNeedsBlurFilterUpdate() {
        setNeedsLayout()
    }

    // Reset if a bounds change means we have to regenerate the images
    private func resetForBoundsChange(oldSize: CGSize) {
        let needsReset = {
            switch direction {
            case .down, .up:
                return bounds.height != oldSize.height
            case .left, .right:
                return bounds.width != oldSize.width
            }
        }()
        guard needsReset else { return }
        reset()
    }

    // Reset both the blur mask, and the dimming gradient
    private func reset() {
        resetBlurMask()
        resetDimmingImage()
    }

    // Some state changed to the point where we need to regenerate the blur mask image
    private func resetBlurMask() {
        gradientMaskImage = nil
        setNeedsUpdate()
    }

    // Some state changed to the point where we need to regenerate the dimming mask image
    private func resetDimmingImage() {
        dimmingView?.image = nil
        setNeedsUpdate()
    }

    // Sets that the blur view needs to be updated in the next layout pass
    // This allows a variety of settings to be set in one run loop, with them all being applied next loop
    private func setNeedsUpdate() {
        needsUpdate = true
        setNeedsLayout()
    }
}

// MARK: Image Generation

@available(iOS 14, *)
extension VariableBlurView {

    private func generateImagesAsNeeded() {
        // Update the blur view's gradient mask
        if gradientMaskImage == nil {
            gradientMaskImage = fetchGradientImage(fullStrengthInset: blurMaximumRadiusInset,
                                                   minimumAlpha: minimumBlurMaskAlpha)
            updateBlurFilter()
        }

        // Dimming has its own 0-to-1 gradient, independent of the blur radius range.
        // Its overall opacity is applied to the image view by updateDimmingViewAlpha().
        if dimmingTintColor != nil, dimmingView?.image == nil {
            makeDimmingViewIfNeeded()
            if let dimmingImage = fetchGradientImage(fullStrengthInset: dimmingFullColorInset,
                                                     smooth: true,
                                                     clearExtension: dimmingClearExtension) {
                dimmingView?.image = UIImage(cgImage: dimmingImage).withRenderingMode(.alwaysTemplate)
            }
        }
    }

    /// Generates a gradient bitmap to be used as a blur mask or dimming gradient image.
    private func fetchGradientImage(
        fullStrengthInset: GradientSizing?,
        smooth: Bool = false,
        clearExtension: GradientSizing? = nil,
        minimumAlpha: CGFloat = 0.0
    ) -> CGImage? {
        // Skip if we're not sized yet.
        guard bounds.width > 0.0, bounds.height > 0.0 else { return nil }

        // Determine size based on direction (1 pixel wide/tall strip)
        let isVertical = direction == .up || direction == .down
        let imageLength = gradientLength(clearExtension: clearExtension)
        guard let length = Int(exactly: imageLength), length > 0 else { return nil }

        // Both inset fractions refer to the original bounds, even when dimming extends outside.
        let startLocation = insetPoints(fullStrengthInset) / CGFloat(length)

        // For up/right directions, the gradient runs in reverse (transparent to opaque)
        let reversed = direction == .up || direction == .right

        return BlurGradientImageRenderer.makeGradientImage(
            length: length,
            isVertical: isVertical,
            startLocation: startLocation,
            reversed: reversed,
            smooth: smooth,
            minimumAlpha: minimumAlpha
        )
    }

    /// The minimum radius expressed as a normalized blur-mask value.
    private var minimumBlurMaskAlpha: CGFloat {
        let maximumRadius = effectiveMaximumBlurRadius
        guard maximumRadius > 0.0 else { return 0.0 }
        guard !minimumBlurRadius.isNaN else { return 0.0 }

        let minimumRadius = min(max(minimumBlurRadius, 0.0), maximumRadius)
        return CGFloat(minimumRadius / maximumRadius)
    }

    /// The validated radius passed to the underlying blur filter.
    private var effectiveMaximumBlurRadius: Double {
        guard maximumBlurRadius.isFinite else { return 0.0 }
        return max(maximumBlurRadius, 0.0)
    }

    private var gradientAxisSize: CGFloat {
        direction == .up || direction == .down ? bounds.height : bounds.width
    }

    /// Resolve an inset against the original bounds, not the extended gradient image.
    private func insetPoints(_ inset: GradientSizing?) -> CGFloat {
        guard let inset else { return 0 }
        let size = gradientAxisSize
        let points: CGFloat
        switch inset {
        case .absolute(let position): points = position
        case .relative(let fraction): points = min(max(fraction.isFinite ? fraction : 0, 0), 1) * size
        }
        return min(max(points.isFinite ? points : 0, 0), size)
    }

    /// A bitmap-sized gradient with optional additional space at its clear edge.
    private func gradientLength(clearExtension extensionAmount: GradientSizing?) -> CGFloat {
        let size = gradientAxisSize
        let extra: CGFloat
        switch extensionAmount {
        case .absolute(let position):
            extra = position.isFinite ? max(position, 0) : 0
        case .relative(let fraction):
            extra = size * (fraction.isFinite ? max(fraction, 0) : 0)
        case nil:
            extra = 0
        }
        let length = size + extra
        guard length.isFinite, length < CGFloat(Int.max) else { return size.rounded(.up) }
        return length.rounded(.up)
    }
}
