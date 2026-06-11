import Foundation

struct WorkspaceTreeIgnorePolicy: Equatable, Sendable {
    let ignoredNames: Set<String>

    static let `default` = WorkspaceTreeIgnorePolicy(ignoredNames: [
        ".git",
        "node_modules",
        ".next",
        ".turbo",
        ".cache",
        ".parcel-cache",
        "dist",
        "build",
        "DerivedData",
        ".venv",
        "vendor",
    ])

    func ignores(_ name: String) -> Bool {
        ignoredNames.contains(name)
    }
}

enum WorkspaceTreeLoadEvent: Equatable, Sendable {
    case rootLoading(UUID)
    case rootLoaded(UUID, [FileNode])
    case directoryLoading(UUID, String, FileNodeLoadReason)
    case directoryLoaded(UUID, String, [FileNode], FileNodeLoadReason)
    case directoryFailed(UUID, String, FileNodeLoadReason)
    case preloadStarted(UUID)
    case preloadFinished(UUID)

    var generation: UUID {
        switch self {
        case .rootLoading(let generation),
             .rootLoaded(let generation, _),
             .directoryLoading(let generation, _, _),
             .directoryLoaded(let generation, _, _, _),
             .directoryFailed(let generation, _, _),
             .preloadStarted(let generation),
             .preloadFinished(let generation):
            return generation
        }
    }
}

@MainActor
protocol DirectoryScanning {
    func scanChildren(of folderURL: URL, relativePath: String, ignorePolicy: WorkspaceTreeIgnorePolicy) async throws -> [FileNode]
}

struct FileManagerDirectoryScanner: DirectoryScanning {
    func scanChildren(of folderURL: URL, relativePath: String, ignorePolicy: WorkspaceTreeIgnorePolicy) async throws -> [FileNode] {
        try await Task.detached(priority: .utility) {
            try Self.scanChildrenSync(of: folderURL, relativePath: relativePath, ignorePolicy: ignorePolicy)
        }.value
    }

    nonisolated private static func scanChildrenSync(
        of folderURL: URL,
        relativePath: String,
        ignorePolicy: WorkspaceTreeIgnorePolicy
    ) throws -> [FileNode] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: []
        )

        let nodes = urls.map { url -> FileNode in
            let values = try? url.resourceValues(forKeys: keys)
            let isDirectory = values?.isDirectory == true
            let isSymlink = values?.isSymbolicLink == true
            let childRelativePath = [relativePath, url.lastPathComponent].filter { !$0.isEmpty }.joined(separator: "/")
            let isIgnored = isDirectory && ignorePolicy.ignores(url.lastPathComponent)
            return FileNode(
                id: childRelativePath,
                url: url,
                relativePath: childRelativePath,
                name: url.lastPathComponent,
                isDirectory: isDirectory,
                isViewable: !isDirectory && ViewableTypeDetector.isViewable(url),
                loadState: Self.loadState(isDirectory: isDirectory, isSymlink: isSymlink, isIgnored: isIgnored),
                children: []
            )
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    nonisolated private static func loadState(isDirectory: Bool, isSymlink: Bool, isIgnored: Bool) -> FileNodeLoadState {
        guard isDirectory else { return .file }
        if isIgnored { return .ignored }
        if isSymlink { return .loaded }
        return .unloaded
    }
}

@MainActor
final class WorkspaceTreeLoader {
    private let workspaceURL: URL
    private let scanner: DirectoryScanning
    private let ignorePolicy: WorkspaceTreeIgnorePolicy
    private let maxConcurrentScans: Int
    private let continuation: AsyncStream<WorkspaceTreeLoadEvent>.Continuation
    private var generation = UUID()
    private var tasks: [String: Task<Void, Never>] = [:]
    private var preloadTask: Task<Void, Never>?

    let events: AsyncStream<WorkspaceTreeLoadEvent>

    init(
        workspaceURL: URL,
        scanner: DirectoryScanning = FileManagerDirectoryScanner(),
        ignorePolicy: WorkspaceTreeIgnorePolicy = .default,
        maxConcurrentScans: Int = 4
    ) {
        self.workspaceURL = workspaceURL.standardizedFileURL
        self.scanner = scanner
        self.ignorePolicy = ignorePolicy
        self.maxConcurrentScans = max(1, maxConcurrentScans)
        var streamContinuation: AsyncStream<WorkspaceTreeLoadEvent>.Continuation!
        self.events = AsyncStream { continuation in
            streamContinuation = continuation
        }
        self.continuation = streamContinuation
    }

    deinit {
        continuation.finish()
    }

    var currentGeneration: UUID {
        generation
    }

    func start() {
        cancelTasks()
        generation = UUID()
        let activeGeneration = generation
        emit(.rootLoading(activeGeneration))
        loadRoot(generation: activeGeneration)
    }

    func refresh() {
        start()
    }

    func loadDirectory(_ node: FileNode, reason: FileNodeLoadReason = .foreground) {
        guard node.canExpand else { return }
        loadDirectory(url: node.url, relativePath: node.relativePath, generation: generation, reason: reason)
    }

    func cancel() {
        cancelTasks()
        generation = UUID()
    }

    private func loadRoot(generation: UUID) {
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let children = try await scanner.scanChildren(of: workspaceURL, relativePath: "", ignorePolicy: ignorePolicy)
                guard !Task.isCancelled, self.generation == generation else { return }
                emit(.rootLoaded(generation, children))
                startPreload(children: children, generation: generation)
            } catch {
                guard !Task.isCancelled, self.generation == generation else { return }
                emit(.rootLoaded(generation, []))
            }
            tasks.removeValue(forKey: "")
        }
        tasks[""] = task
    }

    private func loadDirectory(url: URL, relativePath: String, generation: UUID, reason: FileNodeLoadReason) {
        guard tasks[relativePath] == nil else { return }
        emit(.directoryLoading(generation, relativePath, reason))
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let children = try await scanner.scanChildren(of: url, relativePath: relativePath, ignorePolicy: ignorePolicy)
                guard !Task.isCancelled, self.generation == generation else { return }
                emit(.directoryLoaded(generation, relativePath, children, reason))
            } catch {
                guard !Task.isCancelled, self.generation == generation else { return }
                emit(.directoryFailed(generation, relativePath, reason))
            }
            tasks.removeValue(forKey: relativePath)
        }
        tasks[relativePath] = task
    }

    private func startPreload(children: [FileNode], generation: UUID) {
        preloadTask?.cancel()
        preloadTask = Task { [weak self] in
            guard let self else { return }
            emit(.preloadStarted(generation))
            var queue = children.filter(\.canExpand)

            while !queue.isEmpty {
                guard !Task.isCancelled, self.generation == generation else { return }
                let batch = Array(queue.prefix(maxConcurrentScans))
                queue.removeFirst(min(maxConcurrentScans, queue.count))

                for node in batch {
                    guard !Task.isCancelled, self.generation == generation else { return }
                    do {
                        let children = try await scanner.scanChildren(
                            of: node.url,
                            relativePath: node.relativePath,
                            ignorePolicy: ignorePolicy
                        )
                        guard !Task.isCancelled, self.generation == generation else { return }
                        emit(.directoryLoaded(generation, node.relativePath, children, .background))
                        queue.append(contentsOf: children.filter(\.canExpand))
                    } catch {
                        guard !Task.isCancelled, self.generation == generation else { return }
                        emit(.directoryFailed(generation, node.relativePath, .background))
                    }
                }
            }

            guard !Task.isCancelled, self.generation == generation else { return }
            emit(.preloadFinished(generation))
        }
    }

    private func cancelTasks() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        preloadTask?.cancel()
        preloadTask = nil
    }

    private func emit(_ event: WorkspaceTreeLoadEvent) {
        guard event.generation == generation else { return }
        continuation.yield(event)
    }
}
