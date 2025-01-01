# BlurUIKit

<img src="https://raw.githubusercontent.com/TimOliver/BlurUIKit/main/screenshot.webp" width="500" align="right" alt="TORoundedButton" />

![Version](https://img.shields.io/cocoapods/v/BlurUIKit.svg?style=flat)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/TimOliver/BlurUIKit/main/LICENSE)
![Platform](https://img.shields.io/cocoapods/p/BlurUIKit.svg?style=flat)

_We need your help! If you wish for this blur effect to become an officially supported API, please file a radar and duplicate [FB13949531](https://openradar.appspot.com/FB13949531)!

`BlurUIKit` is an open source UI framework that exposes more of the dynamic blur capabilities of UIKit in an App Store safe way. Namely, it exposes the 'progressive blur' effect Apple has started using in system apps where underlaying content gets progressively more blurry along a gradient pattern.

# Features

* Enables the ability to add progressive blur effects to UIKit applications.
* Allows an optional 'dimming' colored gradient to add additional contrast when needed.
* Dimming and blur gradients can be configured independently.
* Highly optimized to avoid regenerating gradient mask images unless needed.

# Examples

`BlurUIKit` features a default configuration ready to use, but can be further modified depending on your app's needs.

```swift

// Create a new instance of `BlurUIKit`
let blurView = VariableBlurView()

// Set a tint color for the colored gradient.
blurView.dimmingTintColor = .red

// The tint color can 'overshoot' the blur view to add more gradual transition
blurView.dimmingOvershoot = .relative(fraction: 0.25)

```

# Requirements

`BlurUIKit` should work with iOS 14 and above. It may work on lower versions of iOS, but this hasnt been tested.

# Installation

<details>
  <summary><strong>Manual Installation</strong></summary>

Copy the contents of the `BlurUIKit` folder to your app's project folder.
</details>

<details>
  <summary><strong>CocoaPods</strong></summary>

```
pod 'BlurUIKit'
```
</details>

<details>
  <summary><strong>Swift Package Manager</strong></summary>

Add the following to your `Package.swift`:
``` swift
dependencies: [
  // ...
  .package(url: "https://github.com/TimOliver/BlurUIKit.git"),
],
```
</details>

# Is this really App Store safe?

_tl;dr Yes, it should be 99.9% safe for the App Store. If your app gets rejected from this library, please open an issue._

# Credits

`BlurUIKit` was created by [Tim Oliver](http://threads.net/@timoliver) as a component of [iComics](http://icomics.co).

# License

`BlurUIKit` is available under the MIT license. Please see the [LICENSE](LICENSE) file for more information.
