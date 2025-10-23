# BlurUIKit

<img src="https://raw.githubusercontent.com/TimOliver/BlurUIKit/main/screenshot.webp" width="500" align="right" alt="BlurUIKit" />

![Version](https://img.shields.io/cocoapods/v/BlurUIKit.svg?style=flat)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/TimOliver/BlurUIKit/main/LICENSE)
![Platform](https://img.shields.io/cocoapods/p/BlurUIKit.svg?style=flat)

_As of iOS 26, [this is now a public API](https://developer.apple.com/documentation/uikit/uiscrollview/topedgeeffect)! Woohoo! However, please feel free to continue using this library if you need additional control, or need to continue supporting iOS 18._

`BlurUIKit` is an open source UI framework that exposes more of the dynamic blur capabilities of UIKit in an App Store safe way. Namely, it exposes the 'progressive blur' effect Apple has started using in system apps where underlaying content gets progressively more blurry along a gradient pattern. It also exposes the ability to apply gaussian blurs directly to dynamic views, useful for blur-fade transitions.

# Features

* Enables the ability to add progressive blur or gaussian blur effects to UIKit applications.
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

Another feature of `BlurUIKit` is being able to apply gaussian blur to `UIView` instances.

```swift

// Create a new UIView instance
let redSquare = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
redSquare.backgroundColor = .systemRed

// Apply gaussian blur to it
redSquare.blurRadius = 30.0

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

_tl;dr Yes, it should be 99.9% safe for the App Store. If your app gets rejected from this library, [please open an issue](https://github.com/TimOliver/BlurUIKit/issues/new)._

While obviously you should always use the public APIs that Apple provides to you, there is definitely a 'gray' area in iOS where you can extend the functionality of public APIs, without doing anything unsafely.

Apple has historically said the reason they don't like developers using private APIs is that they make no guarantees between major iOS versions that anything under the hood will stay consistent. This primarily applies to ultra-brazen things like dynamically linking to private frameworks. Conversely, even small, innocent things such as traversing the subviews of one of Apple's UI components and moving them around internally (like I did with [TONavigationBar](https://github.com/TimOliver/TONavigationBar)) could be considered using a private API if the inner views aren't public.

`BlurUIKit` is in a similar camp to traversing the inner views of an Apple UI component in terms of private API use. It takes advantage of the fact that `CAFilter` is actually exposed publicly on a public property of `UIVisualEffectView`, which we can access, and then make in-memory copies for our own use. In this way, we can safely ensure that since we're not doing any internal runtime hacking or risky assumptions to access the object, there's nothing for Apple to detect in App Review (_probably_).

Obviously, I'm not a huge fan of relying on these sorts of hacks, but I feel like this is a very special case. Not only is it straight-up not possible to achieve this visual effect using only public APIs (SwiftUI aside), but Apple now uses it so heavily in both the Home Screen and in the system apps that the effect is starting to become a part of the iOS visual design language. ~~And so it feels wild to me that they haven't made it a public API yet to let third-party developers achieve the same thing.~~

In iOS 26, Apple provided [a new API on UIScrollView](https://developer.apple.com/documentation/uikit/uiscrollview/topedgeeffect) that enables this sort of effect, but the initial feedback I'm hearing from fellow developers is that it's very limiting. You can't change the blur radius or the size of the gradient. As such, it seems that this library still has value, even in iOS 26. It would be amazing if Apple fully exposed this effect as a public API. I've already opened [FB13949531](https://openradar.appspot.com/FB13949531) asking them to consider making it as such. The more developers who duplicate that radar, the better chance we have of Apple doing so. If you love this effect as much as I do, please consider duplicating that radar.

# Credits

`BlurUIKit` was created by [Tim Oliver](http://threads.net/@timoliver) as a component of [iComics](http://icomics.co).

# License

`BlurUIKit` is available under the MIT license. Please see the [LICENSE](LICENSE) file for more information.
