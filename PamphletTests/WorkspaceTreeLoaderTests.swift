import XCTest
@testable import Pamphlet

@MainActor
final class WorkspaceTreeLoaderTests: XCTestCase {
    func testLoaderPublishesRootBeforePreloadingDescendants() async throws {
        let workspaceURL = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)
        let scanner = FakeDirectoryScanner(childrenByPath: [
            "": [
                node(workspaceURL: workspaceURL, relativePath: "docs", isDirectory: true),
                node(workspaceURL: workspaceURL, relativePath: "README.md", isDirectory: false),
            ],
            "docs": [
                node(workspaceURL: workspaceURL, relativePath: "docs/guide.md", isDirectory: false),
            ],
        ])
        let loader = WorkspaceTreeLoader(workspaceURL: workspaceURL, scanner: scanner)
        var iterator = loader.events.makeAsyncIterator()

        loader.start()

        let rootLoading = await iterator.next()
        guard case .rootLoading = rootLoading else {
            return XCTFail("Expected root loading event")
        }

        let rootLoaded = await iterator.next()
        guard case .rootLoaded(_, let rootChildren) = rootLoaded else {
            return XCTFail("Expected root loaded event")
        }
        XCTAssertEqual(rootChildren.map(\.relativePath), ["docs", "README.md"])

        let preloadStarted = await iterator.next()
        guard case .preloadStarted = preloadStarted else {
            return XCTFail("Expected preload started event")
        }

        let directoryLoaded = await iterator.next()
        guard case .directoryLoaded(_, "docs", let docsChildren, .background) = directoryLoaded else {
            return XCTFail("Expected background docs load event")
        }
        XCTAssertEqual(docsChildren.map(\.relativePath), ["docs/guide.md"])
    }

    func testFileManagerScannerIncludesHiddenFilesAndLeavesIgnoredFoldersUnloaded() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root.appendingPathComponent(".hidden-folder"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent(".env"))
        try Data().write(to: root.appendingPathComponent("README.md"))

        let children = try await FileManagerDirectoryScanner().scanChildren(
            of: root,
            relativePath: "",
            ignorePolicy: .default
        )

        XCTAssertEqual(children.map(\.relativePath), [".hidden-folder", "node_modules", ".env", "README.md"])
        XCTAssertEqual(children.first { $0.relativePath == ".hidden-folder" }?.loadState, .unloaded)
        XCTAssertEqual(children.first { $0.relativePath == "node_modules" }?.loadState, .ignored)
        XCTAssertEqual(children.first { $0.relativePath == ".env" }?.loadState, .file)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

}

@MainActor
private final class FakeDirectoryScanner: DirectoryScanning {
    private let childrenByPath: [String: [FileNode]]

    init(childrenByPath: [String: [FileNode]]) {
        self.childrenByPath = childrenByPath
    }

    func scanChildren(
        of folderURL: URL,
        relativePath: String,
        ignorePolicy: WorkspaceTreeIgnorePolicy
    ) async throws -> [FileNode] {
        childrenByPath[relativePath] ?? []
    }
}

private func node(workspaceURL: URL, relativePath: String, isDirectory: Bool) -> FileNode {
    let url = workspaceURL.appendingPathComponent(relativePath, isDirectory: isDirectory)
    return FileNode(
        id: relativePath,
        url: url,
        relativePath: relativePath,
        name: url.lastPathComponent,
        isDirectory: isDirectory,
        isViewable: !isDirectory,
        children: []
    )
}
