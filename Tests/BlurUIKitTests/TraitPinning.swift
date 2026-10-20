import UIKit

/// Creates a window whose appearance and contrast traits are fixed, so views hosted in it
/// don't depend on the simulator's accessibility settings. Trait overrides only take effect
/// for views that are in a window.
@MainActor
func makePinnedWindow(style: UIUserInterfaceStyle = .light,
                      contrast: UIAccessibilityContrast = .normal) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
    window.overrideUserInterfaceStyle = style
    if #available(iOS 17, *) {
        window.traitOverrides.accessibilityContrast = contrast
    }
    window.isHidden = false
    return window
}
