import XCTest
@testable import BlurUIKit

final class BlurFilterProviderTests: XCTestCase {
    @MainActor
    func testInitialDiscoveryFailureRecoversOnTheNextRequest() {
        var discoveryAttempts = 0
        let filter = NSObject()
        let provider = BlurFilterProvider(discover: {
            discoveryAttempts += 1
            guard discoveryAttempts > 1 else { return nil }
            return { _ in filter }
        })

        XCTAssertNil(provider.makeFilter(named: "gaussianBlur"))
        XCTAssertEqual(discoveryAttempts, 1)

        XCTAssertTrue(provider.makeFilter(named: "gaussianBlur") === filter)
        XCTAssertEqual(discoveryAttempts, 2)
    }

    @MainActor
    func testPermanentDiscoveryFailureAttemptsOnlyOncePerRequest() {
        var discoveryAttempts = 0
        let provider = BlurFilterProvider(discover: {
            discoveryAttempts += 1
            return nil
        })

        for request in 1...3 {
            XCTAssertNil(provider.makeFilter(named: "variableBlur"))
            XCTAssertEqual(discoveryAttempts, request)
        }
    }

    @MainActor
    func testSuccessfulDiscoveryIsCachedWhileEachRequestCreatesAFilter() throws {
        var discoveryAttempts = 0
        var requestedNames: [String] = []
        let provider = BlurFilterProvider(discover: {
            discoveryAttempts += 1
            return { name in
                requestedNames.append(name)
                return NSObject()
            }
        })

        let first = try XCTUnwrap(provider.makeFilter(named: "gaussianBlur"))
        let second = try XCTUnwrap(provider.makeFilter(named: "gaussianBlur"))
        XCTAssertNotNil(provider.makeFilter(named: "variableBlur"))

        XCTAssertEqual(discoveryAttempts, 1)
        XCTAssertEqual(requestedNames, ["gaussianBlur", "gaussianBlur", "variableBlur"])
        XCTAssertFalse(first === second)
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
