//
//  PhotosViewController.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 30/9/2024.
//

import Foundation
import UIKit

final class PhotosViewController: UIViewController {

    let statusBarBlurView = VariableBlurView()

    init() {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Home"
        tabBarItem.image = UIImage(systemName: "house")
        tabBarItem.selectedImage = UIImage(systemName: "house.fill")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Clamp the status bar blur view to the top safe area
        statusBarBlurView.frame = view.bounds
        statusBarBlurView.frame.size.height = view.safeAreaInsets.top
    }

}

