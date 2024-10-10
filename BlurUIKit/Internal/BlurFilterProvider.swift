//
//  BlurUIKitHelpers.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit

// An internal class that creates, manages and vends the blur filters
// used by the public classes of this framework.
internal class BlurFilterProvider {

    // A shared blur visual effect view that is used to hook and extract a reference to the CAFilter class
    static let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

    /// Vends a newly instantiated CAFilter instance with the provided filter name
    /// - Parameter name: The name of the filter that this filter should be instantiated with
    /// - Returns: The new CAFilter object, or nil if the filter if it couldn't be created.
    static func blurFilter(named name: String) -> NSObject? {
        // The only private method we need is '+[CAFilter filterWithType:]'
        // We probably don't need to obfuscate this since it's not prefixed with a '_'
        let selectorName = ["Type:", "With", "filter"].reversed().joined()
        let selector = NSSelectorFromString(selectorName)

        // Fetch a filter from out of the shared blur view so we can access the CAFilter class.
        guard let backdropView = findSubview(in: blurView, containing: "backdrop"),
              let filter = backdropView.layer.filters?.first as? NSObject else {
            return nil
        }

        // Using the blur view filter object as a base, fetch the CAFilter class, and use that to instantiate a new object
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
