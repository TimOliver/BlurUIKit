//
//  ReflectionBlurView.swift
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

/// A UIView that vertically mirrors its hosted content,
/// and applies a variable blur effect to the reflection.
@available(iOS 14, *)
public class ReflectionBlurView: UIView {

    /// The container view that holds all of the view content that will be reflected.
    /// An empty one is created by default, but it can be replaced with an external view as well
    public var contentView: UIView! {
        didSet {
            addSubview(contentView)
            setNeedsLayout()
        }
    }

    // MARK: - Init

    /// Create a new instance of ReflectionBlurView providing an external content view.
    /// - Parameter contentView: The content view that will be used in reflections
    init(contentView: UIView) {
        super.init(frame: contentView.bounds)
        self.contentView = contentView
    }

    /// Create a new instance of ReflectionBlurView with the provided frame.
    /// - Parameter frame: The frame of this new view
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView = UIView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
}
