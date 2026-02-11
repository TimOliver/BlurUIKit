//
//  GradientImageRenderer.swift
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

/// An internal enum that generates gradient images pixel-by-pixel with eased
/// alpha transitions. This approach ensures smooth gradients across all iOS versions,
/// avoiding the hard edge artifacts present in CGGradient on iOS 16 and earlier.
@available(iOS 14, *)
@MainActor internal enum GradientImageRenderer {

    /// A shared cache that allows multiple blur views to re-use the same gradient image
    private static let cache = NSCache<CacheKey, CGImage>()

    // MARK: - Image Generation

    /// Generates a 1-pixel wide/tall gradient image, returning a cached copy when available.
    /// - Parameters:
    ///   - length: The length of the gradient in pixels.
    ///   - isVertical: If true, creates a 1xN image; if false, creates an Nx1 image.
    ///   - startLocation: Normalized position (0.0-1.0) where the gradient transition begins.
    ///                    Pixels before this point will be fully opaque (or transparent if reversed).
    ///   - reversed: If false, gradient goes opaque→transparent. If true, transparent→opaque.
    ///   - smooth: If true, applies sine-based easing for smooth transitions. If false, uses linear interpolation.
    /// - Returns: A CGImage containing the gradient, or nil if generation fails.
    static func makeGradientImage(
        length: Int,
        isVertical: Bool,
        startLocation: CGFloat = 0.0,
        reversed: Bool = false,
        smooth: Bool = false
    ) -> CGImage? {
        guard length > 0 else { return nil }

        // Check for a cached image matching these parameters
        let key = CacheKey(length: length,
                           isVertical: isVertical,
                           startLocation: startLocation,
                           reversed: reversed,
                           smooth: smooth)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // Create a grayscale + alpha bitmap context
        let width = isVertical ? 1 : length
        let height = isVertical ? length : 1
        let bytesPerPixel = 2

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let buffer = context.data else { return nil }

        let pixels = buffer.assumingMemoryBound(to: UInt8.self)

        // Clamp startLocation to valid range
        let clampedStartLocation = min(max(startLocation, 0.0), 1.0)

        // Precompute reciprocals used in the gradient calculation
        let lengthReciprocal: CGFloat = length > 1 ? 1.0 / CGFloat(length - 1) : 0.0
        let gradientRangeReciprocal: CGFloat = clampedStartLocation < 1.0 ? 1.0 / (1.0 - clampedStartLocation) : 0.0

        // Calculate the pixel boundary where the gradient transition starts.
        // Pixels before this boundary all share the same constant alpha value.
        let gradientStartPixel: Int = {
            guard length > 1, clampedStartLocation > 0.0 else { return 0 }
            return min(Int(clampedStartLocation * CGFloat(length - 1)) + 1, length)
        }()

        // Bulk-fill the constant region before the gradient (no per-pixel math needed)
        if gradientStartPixel > 0 {
            let constantAlpha: UInt8 = reversed ? 0 : 255
            for i in stride(from: 0, to: gradientStartPixel * bytesPerPixel, by: bytesPerPixel) {
                pixels[i] = 0
                pixels[i + 1] = constantAlpha
            }
        }

        // Generate the gradient transition for the remaining pixels
        for i in gradientStartPixel..<length {
            let normalizedPosition = CGFloat(i) * lengthReciprocal
            let adjustedPosition = (normalizedPosition - clampedStartLocation) * gradientRangeReciprocal
            let eased = smooth ? easeInOutSine(adjustedPosition) : adjustedPosition
            let alpha = reversed ? eased : 1.0 - eased

            let pixelIndex = i * bytesPerPixel
            pixels[pixelIndex] = 0
            pixels[pixelIndex + 1] = UInt8(min(max(alpha * 255.0, 0.0), 255.0))
        }

        guard let image = context.makeImage() else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Sine-based ease-in-out function for smooth gradient transitions.
    private static func easeInOutSine(_ t: CGFloat) -> CGFloat {
        -(cos(.pi * t) - 1.0) / 2.0
    }

    /// Shared color space for gradient image generation.
    private static let colorSpace = CGColorSpaceCreateDeviceGray()

    /// A class that wraps all of the properties of a gradient image
    /// into a hashable cache key value.
    private class CacheKey: NSObject {
        let length: Int
        let isVertical: Bool
        let startLocation: CGFloat
        let reversed: Bool
        let smooth: Bool

        init(length: Int, isVertical: Bool, startLocation: CGFloat, reversed: Bool, smooth: Bool) {
            self.length = length
            self.isVertical = isVertical
            self.startLocation = startLocation
            self.reversed = reversed
            self.smooth = smooth
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(length)
            hasher.combine(isVertical)
            hasher.combine(startLocation)
            hasher.combine(reversed)
            hasher.combine(smooth)
            return hasher.finalize()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? CacheKey else { return false }
            return length == other.length
                && isVertical == other.isVertical
                && startLocation == other.startLocation
                && reversed == other.reversed
                && smooth == other.smooth
        }
    }
}
