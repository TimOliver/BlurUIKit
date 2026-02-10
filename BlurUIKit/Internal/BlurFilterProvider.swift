//
//  BlurFilterProvider.swift
//  Copyright (c) 2024-2026 Tim Oliver
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

import UIKit

// An internal class that creates, manages and vends the blur filters
// used by the public classes of this framework.
@available(iOS 14, *)
@MainActor internal class BlurFilterProvider {

    /// The CAFilter class, extracted once from a temporary UIVisualEffectView.
    /// The view is only kept alive during initialization and is not retained.
    private static let filterClass: AnyClass? = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        guard let backdropView = findSubview(in: blurView, containing: "backdrop"),
              let filter = backdropView.layer.filters?.first as? NSObject else {
            return nil
        }
        return type(of: filter)
    }()

    /// The selector for '+[CAFilter filterWithType:]', resolved once.
    /// This ensures that even if Apple changes it, we can fail gracefully.
    private static let filterSelector: Selector? = {
        let selectorName = ["Type:", "With", "filter"].reversed().joined()
        let selector = NSSelectorFromString(selectorName)
        guard let filterClass, filterClass.responds(to: selector) else { return nil }
        return selector
    }()

    /// Vends a newly instantiated CAFilter instance with the provided filter name
    /// - Parameter name: The name of the filter that this filter will be instantiated with.
    /// - Returns: The new CAFilter object, or nil if the filter if it couldn't be created.
    static func blurFilter(named name: String) -> NSObject? {
        guard let filterClass, let filterSelector else { return nil }
        return (filterClass as AnyObject).perform(filterSelector, with: name)?.takeUnretainedValue() as? NSObject
    }

    /// Loop through a view's subviews and find the one with its class name containing the provided string
    /// - Parameter view: The view whose subviews will be searched.
    /// - Parameter name: The portion of the name of the subiew to find.
    /// - Returns: The subview if it is found, or nil otherwise.
    static func findSubview(in view: UIView, containing name: String) -> UIView? {
        let lowercasedName = name.lowercased()
        return view.subviews.first { NSStringFromClass(type(of: $0)).lowercased().contains(lowercasedName) }
    }
}
