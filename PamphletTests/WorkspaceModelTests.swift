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

    func testLoadedDirectoryRemainsExpandableEvenWhenChildrenAreNotVisibleYet() throws {
        let root = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)
        let folder = FileNode(
            id: "docs",
            url: root.appendingPathComponent("docs", isDirectory: true),
            relativePath: "docs",
            name: "docs",
            isDirectory: true,
            isViewable: false,
            loadState: .loaded,
            children: []
        )

        XCTAssertTrue(folder.canExpand)
    }

    func testNonRecursiveDirectoryIsNotExpandable() throws {
        let root = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)
        let folder = FileNode(
            id: "linked-docs",
            url: root.appendingPathComponent("linked-docs", isDirectory: true),
            relativePath: "linked-docs",
            name: "linked-docs",
            isDirectory: true,
            isViewable: false,
            loadState: .nonRecursive,
            children: []
        )

        XCTAssertFalse(folder.canExpand)
    }

    func testRendererBootstrapDecodesPayloadAsUTF8() throws {
        let content = "dash \u{2014} accent cafe\u{0301} emoji \u{1F34C} cjk \u{4E2D}\u{6587}"
        let payload = RendererPayload(
            mode: "markdown",
            content: content,
            language: nil,
            imageUrl: nil,
            fileName: "unicode.md",
            filePath: "unicode.md",
            workspaceToken: "workspace",
            refreshVersion: 1,
            table: nil,
            theme: RendererPayload.ThemePayload(
                variables: [:],
                appCSS: "",
                workspaceCSS: "",
                appearance: "adaptive"
            )
        )

        let script = try RendererBootstrap.renderScript(for: payload)
        XCTAssertTrue(script.contains(#"new TextDecoder("utf-8").decode(payloadBytes)"#))
        XCTAssertFalse(script.contains("JSON.parse(atob"))

        let encodedPayload = try XCTUnwrap(base64Payload(from: script))
        let data = try XCTUnwrap(Data(base64Encoded: encodedPayload))
        let decodedPayload = try JSONDecoder().decode(RendererPayload.self, from: data)
        XCTAssertEqual(decodedPayload.content, content)
    }

    private func base64Payload(from script: String) -> String? {
        let startMarker = #"atob(""#
        guard let startRange = script.range(of: startMarker) else { return nil }
        let valueStart = startRange.upperBound
        guard let endRange = script[valueStart...].range(of: "\"", options: []) else { return nil }
        return String(script[valueStart..<endRange.lowerBound])
    }
}
