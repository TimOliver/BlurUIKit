//
//  VisualEffectViewController.swift
//  BlurUIKitExample
//
//  Copyright (c) 2024-2026 Tim Oliver
//

import UIKit

/// Shows a standard UIVisualEffectView over a photo, with sliders for the blur radius and
/// dimming that BlurUIKit exposes on it. Tapping the photo animates the effect away and back,
/// the way an app would bring its content into focus as a dialog over it goes away.
final class VisualEffectViewController: UIViewController {

    private let imageView = UIImageView()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    private let radiusLabel = UILabel()
    private let radiusSlider = UISlider()
    private let dimmingLabel = UILabel()
    private let dimmingSlider = UISlider()
    private let hintLabel = UILabel()

    /// The slider values to restore after a tap animated the effect away.
    private var hiddenEffectValues: (radius: Float, dimming: Float)?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Overlay"
        tabBarItem.image = UIImage(systemName: "camera.filters")
        tabBarItem.selectedImage = UIImage(systemName: "camera.filters")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        // Show the first photo of the atlas, the same way the Photos tab does
        imageView.image = UIImage(named: "AppleParkAtlas")
        imageView.layer.contentsRect = CGRect(origin: .zero, size: PhotosViewCollectionCell.atlasImageSize)
        imageView.layer.cornerCurve = .continuous
        imageView.layer.masksToBounds = true
        view.addSubview(imageView)

        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true
        effectView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(effectViewTapped)))
        view.addSubview(effectView)

        // Start the sliders at UIKit's own values for this effect style
        radiusSlider.minimumValue = 0
        radiusSlider.maximumValue = 60
        radiusSlider.value = Float(effectView.blurEffectRadius)
        radiusSlider.addTarget(self, action: #selector(slidersDidChange), for: .valueChanged)

        dimmingSlider.minimumValue = 0
        dimmingSlider.maximumValue = 1
        dimmingSlider.value = Float(effectView.dimmingAlpha)
        dimmingSlider.addTarget(self, action: #selector(slidersDidChange), for: .valueChanged)

        for label in [radiusLabel, dimmingLabel, hintLabel] {
            label.font = .preferredFont(forTextStyle: .footnote)
            label.textColor = .secondaryLabel
        }
        hintLabel.text = "Tap the photo to animate the effect away and back."
        hintLabel.textAlignment = .center
        updateLabels()

        for subview in [radiusLabel, radiusSlider, dimmingLabel, dimmingSlider, hintLabel] {
            view.addSubview(subview)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // A single column, centered in the safe area
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let contentWidth = min(safeFrame.width - view.layoutMargins.left - view.layoutMargins.right, 500)
        let contentX = safeFrame.midX - contentWidth * 0.5
        let photoHeight = contentWidth * (9.0 / 16.0)
        let labelHeight: CGFloat = 20
        let sliderHeight: CGFloat = 32
        let totalHeight = photoHeight + 24 + labelHeight + sliderHeight + 12 + labelHeight + sliderHeight + 24 + labelHeight
        var y = max(safeFrame.midY - totalHeight * 0.5, safeFrame.minY + 16)

        imageView.frame = CGRect(x: contentX, y: y, width: contentWidth, height: photoHeight)
        imageView.layer.cornerRadius = contentWidth * 0.1
        effectView.frame = imageView.frame
        effectView.layer.cornerRadius = imageView.layer.cornerRadius
        y = imageView.frame.maxY + 24

        radiusLabel.frame = CGRect(x: contentX, y: y, width: contentWidth, height: labelHeight)
        y += labelHeight
        radiusSlider.frame = CGRect(x: contentX, y: y, width: contentWidth, height: sliderHeight)
        y += sliderHeight + 12

        dimmingLabel.frame = CGRect(x: contentX, y: y, width: contentWidth, height: labelHeight)
        y += labelHeight
        dimmingSlider.frame = CGRect(x: contentX, y: y, width: contentWidth, height: sliderHeight)
        y += sliderHeight + 24

        hintLabel.frame = CGRect(x: contentX, y: y, width: contentWidth, height: labelHeight)
    }

    // MARK: - Interaction

    @objc private func slidersDidChange() {
        hiddenEffectValues = nil
        effectView.blurEffectRadius = CGFloat(radiusSlider.value)
        effectView.dimmingAlpha = CGFloat(dimmingSlider.value)
        updateLabels()
    }

    @objc private func effectViewTapped() {
        if let values = hiddenEffectValues {
            hiddenEffectValues = nil
            animateEffect(radius: values.radius, dimming: values.dimming)
        } else {
            hiddenEffectValues = (radiusSlider.value, dimmingSlider.value)
            animateEffect(radius: 0, dimming: 0)
        }
    }

    // Both properties animate inside a regular animation block, alongside anything else in it
    private func animateEffect(radius: Float, dimming: Float) {
        radiusSlider.setValue(radius, animated: true)
        dimmingSlider.setValue(dimming, animated: true)
        UIView.animate(withDuration: 0.6) {
            self.effectView.blurEffectRadius = CGFloat(radius)
            self.effectView.dimmingAlpha = CGFloat(dimming)
            self.updateLabels()
        }
    }

    private func updateLabels() {
        radiusLabel.text = String(format: "Blur radius: %.0f pt", radiusSlider.value)
        dimmingLabel.text = String(format: "Dimming: %.0f%%", dimmingSlider.value * 100)
    }
}
