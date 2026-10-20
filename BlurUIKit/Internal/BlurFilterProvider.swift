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

/// Creates the private Core Animation filters behind the public blur APIs. The filter class is
/// discovered from a UIKit backdrop on the first request and cached; if that fails, the next
/// request tries again. Each request gets a fresh filter, so callers can configure theirs freely.
@MainActor internal class BlurFilterProvider {

    /// Creates a filter of the given type, such as `"gaussianBlur"` or `"variableBlur"`, or nil.
    typealias FilterFactory = @MainActor (String) -> NSObject?

    /// The provider behind the public blur APIs. Tests replace it to simulate failures.
    static var shared = BlurFilterProvider()

    /// Resolves the factory on demand. Returning nil leaves discovery to be retried on the next request.
    private let discover: @MainActor () -> FilterFactory?

    /// The discovered factory, kept even if it fails to create an individual filter.
    private var filterFactory: FilterFactory?

    /// Creates a provider that discovers UIKit's filter factory on its first request.
    convenience init() {
        self.init(discover: Self.discoverFilterFactory)
    }

    /// Creates a provider with a custom discovery closure, for simulating failures in tests.
    init(discover: @escaping @MainActor () -> FilterFactory?) {
        self.discover = discover
    }

    /// Creates a filter of the given type, discovering the factory first if there isn't one yet.
    /// - Returns: A new filter, or nil if discovery or filter creation fails.
    func makeFilter(named name: String) -> NSObject? {
        if filterFactory == nil {
            filterFactory = discover()
        }
        return filterFactory?(name)
    }

    /// Extracts the filter class from a temporary UIKit backdrop and checks for `filterWithType:`.
    /// The factory captures only the class and selector, not the temporary view or its filter.
    private static func discoverFilterFactory() -> FilterFactory? {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        guard let backdropView = findSubview(in: blurView, containing: "backdrop"),
              let filter = backdropView.layer.filters?.first as? NSObject else {
            return nil
        }
        let filterClass = type(of: filter)

        let selectorName = ["Type:", "With", "filter"].reversed().joined()
        let selector = NSSelectorFromString(selectorName)
        guard filterClass.responds(to: selector) else { return nil }
        return { name in
            (filterClass as AnyObject).perform(selector, with: name)?.takeUnretainedValue() as? NSObject
        }
    }

    /// Finds the first subview whose class name contains the given string, ignoring case.
    static func findSubview(in view: UIView, containing name: String) -> UIView? {
        let lowercasedName = name.lowercased()
        return view.subviews.first { NSStringFromClass(type(of: $0)).lowercased().contains(lowercasedName) }
    }
}
