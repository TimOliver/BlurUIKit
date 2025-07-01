//
//  BlurViewController.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 1/7/2025.
//

import UIKit

final class BlurViewController: UIViewController {

    private let backgroundView = UIView()
    private let redSquare = UIView()
    private let slider = UISlider()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Blur"
        tabBarItem.image = UIImage(systemName: "circle.dotted")
        tabBarItem.selectedImage = UIImage(systemName: "circle.dotted")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground

        backgroundView.backgroundColor = .tertiarySystemBackground
        view.addSubview(backgroundView)

        redSquare.backgroundColor = .systemRed
        view.addSubview(redSquare)

        slider.addTarget(self, action: #selector(sliderDidChange), for: .valueChanged)
        slider.minimumValue = 0.0
        slider.maximumValue = 50.0
        view.addSubview(slider)
    }

    @objc func sliderDidChange() {
        self.redSquare.blurRadius = CGFloat(self.slider.value)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        let minBounds = min(view.bounds.size.width, view.bounds.size.height)
        let minSize = min(minBounds * 0.6, 200)
        redSquare.frame.size = CGSize(width: minSize, height: minSize)

        redSquare.layer.removeAllAnimations()
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 2.0
        rotation.repeatCount = .infinity
        redSquare.layer.add(rotation, forKey: "spin")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        redSquare.center = view.center

        backgroundView.frame.size = redSquare.bounds.size
        backgroundView.center = redSquare.center
        backgroundView.center.x += redSquare.bounds.width * 0.25

        let insetMargin = view.layoutMargins.left + view.layoutMargins.right
        slider.frame.size.width = view.frame.width - insetMargin
        slider.center = CGPoint(x: view.center.x, y: view.frame.size.height - view.safeAreaInsets.bottom - 32)
    }
}
