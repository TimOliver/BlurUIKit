//
//  AppDelegate.swift
//  BlurUIKit
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit
import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let tabBarAppearance: UITabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)

        let tabBarController = UITabBarController()
        tabBarController.tabBar.standardAppearance = tabBarAppearance
        tabBarController.tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBarController.viewControllers = [PhotosViewController(), MapViewController(), BlurViewController(), swiftUIController()]

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        return true
    }

    func swiftUIController() -> UIHostingController<SwiftUIExampleView> {
        let viewController = UIHostingController(rootView: SwiftUIExampleView())
        viewController.tabBarItem = UITabBarItem(title: "SwiftUI",
                                                    image: UIImage(systemName: "swift"),
                                                    selectedImage: UIImage(systemName: "swift"))
        return viewController
    }
}

