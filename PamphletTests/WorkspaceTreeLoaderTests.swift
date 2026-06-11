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

        let directoryLoading = await iterator.next()
        guard case .directoryLoading(_, "docs", .background) = directoryLoading else {
            return XCTFail("Expected background docs loading event")
        }

        let directoryLoaded = await iterator.next()
        guard case .directoryLoaded(_, "docs", let docsChildren, .background) = directoryLoaded else {
            return XCTFail("Expected background docs load event")
        }
        XCTAssertEqual(docsChildren.map(\.relativePath), ["docs/guide.md"])
    }

    func testForegroundExpansionPromotesInFlightBackgroundPreload() async throws {
        let workspaceURL = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)
        let scanner = SuspendedDirectoryScanner(childrenByPath: [
            "": [
                node(workspaceURL: workspaceURL, relativePath: "docs", isDirectory: true),
            ],
            "docs": [
                node(workspaceURL: workspaceURL, relativePath: "docs/guide.md", isDirectory: false),
            ],
        ])
        let loader = WorkspaceTreeLoader(workspaceURL: workspaceURL, scanner: scanner, maxConcurrentScans: 1)
        var iterator = loader.events.makeAsyncIterator()

        loader.start()

        _ = await iterator.next()
        await scanner.resume(path: "")

        guard case .rootLoaded(_, let rootChildren) = await iterator.next() else {
            return XCTFail("Expected root loaded event")
        }
        guard let docs = rootChildren.first else {
            return XCTFail("Expected docs node")
        }

        _ = await iterator.next()
        guard case .directoryLoading(_, "docs", .background) = await iterator.next() else {
            return XCTFail("Expected background docs loading event")
        }

        loader.loadDirectory(docs)

        guard case .directoryLoading(_, "docs", .foreground) = await iterator.next() else {
            return XCTFail("Expected foreground promotion event")
        }

        await scanner.resume(path: "docs")

        guard case .directoryLoaded(_, "docs", let docsChildren, .foreground) = await iterator.next() else {
            return XCTFail("Expected promoted foreground docs load event")
        }
        XCTAssertEqual(docsChildren.map(\.relativePath), ["docs/guide.md"])

        let scanCounts = await scanner.scanCounts
        XCTAssertEqual(scanCounts["docs"], 1)
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
            ignorePolicy: .default,
            priority: .utility
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
        ignorePolicy: WorkspaceTreeIgnorePolicy,
        priority: TaskPriority
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

private actor SuspendedDirectoryScanner: DirectoryScanning {
    private let childrenByPath: [String: [FileNode]]
    private var continuations: [String: CheckedContinuation<Void, Never>] = [:]
    private var counts: [String: Int] = [:]

    init(childrenByPath: [String: [FileNode]]) {
        self.childrenByPath = childrenByPath
    }

    var scanCounts: [String: Int] {
        counts
    }

    func scanChildren(
        of folderURL: URL,
        relativePath: String,
        ignorePolicy: WorkspaceTreeIgnorePolicy,
        priority: TaskPriority
    ) async throws -> [FileNode] {
        counts[relativePath, default: 0] += 1
        await withCheckedContinuation { continuation in
            continuations[relativePath] = continuation
        }
        return childrenByPath[relativePath] ?? []
    }

    func resume(path: String) {
        continuations.removeValue(forKey: path)?.resume()
    }
}
