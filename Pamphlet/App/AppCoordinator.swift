import AppKit

@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private var controllers: [WorkspaceWindowController] = []

    var activeWindowController: WorkspaceWindowController? {
        NSApp.keyWindow?.windowController as? WorkspaceWindowController
    }

    func showOpenPanel() {
        showOpenPanel(canChooseFiles: true, canChooseDirectories: true)
    }

    private func showOpenPanel(canChooseFiles: Bool = true, canChooseDirectories: Bool = true) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = canChooseDirectories
        panel.canChooseFiles = canChooseFiles
        panel.resolvesAliases = true

        if panel.runModal() == .OK, let url = panel.url {
            open(urls: [url])
        }
    }

    func open(urls: [URL]) {
        for url in urls {
            open(url: url)
        }
    }

    func open(url: URL) {
        let standardized = url.standardizedFileURL
        if standardized.isDirectory {
            noteRecent(standardized)
            openWorkspace(folderURL: standardized, initialFileURL: nil, sidebarVisible: true)
            return
        }

        guard ViewableTypeDetector.mode(for: standardized) != nil else {
            return
        }

        noteRecent(standardized)
        openWorkspace(folderURL: standardized.deletingLastPathComponent(), initialFileURL: standardized, sidebarVisible: false)
    }

    func openWorkspace(folderURL: URL, initialFileURL: URL?, sidebarVisible: Bool, recentURL: URL? = nil) {
        if let recentURL {
            noteRecent(recentURL.standardizedFileURL)
        }
        let controller = WorkspaceWindowController(
            workspaceURL: folderURL,
            initialFileURL: initialFileURL,
            sidebarVisible: sidebarVisible,
            coordinator: self
        )
        retainAndShow(controller)
    }

    func restoreWorkspace(state: WorkspaceRestorationState) -> NSWindow? {
        let controller = WorkspaceWindowController(restorationState: state, coordinator: self)
        retainAndShow(controller)
        return controller.window
    }

    func release(_ controller: WorkspaceWindowController) {
        controllers.removeAll { $0 === controller }
    }

    private func retainAndShow(_ controller: WorkspaceWindowController) {
        controllers.append(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func noteRecent(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }
}
