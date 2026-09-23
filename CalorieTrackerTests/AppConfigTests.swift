import XCTest
@testable import CalorieTracker

final class AppConfigTests: XCTestCase {
    /// Debug builds run from Xcode must reach the real server (a demo machine has no local backend).
    func testDefaultsToProductionServer() throws {
        guard ProcessInfo.processInfo.environment["API_BASE_URL"] == nil else {
            throw XCTSkip("API_BASE_URL override is set for this run")
        }
        XCTAssertEqual(AppConfig.apiBaseURL, AppConfig.productionAPIBaseURL)
        XCTAssertEqual(AppConfig.apiBaseURL.scheme, "https")
    }
}
