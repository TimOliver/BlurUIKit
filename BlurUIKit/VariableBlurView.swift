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
        let filter = BlurFilterProvider.blurFilter(named: "Wee")
    }

}
