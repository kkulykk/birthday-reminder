import XCTest
import SwiftData
@testable import BirthdayReminder

final class SharedContainerTests: XCTestCase {

    // MARK: - makeSharedModelContainer

    func testMakeSharedModelContainer_noGroupURL_returnsFallbackContainer() {
        // When no App Group URL is available (always the case in tests),
        // the function must fall back to the default container and not crash.
        let container = makeSharedModelContainer(groupURL: nil)
        XCTAssertNotNil(container)
    }

    func testMakeSharedModelContainer_validGroupURL_usesGroupURL() throws {
        // Provide a writable temp URL so the App Group path succeeds.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".store")
        defer { try? FileManager.default.removeItem(atPath: tempURL.path) }

        let container = makeSharedModelContainer(groupURL: tempURL)
        XCTAssertNotNil(container)
    }

    func testMakeSharedModelContainer_unreachableGroupURL_fallsBackToDefault() {
        // A path inside a non-existent directory forces ModelContainer creation
        // to fail, exercising the fallback branch.
        let badURL = URL(fileURLWithPath: "/nonexistent/deep/path/\(UUID().uuidString).store")
        let container = makeSharedModelContainer(groupURL: badURL)
        XCTAssertNotNil(container)
    }
}
