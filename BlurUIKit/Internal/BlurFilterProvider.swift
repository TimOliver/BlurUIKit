//
//  BlurUIKitHelpers.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 15/6/2024.
//

import UIKit

protocol BlurFilterProvivadable: NSObjectProtocol {
    func filter(withName: String) -> NSObject
}

// An internal class that creates, manages and vends the blur filters
// used by the public classes of this framework.
internal class BlurFilterProvider {

    // A shared blur visual effect view is used to hook and extract a reference
    static let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

    // Vends a filter
    static func blurFilter(named: String) -> NSObject? {
        // Fetch the filter from out of the shared blur view
        guard let backdropView = blurView.subviews.first(where: {
            String(describing: $0).lowercased().contains("backdrop")
        }), let filter = backdropView.layer.filters?.first as? NSObject else {
            return nil
        }



        return nil
    }
}
