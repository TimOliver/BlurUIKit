//
//  VariableBlurView.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit
import CoreImage

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

    /// Tightens the blur transition by insetting the gradient image inside the blur view by a certain amount.
    public enum GradientStartingInset {
        // The amount of points, starting from the clear edge, insetted into the blur view before the gradient completes.
        case absolute(position: CGFloat)
        // A value between 0.0 and 1.0 the gradient relative to the size of the view. A value of 0.5 would shrink the gradient to half the size.
        case relative(fraction: CGFloat)
    }

    /// The current direction of the gradient for this blur view
    public var direction: Direction = .down {
        didSet { reset() }
    }
    
    /// An optional amount of insetting on the starting edge's side, to tighten the gradient if desired
    public var blurStartingInset: GradientStartingInset? {
        didSet { resetBlurMask() }
    }
    
    /// The maximum blur radius of the blur view when its gradient is at full opacity
    public var maximumBlurRadius = 3.5 {
        didSet { updateBlurFilter() }
    }

    /// An optional colored gradient to dim the underlying content for better contrast.
    public var dimmingTintColor: UIColor? = .systemBackground {
        didSet {
            makeDimmingViewIfNeeded()
            dimmingView?.tintColor = dimmingTintColor
        }
    }
   
    /// The alpha value of the colored gradient
    public var dimmingAlpha: CGFloat = 0.5 {
        didSet { dimmingView?.alpha = dimmingAlpha }
    }
    
    /// The inset of the colored gradient to match the blur view if desired
    public var dimmingStartingInset: GradientStartingInset? {
        didSet { resetDimmingImage() }
    }

    /// Performs an update when the frame changes
    public override var frame: CGRect {
        didSet { resetForBoundsChange(oldValue: oldValue) }
    }

    /// The variable blur view filter
    private let variableBlurFilter = BlurFilterProvider.blurFilter(named: "variableBlur")

    /// The current image being used as the gradient mask
    private var gradientMaskImage: CGImage?
    
    /// Track when the images need to be regenerated
    private var needsUpdate = false

    /// An optional dimming gradient shown along with the blur view
    private var dimmingView: UIImageView?
    
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
        dimmingView?.frame = bounds
        updateBlurFilter()
        
        guard needsUpdate else { return }
        generateImagesAsNeeded()
        needsUpdate = false
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        configureView()
        updateBlurFilter()
    }

    // MARK: - Private

    // One-time setup logic to configure the blur view with our filters
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
    
    // Sets up (or tears down) an image view to display the dimming gradient as needed
    private func makeDimmingViewIfNeeded() {
        guard let dimmingTintColor else {
            dimmingView?.removeFromSuperview()
            dimmingView = nil
            return
        }
        
        guard dimmingView == nil else {
            return
        }

        let imageView = UIImageView()
        imageView.alpha = dimmingAlpha
        imageView.tintColor = dimmingTintColor
        contentView.addSubview(imageView)
        
        dimmingView = imageView
        setNeedsUpdate()
    }

    // Update the parameters of the blur filter when the state in this view changes
    private func updateBlurFilter() {
        variableBlurFilter?.setValue(gradientMaskImage, forKey: "inputMaskImage")
        variableBlurFilter?.setValue(maximumBlurRadius, forKey: "inputRadius")
        variableBlurFilter?.setValue(true, forKey: "inputNormalizeEdges")
    }
}

// MARK: Image Reset

extension VariableBlurView {
    // Reset if a bounds change means we have to regenerate the images
    private func resetForBoundsChange(oldValue: CGRect) {
        let needsReset = {
            switch direction {
            case .down, .up:
                return frame.height != oldValue.height
            case .left, .right:
                return frame.width != oldValue.width
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

extension VariableBlurView {
    
    private func generateImagesAsNeeded() {
        // Update the blur view's gradient mask
        if gradientMaskImage == nil {
            gradientMaskImage = fetchGradientImage(startingInset: blurStartingInset)
            updateBlurFilter()
        }
        
        // Update the dimming view image
        if dimmingView?.image == nil {
            makeDimmingViewIfNeeded()
            if let dimmingImage = fetchGradientImage(startingInset: dimmingStartingInset) {
                dimmingView?.image = UIImage(cgImage: dimmingImage).withRenderingMode(.alwaysTemplate)
            }
        }
    }
    
    // Generates a gradient bitmap to be used with the blur filter
    private func fetchGradientImage(startingInset: GradientStartingInset?) -> CGImage? {
        // Skip if we're not sized yet.
        guard frame.size.width != 0.0, frame.size.height != 0.0 else { return nil }

        // Generate the size, based on the current direction
        let size: CGSize = {
            switch direction {
            case .up, .down:
                return CGSize(width: 1.0, height: bounds.height)
            case .left, .right:
                return CGSize(width: bounds.width, height: 1.0)
            }
        }()

        // If we already have a cached version of this mask, and the size hasn't changed in the interim, recycle it
        if let gradientMaskImage, gradientMaskImage.width == Int(size.width), gradientMaskImage.height == Int(size.height) {
            return gradientMaskImage
        }

        // Determine the start location if a setting was provided
        let startLocation: CGFloat = {
            guard let startingInset else { return 0.0 }
            switch startingInset {
                case .absolute(let position):
                return position / (size.width < size.height ? size.height : size.width)
                case .relative(let fraction):
                return fraction
            }
        }()

        // Determine which direction the gradient flows in
        // (Core Image has its origin at the bottom of the bounds)
        let gradientPosition: (start: CIVector, end: CIVector) = {
            switch direction {
            case .down:
                return (start: CIVector(x: 0.5, y: bounds.height - (bounds.height * startLocation)), end: CIVector(x: 0.5, y: 0.0))
            case .up:
                return (start: CIVector(x: 0.5, y: 0.0 + (bounds.height * startLocation)), end: CIVector(x: 0.5, y: bounds.height))
            case .left:
                return (start: CIVector(x: bounds.width - (bounds.width * startLocation), y: 0.5), end: CIVector(x: 0.0, y: 0.5))
            case .right:
                return (start: CIVector(x: 0.0 + (bounds.width * startLocation), y: 0.5), end: CIVector(x: bounds.width, y: 0.5))
            }
        }()

        // Configure one color to be opaque and one to be clear
        let startColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let endColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)

        // Create a Core Image smooth linear gradient, since the classic Core Graphics gradient seems
        // to have a much harsher starting line at the edge of the gradient
        guard let gradientFilter = CIFilter(name: "CISmoothLinearGradient") else { return nil }
        gradientFilter.setDefaults()
        gradientFilter.setValue(gradientPosition.start, forKey: "inputPoint0")
        gradientFilter.setValue(gradientPosition.end, forKey: "inputPoint1")
        gradientFilter.setValue(startColor, forKey: "inputColor0")
        gradientFilter.setValue(endColor, forKey: "inputColor1")

        // Render the image out as a CGImage
        guard let gradientImage = gradientFilter.outputImage else { return nil }
        return CIContext(options: [.useSoftwareRenderer: true])
            .createCGImage(gradientImage, from: CGRect(origin: .zero, size: size))
    }
}
