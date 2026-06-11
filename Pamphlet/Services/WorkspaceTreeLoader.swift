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

protocol DirectoryScanning: Sendable {
    func scanChildren(
        of folderURL: URL,
        relativePath: String,
        ignorePolicy: WorkspaceTreeIgnorePolicy,
        priority: TaskPriority
    ) async throws -> [FileNode]
}

struct FileManagerDirectoryScanner: DirectoryScanning, Sendable {
    func scanChildren(
        of folderURL: URL,
        relativePath: String,
        ignorePolicy: WorkspaceTreeIgnorePolicy,
        priority: TaskPriority
    ) async throws -> [FileNode] {
        try await Task.detached(priority: priority) {
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
            let isSymlink = values?.isSymbolicLink == true
            let isDirectory = values?.isDirectory == true || (isSymlink && Self.symlinkTargetsDirectory(url))
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

    nonisolated private static func symlinkTargetsDirectory(_ url: URL) -> Bool {
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) else {
            return false
        }
        let targetURL: URL
        if destination.hasPrefix("/") {
            targetURL = URL(fileURLWithPath: destination)
        } else {
            targetURL = url.deletingLastPathComponent().appendingPathComponent(destination)
        }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
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
    private var preloadQueue: [FileNode] = []
    private var queuedPreloadPaths: Set<String> = []
    private var activeScans: [String: FileNodeLoadReason] = [:]
    private var loadedPaths: Set<String> = []
    private var foregroundPromotions: Set<String> = []

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

    func start(priority: TaskPriority = .userInitiated) {
        cancelTasks()
        generation = UUID()
        let activeGeneration = generation
        emit(.rootLoading(activeGeneration))
        loadRoot(generation: activeGeneration, priority: priority)
    }

    func refresh(priority: TaskPriority = .userInitiated) {
        start(priority: priority)
    }

    func loadDirectory(_ node: FileNode, reason: FileNodeLoadReason = .foreground) {
        guard node.canExpand else { return }
        loadDirectory(url: node.url, relativePath: node.relativePath, generation: generation, reason: reason)
    }

    func cancel() {
        cancelTasks()
        generation = UUID()
    }

    private func loadRoot(generation: UUID, priority: TaskPriority) {
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let children = try await scanner.scanChildren(
                    of: workspaceURL,
                    relativePath: "",
                    ignorePolicy: ignorePolicy,
                    priority: priority
                )
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
        guard !loadedPaths.contains(relativePath) else { return }
        if activeScans[relativePath] != nil {
            if reason == .foreground {
                foregroundPromotions.insert(relativePath)
                emit(.directoryLoading(generation, relativePath, .foreground))
            }
            return
        }
        startDirectoryScan(url: url, relativePath: relativePath, generation: generation, reason: reason)
    }

    private func startDirectoryScan(url: URL, relativePath: String, generation: UUID, reason: FileNodeLoadReason) {
        emit(.directoryLoading(generation, relativePath, reason))
        activeScans[relativePath] = reason
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let children = try await scanner.scanChildren(
                    of: url,
                    relativePath: relativePath,
                    ignorePolicy: ignorePolicy,
                    priority: Self.scanPriority(for: reason)
                )
                guard !Task.isCancelled, self.generation == generation else { return }
                let effectiveReason = foregroundPromotions.remove(relativePath) != nil ? .foreground : reason
                activeScans.removeValue(forKey: relativePath)
                loadedPaths.insert(relativePath)
                emit(.directoryLoaded(generation, relativePath, children, effectiveReason))
                enqueuePreload(children)
            } catch {
                guard !Task.isCancelled, self.generation == generation else { return }
                let effectiveReason = foregroundPromotions.remove(relativePath) != nil ? .foreground : reason
                activeScans.removeValue(forKey: relativePath)
                emit(.directoryFailed(generation, relativePath, effectiveReason))
            }
            tasks.removeValue(forKey: relativePath)
        }
        tasks[relativePath] = task
    }

    private func startPreload(children: [FileNode], generation: UUID) {
        preloadTask?.cancel()
        preloadQueue = []
        queuedPreloadPaths = []
        enqueuePreload(children)
        preloadTask = Task { [weak self] in
            guard let self else { return }
            emit(.preloadStarted(generation))

            while true {
                guard !Task.isCancelled, self.generation == generation else { return }
                startQueuedPreloadScans(generation: generation)
                if preloadQueue.isEmpty && activeScans.isEmpty {
                    break
                }
                try? await Task.sleep(for: .milliseconds(20))
            }

            guard !Task.isCancelled, self.generation == generation else { return }
            emit(.preloadFinished(generation))
        }
    }

    private func enqueuePreload(_ nodes: [FileNode]) {
        for node in nodes where node.canExpand && !loadedPaths.contains(node.relativePath) {
            guard !queuedPreloadPaths.contains(node.relativePath) else { continue }
            queuedPreloadPaths.insert(node.relativePath)
            preloadQueue.append(node)
        }
    }

    private func startQueuedPreloadScans(generation: UUID) {
        while activeScans.count < maxConcurrentScans && !preloadQueue.isEmpty {
            let node = preloadQueue.removeFirst()
            queuedPreloadPaths.remove(node.relativePath)
            guard !loadedPaths.contains(node.relativePath), activeScans[node.relativePath] == nil else {
                continue
            }
            startDirectoryScan(url: node.url, relativePath: node.relativePath, generation: generation, reason: .background)
        }
    }

    private static func scanPriority(for reason: FileNodeLoadReason) -> TaskPriority {
        reason == .foreground ? .userInitiated : .utility
    }

    private func cancelTasks() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        preloadTask?.cancel()
        preloadTask = nil
        preloadQueue = []
        queuedPreloadPaths = []
        activeScans = [:]
        loadedPaths = []
        foregroundPromotions = []
    }

    private func emit(_ event: WorkspaceTreeLoadEvent) {
        guard event.generation == generation else { return }
        continuation.yield(event)
    }
}
