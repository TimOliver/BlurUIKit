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

    // The maximum blur radius of the blur view when its gradient is at full opacity
    public var maximumBlurRadius = 2.0 {
        didSet { updateBlurFilter() }
    }

    // Performs an update when the frame changes
    public override var frame: CGRect {
        didSet {
            if frame.size != oldValue.size {
                updateBlurFilter()
            }
        }
    }

    // The variable blur view filter
    private let variableBlurFilter = BlurFilterProvider.blurFilter(named: "variableBlur")

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
            backdropView.layer.setValue(0.5, forKey: "scale")
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
        let size = CGSize(width: 1, height: 5)
        let graphicsRenderer = UIGraphicsImageRenderer(size: size)
        let image = graphicsRenderer.image { context in
            let gradientColor = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 1.00)
            let gradientColor2 = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.000)
            let gradient = CGGradient(colorsSpace: nil, colors: [gradientColor.cgColor, gradientColor2.cgColor] as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0.5, y: 00), end: CGPoint(x: 0.5, y: 5), options: [])
        }
        return image.cgImage
    }
}
