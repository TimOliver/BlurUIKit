# BlurUIKit

<img src="https://raw.githubusercontent.com/TimOliver/BlurUIKit/main/screenshot.webp" width="500" align="right" alt="BlurUIKit" />

![Version](https://img.shields.io/cocoapods/v/BlurUIKit.svg?style=flat)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/TimOliver/BlurUIKit/main/LICENSE)
![Platform](https://img.shields.io/cocoapods/p/BlurUIKit.svg?style=flat)

_We need your help! If you wish for this blur effect to become an officially supported API, please file a radar and duplicate [FB13949531](https://openradar.appspot.com/FB13949531)!_

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

_tl;dr Yes, it should be 99.9% safe for the App Store. If your app gets rejected from this library, [please open an issue](https://github.com/TimOliver/BlurUIKit/issues/new)._

While obviously you should always use the public APIs that Apple provides to you, there is definitely a 'gray' area in iOS where you can extend the functionality of public APIs, without abusing private APIs in an unsafe way at the same time.

Apple has historically said the reason they don't like developers using private APIs is that they make no guarantees between major iOS versions that anything under the hood will stay consistent. If developers are doing ultra-brazen things like dynamically linking to private frameworks, and re-implementing the headers on those frameworks based on how they _think_ the frameworks behave, this makes complete sense. Likewise, there can be very small, innocent things that technically count as private API access, such as traversing the subviews of one of Apple's UI components and moving them around internally (like I did with [TONavigationBar](https://github.com/TimOliver/TONavigationBar)).

`BlurUIKit` is in a similar camp to traversing the inner views of an Apple UI component in terms of private API use. It takes advantage of the fact that `CAFilter` is actually exposed publicly on a public property of `UIVisualEffectView`, which we can then make a copy for our own use. In this way, we can safely ensure that if Apple breaks our assumption, the app won't crash, and since we're not doing any internal runtime hacking to access the object, there's nothing for Apple to detect in App Review (probably).

Obviously, I'm not a huge fan of relying on these sorts of hacks, but I feel like this is a very special case. Not only is it straight-up not possible to achieve this visual effect using only public APIs (SwiftUI aside), but Apple now uses it so heavily in both the Home Screen and in the system apps that the effect is starting to become a part of the iOS visual design language. And so it feels wild to me that they haven't made it a public API yet to let third-party developers achieve the same thing.

In any case, it would be amazing if Apple made this a public API. I've already opened [FB13949531](https://openradar.appspot.com/FB13949531) asking them to consider making this a public API. The more developers who duplicate that radar, the better chance we have of Apple doing so. If you love this effect as much as I do, please consider duplicating that radar.

# Credits

`BlurUIKit` was created by [Tim Oliver](http://threads.net/@timoliver) as a component of [iComics](http://icomics.co).

# License

`BlurUIKit` is available under the MIT license. Please see the [LICENSE](LICENSE) file for more information.
