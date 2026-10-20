import XCTest
#if SWIFT_PACKAGE
@testable import BlurUIKit
#else
@testable import BlurUIKitExample
#endif

final class BlurFilterProviderTests: XCTestCase {
    @MainActor
    func testDiscoveryRetriesFailuresThenCachesTheFactoryAndCreatesFreshFilters() throws {
        var discoveryAttempts = 0
        var requestedNames: [String] = []
        let provider = BlurFilterProvider(discover: {
            discoveryAttempts += 1
            guard discoveryAttempts > 2 else { return nil }
            return { name in
                requestedNames.append(name)
                return NSObject()
            }
        })

        XCTContext.runActivity(named: "Each failed request makes one fresh discovery attempt") { _ in
            for request in 1...2 {
                XCTAssertNil(provider.makeFilter(named: "gaussianBlur"))
                XCTAssertEqual(discoveryAttempts, request)
            }
        }

        try XCTContext.runActivity(named: "Discovery recovers and its factory creates fresh filters") { _ in
            let first = try XCTUnwrap(provider.makeFilter(named: "gaussianBlur"))
            XCTAssertEqual(discoveryAttempts, 3)
            let second = try XCTUnwrap(provider.makeFilter(named: "gaussianBlur"))
            XCTAssertNotNil(provider.makeFilter(named: "variableBlur"))
            XCTAssertEqual(discoveryAttempts, 3)
            XCTAssertEqual(requestedNames, ["gaussianBlur", "gaussianBlur", "variableBlur"])
            XCTAssertFalse(first === second)
        }
    }

    @MainActor
    func testFilterCreationFailureRetriesWithoutDiscardingTheFactory() {
        var discoveryAttempts = 0
        var variableBlurAttempts = 0
        let gaussianFilter = NSObject()
        let variableFilter = NSObject()
        let provider = BlurFilterProvider(discover: {
            discoveryAttempts += 1
            return { name in
                if name == "gaussianBlur" { return gaussianFilter }
                variableBlurAttempts += 1
                return variableBlurAttempts > 1 ? variableFilter : nil
            }
        })

        XCTAssertNil(provider.makeFilter(named: "variableBlur"))
        XCTAssertTrue(provider.makeFilter(named: "gaussianBlur") === gaussianFilter)
        XCTAssertTrue(provider.makeFilter(named: "variableBlur") === variableFilter)

        XCTAssertEqual(discoveryAttempts, 1)
        XCTAssertEqual(variableBlurAttempts, 2)
    }
}
