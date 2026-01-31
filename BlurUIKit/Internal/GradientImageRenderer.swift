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

/// An internal class that generates gradient images pixel-by-pixel with eased
/// alpha transitions. This approach ensures smooth gradients across all iOS versions,
/// avoiding the hard edge artifacts present in CGGradient on iOS 16 and earlier.
@available(iOS 14, *)
internal enum GradientImageRenderer {

    /// Generates a 1-pixel wide/tall gradient image with smooth alpha transitions.
    /// - Parameters:
    ///   - length: The length of the gradient in pixels.
    ///   - isVertical: If true, creates a 1xN image; if false, creates an Nx1 image.
    ///   - startLocation: Normalized position (0.0-1.0) where the gradient transition begins.
    ///                    Pixels before this point will be fully opaque (or transparent if reversed).
    ///   - reversed: If false, gradient goes opaque→transparent. If true, transparent→opaque.
    /// - Returns: A CGImage containing the gradient, or nil if generation fails.
    static func makeGradientImage(
        length: Int,
        isVertical: Bool,
        startLocation: CGFloat = 0.0,
        reversed: Bool = false
    ) -> CGImage? {
        guard length > 0 else { return nil }

        // Create pixel data - RGBA format
        let width = isVertical ? 1 : length
        let height = isVertical ? length : 1
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // Clamp startLocation to valid range
        let clampedStartLocation = min(max(startLocation, 0.0), 1.0)

        // Calculate gradient values for each pixel
        for i in 0..<length {
            // Determine normalized position along the gradient (0.0 to 1.0)
            let normalizedPosition = length > 1 ? CGFloat(i) / CGFloat(length - 1) : 0.0

            // Calculate alpha with starting inset
            let alpha: CGFloat = {
                // Adjust for starting inset - pixels before startLocation are fully opaque/transparent
                let adjustedPosition: CGFloat
                if clampedStartLocation >= 1.0 {
                    adjustedPosition = 0.0
                } else if normalizedPosition <= clampedStartLocation {
                    adjustedPosition = 0.0
                } else {
                    adjustedPosition = (normalizedPosition - clampedStartLocation) / (1.0 - clampedStartLocation)
                }

                // Apply easing for smooth transition
                let easedPosition = easeInOutSine(adjustedPosition)

                // Apply direction
                return reversed ? easedPosition : 1.0 - easedPosition
            }()

            // Convert to 8-bit value and write pixel (RGBA - black with varying alpha)
            let alphaValue = UInt8(min(max(alpha * 255.0, 0.0), 255.0))
            let pixelIndex = i * bytesPerPixel
            pixelData[pixelIndex] = 0               // R
            pixelData[pixelIndex + 1] = 0           // G
            pixelData[pixelIndex + 2] = 0           // B
            pixelData[pixelIndex + 3] = alphaValue  // A
        }

        // Create CGImage from pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return cgImage
    }

    /// Sine-based ease-in-out function for smooth gradient transitions.
    private static func easeInOutSine(_ t: CGFloat) -> CGFloat {
        -(cos(.pi * t) - 1.0) / 2.0
    }
}
