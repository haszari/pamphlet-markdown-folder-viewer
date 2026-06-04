import XCTest
@testable import Pamphlet

final class WorkspaceModelTests: XCTestCase {
    func testRelativePathStaysInsideWorkspace() throws {
        let root = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)
        let file = root.appendingPathComponent("docs/readme.md")
        XCTAssertEqual(file.relativePath(from: root), "docs/readme.md")
    }

    func testViewableTypeDetectionUsesMarkdownAndTables() throws {
        XCTAssertEqual(ViewableTypeDetector.mode(for: URL(fileURLWithPath: "/tmp/README.md"))?.rendererMode, "markdown")
        XCTAssertEqual(ViewableTypeDetector.mode(for: URL(fileURLWithPath: "/tmp/data.csv"))?.rendererMode, "table")
        XCTAssertNil(ViewableTypeDetector.mode(for: URL(fileURLWithPath: "/tmp/archive.zip")))
    }

    func testSVGSelectedDirectlyIsSourceCode() throws {
        let mode = ViewableTypeDetector.mode(for: URL(fileURLWithPath: "/tmp/diagram.svg"))
        XCTAssertEqual(mode?.rendererMode, "code")
        XCTAssertEqual(mode?.language, "xml")
    }
}
