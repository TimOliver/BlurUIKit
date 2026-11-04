//
//  ObjCInteropTests.m
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

// Exercises the library through its generated Objective-C header, so compiling this file
// verifies the API is reachable from Objective-C, and running it verifies the bridges.

@import XCTest;
@import UIKit;
@import BlurUIKit;

@interface ObjCInteropTests : XCTestCase
@end

@implementation ObjCInteropTests

- (void)testVariableBlurViewProperties {
    VariableBlurView *view = [[VariableBlurView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];

    view.direction = VariableBlurViewDirectionLeft;
    view.minimumBlurRadius = 1.0;
    view.maximumBlurRadius = 10.0;
    view.dimmingTintColor = nil;
    view.replacesBlurWhenReducingTransparency = NO;

    XCTAssertEqual(view.direction, VariableBlurViewDirectionLeft);
    XCTAssertEqual(view.minimumBlurRadius, 1.0);
    XCTAssertEqual(view.maximumBlurRadius, 10.0);
    XCTAssertNil(view.dimmingTintColor);
    XCTAssertFalse(view.replacesBlurWhenReducingTransparency);
}

- (void)testGradientSizingRoundTrips {
    VariableBlurView *view = [[VariableBlurView alloc] initWithFrame:CGRectZero];

    // The Swift default of 25% extra comes through as a relative sizing
    XCTAssertTrue(view.dimmingClearExtension.isRelative);
    XCTAssertEqual(view.dimmingClearExtension.value, 0.25);

    view.blurMaximumRadiusInset = [VariableBlurViewGradientSizing absoluteWithPosition:24.0];
    XCTAssertFalse(view.blurMaximumRadiusInset.isRelative);
    XCTAssertEqual(view.blurMaximumRadiusInset.value, 24.0);

    view.dimmingFullColorInset = [VariableBlurViewGradientSizing relativeWithFraction:0.5];
    XCTAssertEqualObjects(view.dimmingFullColorInset, [VariableBlurViewGradientSizing relativeWithFraction:0.5]);
    XCTAssertNotEqualObjects(view.dimmingFullColorInset, [VariableBlurViewGradientSizing absoluteWithPosition:0.5]);

    view.dimmingClearExtension = nil;
    XCTAssertNil(view.dimmingClearExtension);
}

- (void)testDimmingAlphaRoundTrips {
    VariableBlurView *view = [[VariableBlurView alloc] initWithFrame:CGRectZero];

    // The Swift default differs between light and dark mode
    XCTAssertEqual(view.dimmingAlpha.lightModeAlpha, 0.5);
    XCTAssertEqual(view.dimmingAlpha.darkModeAlpha, 0.25);

    view.dimmingAlpha = [VariableBlurViewDimmingAlpha constantWithAlpha:0.75];
    XCTAssertEqual(view.dimmingAlpha.lightModeAlpha, 0.75);
    XCTAssertEqual(view.dimmingAlpha.darkModeAlpha, 0.75);
    XCTAssertEqualObjects(view.dimmingAlpha, [VariableBlurViewDimmingAlpha constantWithAlpha:0.75]);

    // A constant is kept distinct from an interface style that happens to use the same values
    XCTAssertNotEqualObjects(view.dimmingAlpha,
                             [VariableBlurViewDimmingAlpha interfaceStyleWithLightModeAlpha:0.75 darkModeAlpha:0.75]);

    view.dimmingAlpha = nil;
    XCTAssertNil(view.dimmingAlpha);
}

- (void)testReflectionBlurViewProperties {
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
    ReflectionBlurView *view = [[ReflectionBlurView alloc] initWithContentView:contentView];
    XCTAssertEqual(view.contentView, contentView);

    view.reflectionAlpha = 0.25;
    view.isReflectionHidden = YES;
    view.maximumBlurRadius = 20.0;
    view.minimumBlurRadius = 2.0;
    view.dimmingTintColor = UIColor.redColor;
    view.blurMaximumRadiusInset = [VariableBlurViewGradientSizing relativeWithFraction:0.5];
    view.dimmingAlpha = [VariableBlurViewDimmingAlpha constantWithAlpha:0.4];
    view.dimmingFullColorInset = [VariableBlurViewGradientSizing absoluteWithPosition:8.0];
    view.dimmingClearExtension = [VariableBlurViewGradientSizing absoluteWithPosition:16.0];
    [view setNeedsReflectionUpdate];

    XCTAssertEqual(view.reflectionAlpha, 0.25);
    XCTAssertTrue(view.isReflectionHidden);
    XCTAssertEqual(view.maximumBlurRadius, 20.0);
    XCTAssertEqual(view.minimumBlurRadius, 2.0);
    XCTAssertEqualObjects(view.dimmingTintColor, UIColor.redColor);
    XCTAssertEqualObjects(view.blurMaximumRadiusInset, [VariableBlurViewGradientSizing relativeWithFraction:0.5]);
    XCTAssertEqualObjects(view.dimmingAlpha, [VariableBlurViewDimmingAlpha constantWithAlpha:0.4]);
    XCTAssertEqualObjects(view.dimmingFullColorInset, [VariableBlurViewGradientSizing absoluteWithPosition:8.0]);
    XCTAssertEqualObjects(view.dimmingClearExtension, [VariableBlurViewGradientSizing absoluteWithPosition:16.0]);
}

- (void)testAnimatedBlurRadius {
    NSString *animationKey = @"filters.gaussianBlur.inputRadius";
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];

    // The default duration and automatic timing
    [view setBlurRadiusAnimated:20.0];
    CABasicAnimation *animation = (CABasicAnimation *)[view.layer animationForKey:animationKey];
    XCTAssertEqual(view.blurRadius, 20.0);
    XCTAssertEqualWithAccuracy(animation.duration, 0.45, 0.0001);
    [self assertTimingFunction:animation.timingFunction matches:CAMediaTimingFunction.blurEaseIn];

    // A custom duration
    [view setBlurRadiusAnimated:10.0 duration:1.0];
    animation = (CABasicAnimation *)[view.layer animationForKey:animationKey];
    XCTAssertEqual(view.blurRadius, 10.0);
    XCTAssertEqual(animation.duration, 1.0);
    [self assertTimingFunction:animation.timingFunction matches:CAMediaTimingFunction.blurEaseOut];

    // A custom timing function is used as given
    CAMediaTimingFunction *linear = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [view setBlurRadiusAnimated:30.0 duration:2.0 delay:0.0 timingFunction:linear];
    animation = (CABasicAnimation *)[view.layer animationForKey:animationKey];
    XCTAssertEqual(view.blurRadius, 30.0);
    XCTAssertEqual(animation.duration, 2.0);
    XCTAssertEqual(animation.timingFunction, linear);

    // A nil timing function falls back to the automatic timing
    [view setBlurRadiusAnimated:0.0 duration:1.0 delay:0.0 timingFunction:nil];
    animation = (CABasicAnimation *)[view.layer animationForKey:animationKey];
    [self assertTimingFunction:animation.timingFunction matches:CAMediaTimingFunction.blurEaseOut];
}

- (void)testVisualEffectViewProperties {
    UIVisualEffectView *view = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    view.dimmingAlpha = 0.5;
    view.blurEffectRadius = 4.0;
    XCTAssertGreaterThanOrEqual(view.blurEffectRadius, 0.0);
}

#pragma mark - Helpers

- (void)assertTimingFunction:(CAMediaTimingFunction *)timingFunction matches:(CAMediaTimingFunction *)expected {
    XCTAssertNotNil(timingFunction);
    for (size_t index = 1; index <= 2; index++) {
        float actualPoint[2], expectedPoint[2];
        [timingFunction getControlPointAtIndex:index values:actualPoint];
        [expected getControlPointAtIndex:index values:expectedPoint];
        XCTAssertEqual(actualPoint[0], expectedPoint[0]);
        XCTAssertEqual(actualPoint[1], expectedPoint[1]);
    }
}

@end
