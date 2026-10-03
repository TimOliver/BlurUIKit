//
//  ReflectionBlurView.swift
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

/// A UIView that vertically mirrors its hosted content,
/// and applies a variable blur effect to the reflection.
@available(iOS 14, *)
public class ReflectionBlurView: UIView {

    // MARK: - Public Properties

    /// The container view that holds all of the view content that will be reflected.
    /// An empty one is created by default, but it can be replaced with an external view as well.
    public var contentView: UIView {
        didSet {
            guard contentView !== oldValue else { return }
            oldValue.removeFromSuperview()
            installContentView()
        }
    }

    /// The opacity of the reflected content, from `0.0` to `1.0`.
    /// Values outside this range are clamped when applied.
    public var reflectionAlpha: CGFloat = 0.5 {
        didSet { updateReflectionAppearance() }
    }

    /// Hides the reflection while leaving the source content visible.
    /// When hidden, the additional replicator instance is disabled entirely.
    public var isReflectionHidden = false {
        didSet { updateReflectionAppearance() }
    }

    /// The maximum blur radius applied at the far edge of the reflection.
    public var maximumBlurRadius: Double {
        get { blurView.maximumBlurRadius }
        set { blurView.maximumBlurRadius = newValue }
    }

    /// The minimum blur radius applied where the reflection begins.
    public var minimumBlurRadius: Double {
        get { blurView.minimumBlurRadius }
        set { blurView.minimumBlurRadius = newValue }
    }

    /// The position at which the variable blur begins transitioning.
    public var blurStartingInset: VariableBlurView.GradientSizing? {
        get { blurView.blurStartingInset }
        set { blurView.blurStartingInset = newValue }
    }

    /// An optional color gradient used to dim the reflection as it moves away from the source.
    public var dimmingTintColor: UIColor? {
        get { blurView.dimmingTintColor }
        set { blurView.dimmingTintColor = newValue }
    }

    /// The opacity applied to the dimming gradient.
    public var dimmingAlpha: VariableBlurView.DimmingAlpha? {
        get { blurView.dimmingAlpha }
        set { blurView.dimmingAlpha = newValue }
    }

    /// The position at which the dimming gradient begins transitioning.
    public var dimmingStartingInset: VariableBlurView.GradientSizing? {
        get { blurView.dimmingStartingInset }
        set { blurView.dimmingStartingInset = newValue }
    }

    // MARK: - Public Methods

    /// Marks the reflection's blur backdrop to be refreshed on the next layout pass.
    ///
    /// Call this while content is moving without changing the reflection view's geometry,
    /// such as from `scrollViewDidScroll(_:)`. Multiple calls made before the next layout
    /// pass are automatically coalesced.
    public func setNeedsReflectionUpdate() {
        blurView.setNeedsBlurFilterUpdate()
    }

    // MARK: - Private Properties

    /// Hosts the single source subtree and creates its reflected layer instance.
    private let replicatorView = BlurReplicatorView()

    /// Applies variable blur and dimming over the reflection and beneath the source content.
    private let blurView: VariableBlurView = {
        let blurView = VariableBlurView()
        blurView.direction = .up
        blurView.maximumBlurRadius = 4.5
        blurView.activeGradientExtent = .relative(fraction: 0.5)
        blurView.dimmingOvershoot = nil
        blurView.clipsToBounds = true
        return blurView
    }()

    /// The most recently calculated source region, in the receiver's coordinate space.
    private var sourceFrame = CGRect.zero

    /// The most recently calculated reflection region, in the receiver's coordinate space.
    private var reflectionFrame = CGRect.zero

    // MARK: - Initialization

    /// Create a new instance of ReflectionBlurView providing an external content view.
    /// The receiver's outer size is intentionally independent from the content view's size;
    /// set it with `frame`, constraints, or another normal UIKit layout mechanism.
    /// - Parameter contentView: The content view that will be placed in the top half.
    public init(contentView: UIView) {
        self.contentView = contentView
        super.init(frame: .zero)
        commonInit()
    }

    /// Create a new instance of ReflectionBlurView with the provided frame.
    /// - Parameter frame: The frame of this new view
    public override init(frame: CGRect) {
        contentView = UIView()
        super.init(frame: frame)
        commonInit()
    }

    /// Create a new instance of ReflectionBlurView with the provided coder.
    /// - Parameter coder: The coder object (from Interface Builder)
    public required init?(coder: NSCoder) {
        contentView = UIView()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Basic view configuration
        backgroundColor = .clear
        clipsToBounds = true
        isAccessibilityElement = false

        // Add the replicator view as a full outer container
        replicatorView.backgroundColor = .clear
        addSubview(replicatorView)

        // Add the content view to the replicator view
        installContentView()

        // Add the variable blur view as a sibling of the replicator layer
        addSubview(blurView)

        // Keep the source above the blur and move the reflected instance beneath it.
        // Preserving depth allows the sibling blur view to render between both instances.
        replicatorView.layer.zPosition = 1.0
        blurView.layer.zPosition = 0.0

        // Configure the replicator to show its mirror upside down and behind the blur.
        let layer = replicatorView.replicatorLayer
        layer.instanceCount = 2
        layer.instanceDelay = 0.0
        layer.preservesDepth = true

        // Set the replicated copy's Z-index to be negative so we can thread the blur view
        // between it and the content view
        var instanceTransform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        instanceTransform.m43 = -2.0
        layer.instanceTransform = instanceTransform

        // Configure the replicator's visibility/alpha
        updateReflectionAppearance()
    }

    private func installContentView() {
        // Insert the content view into the replicator layer as the source layer
        contentView.clipsToBounds = true
        // Reserve the root depth so each replicator instance stays on its intended side of the blur.
        contentView.layer.zPosition = 0.0
        replicatorView.addSubview(contentView)
        setNeedsLayout()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()

        // Divide the reflection view into 2 vertical halves
        let contentHeight = bounds.height * 0.5
        let newSourceFrame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: contentHeight)
        let newReflectionFrame = CGRect(x: bounds.minX, y: bounds.minY + contentHeight,
                                        width: bounds.width, height: bounds.height - contentHeight)

        // Save the top and bottom half sizes
        sourceFrame = newSourceFrame
        reflectionFrame = newReflectionFrame

        // Apply the sizes to the view content
        replicatorView.frame = bounds
        contentView.frame = CGRect(origin: .zero, size: sourceFrame.size)
        blurView.frame = bounds
    }

    /// The reflected layer instance has no corresponding view, so it should not intercept input.
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        sourceFrame.contains(point) && super.point(inside: point, with: event)
    }

    // MARK: - Appearance

    private func updateReflectionAppearance() {
        let alpha = min(max(reflectionAlpha, 0.0), 1.0)

        // Update the alpha/visibility of the reflected copy
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        replicatorView.replicatorLayer.instanceCount = isReflectionHidden ? 1 : 2
        replicatorView.replicatorLayer.instanceAlphaOffset = Float(alpha - 1.0)
        CATransaction.commit()

        // Hide the blur view if needed
        blurView.isHidden = isReflectionHidden
    }
}
