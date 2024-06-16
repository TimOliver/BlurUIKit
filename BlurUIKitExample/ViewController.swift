//
//  ViewController.swift
//  BlurUIKit
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    let mapView = MKMapView()
    let statusBarBlurView = VariableBlurView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mapView)
        view.addSubview(statusBarBlurView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mapView.frame = view.bounds

        // Clamp the status bar blur view to the top safe area
        statusBarBlurView.frame = view.bounds
        statusBarBlurView.frame.size.height = view.safeAreaInsets.top
    }
}

