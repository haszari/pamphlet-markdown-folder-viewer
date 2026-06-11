import AppKit
import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    let workspaceURL: URL
    let workspaceToken: String

    @Published var sidebarVisible: Bool
    @Published var tree: [FileNode] = []
    @Published var expandedDirectories: Set<String> = []
    @Published var tabs: [ViewTab] = []
    @Published var activeTabID: UUID?
    @Published var refreshVersion = 1
    @Published var zoom = 1.0
    @Published var sidebarWidth = 280.0
    @Published var tableHeaderByPath: [String: Bool] = [:]
    @Published var theme: ResolvedTheme
    @Published var isTreeRootLoading = false
    @Published var isTreePreloading = false
    @Published var isTreeRefreshing = false

    var onWindowSubjectChanged: ((String, URL) -> Void)?
    private weak var coordinator: AppCoordinator?
    private let treeLoader: WorkspaceTreeLoader
    private var treeEventTask: Task<Void, Never>?
    private var treeGeneration: UUID?

    init(
        workspaceURL: URL,
        initialFileURL: URL?,
        sidebarVisible: Bool,
        coordinator: AppCoordinator,
        treeLoader: WorkspaceTreeLoader? = nil
    ) {
        self.workspaceURL = workspaceURL.standardizedFileURL
        self.workspaceToken = UUID().uuidString
        self.sidebarVisible = sidebarVisible
        self.coordinator = coordinator
        self.theme = ThemeStore.shared.resolveTheme(workspaceURL: self.workspaceURL, useDarkAppearance: Self.usesDarkAppearance)
        self.treeLoader = treeLoader ?? WorkspaceTreeLoader(workspaceURL: self.workspaceURL)

        WorkspaceRegistry.shared.register(token: workspaceToken, workspaceURL: self.workspaceURL)
        startTreeEventLoop()

        let initialContentURL = initialFileURL ?? findStartDocument()
        if sidebarVisible {
            startTreeLoad(priority: .userInitiated)
            if let initialContentURL {
                openFile(initialContentURL, openInNewTab: false)
            }
        } else {
            if let initialContentURL {
                openFile(initialContentURL, openInNewTab: false)
            }
            startTreeLoad(priority: .utility)
        }

        updateWindowSubject()
    }

    deinit {
        treeEventTask?.cancel()
        let treeLoader = treeLoader
        Task { @MainActor in
            treeLoader.cancel()
        }
    }

    convenience init(restorationState: WorkspaceRestorationState, coordinator: AppCoordinator) {
        self.init(
            workspaceURL: restorationState.workspaceURL,
            initialFileURL: nil,
            sidebarVisible: restorationState.sidebarVisible,
            coordinator: coordinator
        )

        expandedDirectories = restorationState.expandedDirectories
        zoom = restorationState.zoom
        resizeSidebar(to: restorationState.sidebarWidth)
        tableHeaderByPath = restorationState.tableHeaderByPath
        tabs = []
        activeTabID = nil

        for relativePath in restorationState.tabRelativePaths {
            let fileURL = workspaceURL.appendingPathComponent(relativePath)
            guard
                let mode = ViewableTypeDetector.mode(for: fileURL),
                !isTooLargeForFirstPass(fileURL, mode: mode)
            else {
                continue
            }
            tabs.append(ViewTab(fileURL: fileURL, relativePath: relativePath, mode: mode))
        }

        if let activeRelativePath = restorationState.activeRelativePath,
           let activeTab = tabs.first(where: { $0.relativePath == activeRelativePath }) {
            activeTabID = activeTab.id
        } else {
            activeTabID = tabs.first?.id
        }

        updateWindowSubject()
    }

    var hasTabs: Bool {
        !tabs.isEmpty
    }

    var activeTab: ViewTab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    var activePayload: RendererPayload? {
        guard let tab = activeTab else { return nil }
        return payload(for: tab)
    }

    func toggleSidebar() {
        sidebarVisible.toggle()
    }

    func resizeSidebar(to width: Double) {
        sidebarWidth = min(460, max(180, width))
    }

    func toggleDirectory(_ node: FileNode) {
        guard node.canExpand else { return }
        if expandedDirectories.contains(node.relativePath) {
            expandedDirectories.remove(node.relativePath)
        } else {
            expandedDirectories.insert(node.relativePath)
            if node.loadState == .unloaded || node.loadState == .failed {
                updateNode(path: node.relativePath) { node in
                    node.loadState = .loading(.foreground)
                }
                treeLoader.loadDirectory(node)
            }
        }
    }

    func activateTreeNode(_ node: FileNode, openInNewTab: Bool) {
        guard !node.isDirectory, node.isViewable else { return }
        openFile(node.url, openInNewTab: openInNewTab)
    }

    func openFile(_ fileURL: URL, openInNewTab: Bool) {
        let standardized = fileURL.standardizedFileURL
        guard
            standardized.isContained(in: workspaceURL),
            let relativePath = standardized.relativePath(from: workspaceURL),
            let mode = ViewableTypeDetector.mode(for: standardized),
            !isTooLargeForFirstPass(standardized, mode: mode)
        else {
            return
        }

        if let existing = tabs.first(where: { $0.relativePath == relativePath }) {
            activeTabID = existing.id
            updateWindowSubject()
            return
        }

        let next = ViewTab(fileURL: standardized, relativePath: relativePath, mode: mode)
        if openInNewTab || tabs.isEmpty || activeTabID == nil {
            tabs.append(next)
            activeTabID = next.id
        } else if let index = tabs.firstIndex(where: { $0.id == activeTabID }) {
            tabs[index] = next
            activeTabID = next.id
        }
        updateWindowSubject()
    }

    func closeActiveTab() {
        guard let activeTabID, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            self.activeTabID = nil
        } else {
            self.activeTabID = tabs[min(index, tabs.count - 1)].id
        }
        updateWindowSubject()
    }

    func selectTab(_ tab: ViewTab) {
        activeTabID = tab.id
        updateWindowSubject()
    }

    func selectAdjacentTab(offset: Int) {
        guard tabs.count > 1, let activeTabID, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let nextIndex = (index + offset + tabs.count) % tabs.count
        self.activeTabID = tabs[nextIndex].id
        updateWindowSubject()
    }

    func refresh() {
        refreshVersion += 1
        reloadTheme(refreshRenderer: false)
        startTreeLoad()
        updateWindowSubject()
    }

    func reloadTheme(refreshRenderer: Bool = true) {
        theme = ThemeStore.shared.resolveTheme(workspaceURL: workspaceURL, useDarkAppearance: Self.usesDarkAppearance)
        if refreshRenderer {
            refreshVersion += 1
        }
        updateWindowSubject()
    }

    func adjustZoom(by delta: Double) {
        zoom = min(2.5, max(0.5, zoom + delta))
    }

    func resetZoom() {
        zoom = 1
    }

    func findInView() {
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: nil)
    }

    var activeTableUsesHeaderRow: Bool {
        guard let activeTab else { return true }
        return tableHeaderByPath[activeTab.relativePath] ?? true
    }

    var canToggleActiveTableHeaderRow: Bool {
        guard let activeTab else { return false }
        if case .table = activeTab.mode {
            return true
        }
        return false
    }

    func toggleActiveTableHeaderRow() {
        guard let activeTab, canToggleActiveTableHeaderRow else { return }
        tableHeaderByPath[activeTab.relativePath] = !activeTableUsesHeaderRow
        refreshVersion += 1
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openWithSystem(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func cancelTreeLoading() {
        treeEventTask?.cancel()
        treeLoader.cancel()
    }

    func handleLinkClick(_ click: LinkClick) {
        if click.isExternal, let url = URL(string: click.href) {
            NSWorkspace.shared.open(url)
            return
        }

        guard let activeTab else { return }
        let targetURL: URL
        if let resolvedPath = click.resolvedPath {
            targetURL = workspaceURL.appendingPathComponent(resolvedPath)
        } else {
            targetURL = activeTab.fileURL.deletingLastPathComponent().appendingPathComponent(click.href)
        }

        let standardized = targetURL.standardizedFileURL
        guard let mode = ViewableTypeDetector.mode(for: standardized), !isTooLargeForFirstPass(standardized, mode: mode) else {
            return
        }

        if standardized.isContained(in: workspaceURL) {
            openFile(standardized, openInNewTab: click.metaKey)
        } else {
            coordinator?.openWorkspace(
                folderURL: standardized.deletingLastPathComponent(),
                initialFileURL: standardized,
                sidebarVisible: false,
                recentURL: standardized
            )
        }
    }

    func updateWindowSubject() {
        let workspaceTitle = theme.workspaceTitle ?? workspaceURL.lastPathComponent
        if let activeTab {
            onWindowSubjectChanged?("\(workspaceTitle) - \(activeTab.title)", activeTab.fileURL)
        } else {
            onWindowSubjectChanged?(workspaceTitle, workspaceURL)
        }
    }

    private func findStartDocument() -> URL? {
        let candidates = ["readme.md", "readme.markdown", "index.md", "index.markdown"]
        for candidate in candidates {
            let url = workspaceURL.appendingPathComponent(candidate)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                return url
            }
        }
        return nil
    }

    private func payload(for tab: ViewTab) -> RendererPayload? {
        switch tab.mode {
        case .markdown:
            guard let content = readUTF8(tab.fileURL) else { return nil }
            return basePayload(tab: tab, mode: "markdown", content: content)
        case .text(let language), .code(let language):
            guard let content = readUTF8(tab.fileURL) else { return nil }
            return basePayload(tab: tab, mode: tab.mode.rendererMode, content: content, language: language)
        case .table(let delimiter):
            guard let content = readUTF8(tab.fileURL) else { return nil }
            return basePayload(
                tab: tab,
                mode: "table",
                content: content,
                table: RendererPayload.TableOptions(
                    delimiter: delimiter,
                    firstRowHeader: tableHeaderByPath[tab.relativePath] ?? true
                )
            )
        case .image:
            return basePayload(tab: tab, mode: "image", imageUrl: tab.relativePath)
        }
    }

    private func basePayload(
        tab: ViewTab,
        mode: String,
        content: String? = nil,
        language: String? = nil,
        imageUrl: String? = nil,
        table: RendererPayload.TableOptions? = nil
    ) -> RendererPayload {
        RendererPayload(
            mode: mode,
            content: content,
            language: language,
            imageUrl: imageUrl,
            fileName: tab.title,
            filePath: tab.relativePath,
            workspaceToken: workspaceToken,
            refreshVersion: refreshVersion,
            table: table,
            theme: theme.rendererPayload
        )
    }

    private func readUTF8(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: Data(data.dropFirst(3)), encoding: .utf8)
        }
        return String(data: data, encoding: .utf8)
    }

    private func startTreeEventLoop() {
        treeEventTask?.cancel()
        treeEventTask = Task { [weak self] in
            guard let self else { return }
            for await event in treeLoader.events {
                applyTreeEvent(event)
            }
        }
    }

    private func startTreeLoad(priority: TaskPriority = .userInitiated) {
        treeLoader.refresh(priority: priority)
    }

    private func applyTreeEvent(_ event: WorkspaceTreeLoadEvent) {
        switch event {
        case .rootLoading(let generation):
            treeGeneration = generation
            if tree.isEmpty {
                isTreeRootLoading = true
            } else {
                isTreeRefreshing = true
            }
            isTreePreloading = false
        case .rootLoaded(let generation, let children):
            guard generation == treeGeneration else { return }
            tree = children
            expandedDirectories = expandedDirectories.filter { path in
                path.contains("/") || containsNode(path: path, in: tree)
            }
            isTreeRootLoading = false
            isTreeRefreshing = false
            loadRestoredExpandedDirectories(in: tree)
        case .directoryLoading(let generation, let path, let reason):
            guard generation == treeGeneration else { return }
            updateNode(path: path) { node in
                node.loadState = .loading(reason)
            }
        case .directoryLoaded(let generation, let path, let children, _):
            guard generation == treeGeneration else { return }
            updateNode(path: path) { node in
                node.children = children
                node.loadState = .loaded
            }
            loadRestoredExpandedDirectories(in: children)
        case .directoryFailed(let generation, let path, _):
            guard generation == treeGeneration else { return }
            updateNode(path: path) { node in
                node.loadState = .failed
            }
        case .preloadStarted(let generation):
            guard generation == treeGeneration else { return }
            isTreePreloading = true
        case .preloadFinished(let generation):
            guard generation == treeGeneration else { return }
            isTreePreloading = false
        }
    }

    private func loadRestoredExpandedDirectories(in nodes: [FileNode]) {
        for node in nodes where expandedDirectories.contains(node.relativePath) {
            guard node.loadState == .unloaded || node.loadState == .failed else { continue }
            updateNode(path: node.relativePath) { node in
                node.loadState = .loading(.foreground)
            }
            treeLoader.loadDirectory(node)
        }
    }

    private func updateNode(path: String, update: (inout FileNode) -> Void) {
        updateNode(path: path, nodes: &tree, update: update)
    }

    private func updateNode(path: String, nodes: inout [FileNode], update: (inout FileNode) -> Void) {
        for index in nodes.indices {
            if nodes[index].relativePath == path {
                update(&nodes[index])
                return
            }
            updateNode(path: path, nodes: &nodes[index].children, update: update)
        }
    }

    private func containsNode(path: String, in nodes: [FileNode]) -> Bool {
        for node in nodes {
            if node.relativePath == path || containsNode(path: path, in: node.children) {
                return true
            }
        }
        return false
    }

    private func isTooLargeForFirstPass(_ url: URL, mode: ViewMode) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize else {
            return false
        }
        switch mode {
        case .image:
            return size > 50 * 1024 * 1024
        case .table:
            return size > 10 * 1024 * 1024
        case .markdown, .text, .code:
            return size > 5 * 1024 * 1024
        }
    }

    private static var usesDarkAppearance: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
