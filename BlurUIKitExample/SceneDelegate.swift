//
//  SceneDelegate.swift
//  BlurUIKit
//

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
            VisualEffectViewController()
        ]

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        self.window = window
        window.makeKeyAndVisible()
    }
}
