//
//  UIView+Blur.swift
//  Copyright (c) 2024-2025 Tim Oliver
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import ObjectiveC
import UIKit

// Applies a gaussian blur to a UIView without blurring the content below it.
extension UIView {

    /// Set the gaussian blur radius of this view
    public var blurRadius: CGFloat {
        get {
            guard let filter = blurFilter else { return 0.0 }
            return filter.value(forKey: "inputRadius") as? CGFloat ?? 0.0
        }

        set {
            // We can't update the radius of an existing object,
            // so copy and create a fresh object from it.
            var newFilter: NSObject? = nil
            if let filter = self.blurFilter {
                self.layer.filters?.removeAll { ($0 as? NSObject) == filter }
                newFilter = BlurFilterProvider.blurFilterCopy(from: filter, named: "gaussianBlur")
            } else {
                newFilter = BlurFilterProvider.blurFilter(named: "gaussianBlur")
            }
            guard let newFilter else { return }
            newFilter.setValue(newValue, forKey: "inputRadius")
            self.layer.filters = (self.layer.filters ?? []) + [newFilter]
            self.blurFilter = newFilter
        }
    }

    /// Apply a gaussian blur to this view with an animation
    public func setBlurRadiusAnimated(radius: CGFloat, duration: TimeInterval = 0.45) {
        let currentRadius = self.blurRadius
        self.blurRadius = radius

        let blurAnimation = CABasicAnimation(keyPath: "filters.gaussianBlur.inputRadius")
        blurAnimation.fromValue = currentRadius
        blurAnimation.toValue = radius
        blurAnimation.duration = duration
        self.layer.add(blurAnimation, forKey: "filters.gaussianBlur.inputRadius")
    }
}

// MARK: - Private

// A global pointer to use as the associated object handle
@MainActor private var BlurFilterObjectHandle: UInt8 = 0

extension UIView {
    // Save the associated filter with this view so it's quicker to fetch on subsequent calls
    private var blurFilter: NSObject? {
        get {
            return objc_getAssociatedObject(self, &BlurFilterObjectHandle) as? NSObject
        }
        set {
            objc_setAssociatedObject(self, &BlurFilterObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
