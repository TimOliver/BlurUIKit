//
//  ReflectionBlurViewController.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 3/10/2026.
//

import UIKit

final class ReflectionBlurViewController: UIViewController {

    private let reflectionView = ReflectionBlurView()
    private let cardView = UIView()
    private let imageView = UIImageView()
    private let redSquareView = UIView()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Reflection"
        tabBarItem.image = UIImage(systemName: "square.bottomhalf.filled")
        tabBarItem.selectedImage = UIImage(systemName: "square.bottomhalf.filled")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerCurve = .continuous
        cardView.layer.masksToBounds = true
        reflectionView.contentView.addSubview(cardView)

        imageView.image = UIImage(named: "AppleParkAtlas")?.preparingForDisplay()
        imageView.layer.contentsRect = CGRect(x: 0.0, y: 0.0, width: 0.499, height: 0.249)
        cardView.addSubview(imageView)

        redSquareView.backgroundColor = .systemRed
        reflectionView.contentView.addSubview(redSquareView)

        reflectionView.minimumBlurRadius = 7.0
        reflectionView.maximumBlurRadius = 60.0
        reflectionView.dimmingTintColor = .black
        reflectionView.dimmingAlpha = .constant(alpha: 0.9)
        view.addSubview(reflectionView)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        redSquareView.layer.removeAnimation(forKey: "spin")

        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0.0
        rotation.toValue = Double.pi * 2.0
        rotation.duration = 2.0
        rotation.repeatCount = .infinity
        redSquareView.layer.add(rotation, forKey: "spin")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        reflectionView.frame = view.bounds
        reflectionView.layoutIfNeeded()

        let contentBounds = reflectionView.contentView.bounds
        let horizontalMargin: CGFloat = 24.0
        let midpointMargin: CGFloat = 16.0
        let maximumWidth = min(contentBounds.width - (horizontalMargin * 2.0), 640.0)
        let maximumContentHeight = max(contentBounds.height - view.safeAreaInsets.top - midpointMargin, 0.0)

        let cardWidth = max(min(maximumWidth, maximumContentHeight * (16.0 / 9.0)), 0.0)
        let cardHeight = cardWidth * (9.0 / 16.0)
        cardView.frame = CGRect(x: (contentBounds.width - cardWidth) * 0.5,
                                y: contentBounds.maxY - cardHeight - midpointMargin,
                                width: cardWidth,
                                height: cardHeight)
        cardView.layer.cornerRadius = min(cardWidth, cardHeight) * 0.175
        imageView.frame = cardView.bounds

        let squareLength = min(cardWidth, cardHeight) * 0.64
        redSquareView.bounds = CGRect(x: 0.0, y: 0.0, width: squareLength, height: squareLength)
        let squareCenter = CGPoint(x: cardView.bounds.width * 0.78,
                                   y: cardView.bounds.height * 0.52)
        redSquareView.center = cardView.convert(squareCenter, to: reflectionView.contentView)
    }
}
