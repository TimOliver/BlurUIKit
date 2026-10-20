import UIKit

/// Creates a window whose appearance and contrast traits are fixed, so views hosted in it
/// don't depend on the simulator's accessibility settings. Trait overrides only take effect
/// for views that are in a window. App-hosted tests also need a connected scene for rendering
/// and SwiftUI updates; the standalone package test runner can use a window without a scene.
@MainActor
func makePinnedWindow(frame: CGRect = CGRect(x: 0, y: 0, width: 300, height: 400),
                      style: UIUserInterfaceStyle = .light,
                      contrast: UIAccessibilityContrast = .normal) -> UIWindow {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window: UIWindow
    if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
        window = UIWindow(windowScene: scene)
        window.frame = frame
    } else {
        window = UIWindow(frame: frame)
    }
    window.rootViewController = UIViewController()
    window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
    window.overrideUserInterfaceStyle = style
    if #available(iOS 17, *) {
        window.traitOverrides.accessibilityContrast = contrast
    }
    window.isHidden = false
    return window
}
