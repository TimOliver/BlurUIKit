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

/// Discovers and creates the Core Animation filters used by the framework's public blur APIs.
///
/// Discovery is deferred until a filter is requested. A successfully discovered factory is
/// cached, while unsuccessful discovery can be retried on a later request. Filter instances
/// are created separately for each request so callers can configure them independently.
@MainActor internal class BlurFilterProvider {

    /// Creates a new filter for the supplied Core Animation filter type, such as
    /// `"gaussianBlur"` or `"variableBlur"`, or returns nil if that filter cannot be created.
    ///
    /// The closure runs on the main actor, matching the UIKit views and layers using its result.
    typealias FilterFactory = @MainActor (String) -> NSObject?

    /// The provider used by `blurFilter(named:)` and, through it, the public blur APIs.
    /// Tests can replace this instance to simulate discovery or filter-creation failures.
    static var shared = BlurFilterProvider()

    /// Resolves a factory capable of creating filters, rather than creating a filter itself.
    /// Called once per request while no factory is cached. Returning nil leaves discovery
    /// pending so a later request can retry. Supplied at initialization for failure testing.
    private let discover: @MainActor () -> FilterFactory?

    /// The successfully discovered factory, reused to create subsequent filter instances.
    /// Nil means discovery has not run or its most recent attempt failed. A factory remains
    /// cached even if it returns nil for an individual filter-creation request.
    private var filterFactory: FilterFactory?

    /// Creates a provider that discovers UIKit's filter factory on its first filter request.
    /// Initialization itself does not create a visual effect view or perform discovery.
    convenience init() {
        self.init(discover: Self.discoverFilterFactory)
    }

    /// Creates a provider with a custom factory-discovery closure.
    ///
    /// Use this initializer to simulate unavailable factories or failed filter creation in tests.
    /// The closure is stored without being called during initialization.
    ///
    /// - Parameter discover: A main-actor closure returning a filter factory, or nil if one is
    ///   unavailable. A successful result is cached; nil permits another attempt on the next request.
    init(discover: @escaping @MainActor () -> FilterFactory?) {
        self.discover = discover
    }

    /// Creates a filter, discovering and caching its factory if necessary.
    ///
    /// Each call makes at most one discovery attempt and one factory invocation. Failed
    /// discovery is retried only on a later call. Failure to create an individual filter
    /// leaves a successfully discovered factory cached for subsequent requests.
    ///
    /// - Parameter name: The Core Animation filter type, such as `"gaussianBlur"` or `"variableBlur"`.
    /// - Returns: A new filter, or nil if discovery or filter creation fails.
    func makeFilter(named name: String) -> NSObject? {
        if filterFactory == nil {
            filterFactory = discover()
        }
        return filterFactory?(name)
    }

    /// Extracts the filter class from a temporary UIKit backdrop and checks for `filterWithType:`.
    ///
    /// The returned closure captures only the class and selector. The temporary visual effect
    /// view and its existing filter are not retained by the factory.
    ///
    /// - Returns: A factory that dynamically invokes `filterWithType:`, or nil if UIKit exposes
    ///   no backdrop filter or its class does not support that selector.
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

    /// Creates a filter through the shared provider, using its discovery cache and retry behavior.
    /// - Parameter name: The Core Animation filter type to create.
    /// - Returns: A new filter, or nil if discovery or filter creation fails.
    static func blurFilter(named name: String) -> NSObject? {
        shared.makeFilter(named: name)
    }

    /// Loop through a view's subviews and find the one with its class name containing the provided string
    /// - Parameter view: The view whose subviews will be searched.
    /// - Parameter name: The portion of the name of the subview to find.
    /// - Returns: The subview if it is found, or nil otherwise.
    static func findSubview(in view: UIView, containing name: String) -> UIView? {
        let lowercasedName = name.lowercased()
        return view.subviews.first { NSStringFromClass(type(of: $0)).lowercased().contains(lowercasedName) }
    }
}
