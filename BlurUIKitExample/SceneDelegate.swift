//
//  SceneDelegate.swift
//  BlurUIKit
//

import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)

        let tabBarController = UITabBarController()
        tabBarController.tabBar.standardAppearance = tabBarAppearance
        tabBarController.tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBarController.viewControllers = [
            PhotosViewController(),
            MapViewController(),
            BlurViewController(),
            ReflectionBlurViewController(),
            swiftUIController()
        ]

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        self.window = window
        window.makeKeyAndVisible()
    }

    private func swiftUIController() -> UIHostingController<SwiftUIExampleView> {
        let viewController = UIHostingController(rootView: SwiftUIExampleView())
        viewController.tabBarItem = UITabBarItem(title: "SwiftUI",
                                                image: UIImage(systemName: "swift"),
                                                selectedImage: UIImage(systemName: "swift"))
        return viewController
    }
}
