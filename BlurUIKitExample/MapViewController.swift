//
//  ViewController.swift
//  BlurUIKit
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit
import MapKit

final class MapViewController: UIViewController {

    let mapView = MKMapView()
    let statusBarBlurView = VariableBlurView()

    init() {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Maps"
        tabBarItem.image = UIImage(systemName: "map")
        tabBarItem.selectedImage = UIImage(systemName: "map.fill")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mapView)
        
        // Since the map view is sufficiently high contrast on its own, disable the tinted dimming
        statusBarBlurView.dimmingTintColor = nil
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

