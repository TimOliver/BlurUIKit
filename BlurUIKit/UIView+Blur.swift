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

// A global pointer to use as the associated object handle
private var BlurFilterObjectHandle: UInt8 = 0

// Applies a gaussian blur to a UIView without blurring the content below it.
extension UIView {

    /// Set the gaussian blur radius of this view
    public var blurRadius: CGFloat {
        get {
            if let filter = blurFilter {
                return filter.value(forKey: "inputRadius") as? CGFloat ?? 0.0
            }
            return 0.0
        }

        set {
            var filter: NSObject? = self.blurFilter
            if filter == nil {
                filter = BlurFilterProvider.blurFilter(named: "gaussianBlur")
                if let filter {
                    self.blurFilter = filter
                    self.layer.filters = [filter]
                }
            }
            guard let filter else { return }
            filter.setValue(newValue, forKey: "inputRadius")
        }
    }

    // Save the associated filter with this view so it's easier to fetch on subsequent calls
    var blurFilter: NSObject? {
        get {
            return objc_getAssociatedObject(self, &BlurFilterObjectHandle) as? NSObject
        }
        set {
            objc_setAssociatedObject(self, &BlurFilterObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
