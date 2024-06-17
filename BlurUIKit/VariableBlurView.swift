//
//  VariableBlurView.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit

/// A variant of UIVisualEffectView that provides a blur overlay view
/// that gradually 'ramps' up in blur intensity from one edge to the other.
/// This is great for separating separate layers of content (such as the iOS status bar)
/// without any hard border lines.
public class VariableBlurView: UIVisualEffectView {

    /// The possible directions that the gradient of this blur view may flow in.
    public enum Direction {
        case down   // Downwards. Useful for the iOS status bar
        case up     // Upwards. Useful for view controller toolbars
        case left   // Left. Useful for iPadOS sidebar
        case right  // Right. iPadOS sidebar in right-to-left locales
    }

    /// Dentoting the end position of the opaque side of the gradient.
    /// Use this to move the end position forward, tightening the gradient.
    public enum StartInset {
        // A flat inset in points that will remain the same, regardless of the size of the view.
        case absolute(position: CGFloat)
        // A relative position (between 0.0 and 1.0) that scales with the length of the gradient.
        case relative(fraction: CGFloat)
    }

    // The current direction of the gradient for this blur view
    public var direction: Direction = .down {
        didSet { setNeedsUpdate() }
    }

    // An optional amount of insetting on the starting edge's side, to tight the gradient if desired
    public var startInset: StartInset? {
        didSet { setNeedsUpdate() }
    }

    // The maximum blur radius of the blur view when its gradient is at full opacity
    public var maximumBlurRadius = 2.0 {
        didSet { setNeedsUpdate() }
    }

    // Performs an update when the frame changes
    public override var frame: CGRect {
        didSet { setNeedsUpdate() }
    }

    // The variable blur view filter
    private let variableBlurFilter = BlurFilterProvider.blurFilter(named: "variableBlur")

    // Track when the blur view needs to be updated
    private var needsUpdate = false

    // MARK: - Initialization

    init() {
        super.init(effect: UIBlurEffect(style: .regular))
        commonInit()
    }

    init(frame: CGRect) {
        super.init(effect: UIBlurEffect(style: .regular))
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(effect: UIBlurEffect(style: .regular))
        commonInit()
    }

    private func commonInit() {
        // Disable interaction so touches will pass through it
        isUserInteractionEnabled = false
    }

    // MARK: - View Lifecycle

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        configureView()
        updateBlurFilter()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard needsUpdate else { return }
        updateBlurFilter()
        needsUpdate = false
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        configureView()
        updateBlurFilter()
    }

    // MARK: - Private

    // One-time setup logic
    private func configureView() {
        guard superview != nil, let variableBlurFilter else { return }

        // Find the overlay view (The one that lightens or darkens these blur views) and hide it.
        BlurFilterProvider.findSubview(in: self, containing: "subview")?.isHidden = true

        // Find the backdrop view (The one that repeats the content drawn behind it) and apply the blur filter.
        if let backdropView = BlurFilterProvider.findSubview(in: self, containing: "backdrop") {
            backdropView.layer.filters = [variableBlurFilter]
            backdropView.layer.setValue(0.75, forKey: "scale")
        }
    }

    // Update the parameters of the blur filter
    private func updateBlurFilter() {
        variableBlurFilter?.setValue(gradientMaskImage(), forKey: "inputMaskImage")
        variableBlurFilter?.setValue(maximumBlurRadius, forKey: "inputRadius")
        variableBlurFilter?.setValue(true, forKey: "inputNormalizeEdges")
    }

    // Generates a gradient bitmap to be used with the blur filter
    private func gradientMaskImage() -> CGImage? {
        // Skip if we're not sized yet.
        guard frame.size != .zero else { return nil }

        // Generate the size, based on the current direction
        let size: CGSize = {
            switch direction {
            case .up, .down:
                return CGSize(width: 1.0, height: bounds.height)
            case .left, .right:
                return CGSize(width: bounds.width, height: 1.0)
            }
        }()

        // Determine the start location if a setting was provided
        let startLocation: CGFloat = {
            guard let startInset else { return 0.0 }
            switch startInset {
                case .absolute(let position):
                return position / (size.width < size.height ? size.height : size.width)
                case .relative(let fraction):
                return fraction
            }
        }()

        // Determine which direction the gradient flows in
        let gradientPosition: (start: CGPoint, end: CGPoint) = {
            switch direction {
            case .down:
                return (start: CGPoint(x: 0.5, y: 0.0), end: CGPoint(x: 0.5, y: bounds.height))
            case .up:
                return (start: CGPoint(x: 0.5, y: bounds.height), end: CGPoint(x: 0.5, y: 0.0))
            case .left:
                return (start: CGPoint(x: 0.0, y: 0.5), end: CGPoint(x: bounds.width, y: 0.5))
            case .right:
                return (start: CGPoint(x: bounds.width, y: 0.5), end: CGPoint(x: 0.0, y: 0.5))
            }
        }()

        // Configure one color to be opaque and one to be clear
        let startColor = UIColor(white: 0.0, alpha: 1.0), endColor = UIColor(white: 0.0, alpha: 0.0)
        let colors = [startColor.cgColor, endColor.cgColor] as CFArray

        // Disable retina scaling since it won't be noticable, and saves memory
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        // Render the gradient
        let graphicsRenderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = graphicsRenderer.image { context in
            guard let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [startLocation, 1.0]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: gradientPosition.start, end: gradientPosition.end, options: [])
        }
        return image.cgImage
    }

    // Sets that the blur view needs to be updated in the next layout pass
    // This allows a variety of settings to be set in one run loop, with them all being applied next loop
    private func setNeedsUpdate() {
        needsUpdate = true
        setNeedsLayout()
    }
}
