//
//  BlurFilterProvider.swift
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

import UIKit

// An internal class that creates, manages and vends the blur filters
// used by the public classes of this framework.
@MainActor internal class BlurFilterProvider {

    // A shared blur visual effect view that is used to hook and extract a reference to the CAFilter class
    static let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

    /// Vends a newly instantiated CAFilter instance with the provided filter name
    /// - Parameter name: The name of the filter that this filter will be instantiated with.
    /// - Returns: The new CAFilter object, or nil if the filter if it couldn't be created.
    static func blurFilter(named name: String) -> NSObject? {
        // Fetch a known CAFilter-backed subview from out of the shared blur view so we can access that class.
        guard let backdropView = findSubview(in: blurView, containing: "backdrop"),
              let filter = backdropView.layer.filters?.first as? NSObject else {
            return nil
        }
        return blurFilterCopy(from: filter, named: name)
    }

    /// With an already instantiated CAFilter object as the base, create a completely new instance with the specified filter type.
    /// - Parameters:
    ///   - filter: The existing filter to use as a base
    ///   - name: The name of the filter that this filter will be instantiated with.
    /// - Returns: The new CAFilter object, or nil if the filter if it couldn't be created.
    static func blurFilterCopy(from filter: NSObject, named name: String) -> NSObject? {
        // Confirm this object implements the method name we need.
        // This ensures that even if Apple changes it, we can fail gracefully.
        // The only private method we need to call is '+[CAFilter filterWithType:]'
        let selectorName = ["Type:", "With", "filter"].reversed().joined()
        let selector = NSSelectorFromString(selectorName)

        let type = type(of: filter)
        guard type.responds(to: selector) else { return nil }
        return type.perform(selector, with: name).takeUnretainedValue() as? NSObject
    }

    /// Loop through a view's subviews and find the one with its class name containing the provided string
    /// - Parameter view: The view whose subviews will be searched.
    /// - Parameter name: The portion of the name of the subiew to find.
    /// - Returns: The subview if it is found, or nil otherwise.
    static func findSubview(in view: UIView, containing name: String) -> UIView? {
        view.subviews.first { String(describing: $0).lowercased().contains(name.lowercased()) }
    }
}
