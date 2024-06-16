//
//  AppDelegate.swift
//  BlurUIKit
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [ViewController()]

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        return true
    }

}

