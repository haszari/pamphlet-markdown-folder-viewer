import AppKit
import Combine
import SwiftUI

struct WorkspaceRestorationState {
    let workspaceURL: URL
    let tabRelativePaths: [String]
    let activeRelativePath: String?
    let sidebarVisible: Bool
    let sidebarWidth: Double
    let expandedDirectories: Set<String>
    let zoom: Double
    let tableHeaderByPath: [String: Bool]
}

@MainActor
final class WorkspaceWindowController: NSWindowController, NSWindowDelegate, NSWindowRestoration {
    fileprivate enum RestorationKey {
        static let windowIdentifier = NSUserInterfaceItemIdentifier("WorkspaceWindow")
        static let workspaceURL = "workspaceURL"
        static let tabRelativePaths = "tabRelativePaths"
        static let activeRelativePath = "activeRelativePath"
        static let sidebarVisible = "sidebarVisible"
        static let sidebarWidth = "sidebarWidth"
        static let expandedDirectories = "expandedDirectories"
        static let zoom = "zoom"
        static let tableHeaderByPath = "tableHeaderByPath"
    }

    let model: WorkspaceViewModel
    private weak var coordinator: AppCoordinator?
    private var stateObserver: AnyCancellable?

    init(workspaceURL: URL, initialFileURL: URL?, sidebarVisible: Bool, coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.model = WorkspaceViewModel(
            workspaceURL: workspaceURL,
            initialFileURL: initialFileURL,
            sidebarVisible: sidebarVisible,
            coordinator: coordinator
        )
        super.init(window: Self.makeWindow(model: model))
        configureWindow()
    }

    init(restorationState: WorkspaceRestorationState, coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.model = WorkspaceViewModel(restorationState: restorationState, coordinator: coordinator)
        super.init(window: Self.makeWindow(model: model))
        configureWindow()
    }

    private static func makeWindow(model: WorkspaceViewModel) -> NSWindow {
        let rootView = WorkspaceView(model: model)
        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.minSize = NSSize(width: 760, height: 460)
        window.tabbingMode = .disallowed
        window.identifier = RestorationKey.windowIdentifier
        window.isRestorable = true
        window.restorationClass = WorkspaceWindowController.self
        return window
    }

    private func configureWindow() {
        window?.delegate = self

        model.onWindowSubjectChanged = { [weak self] title, representedURL in
            self?.window?.title = title
            self?.window?.representedURL = representedURL
        }
        stateObserver = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.window?.invalidateRestorableState()
            }
        }
        model.updateWindowSubject()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        coordinator?.release(self)
    }

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        state.encode(model.workspaceURL as NSURL, forKey: RestorationKey.workspaceURL)
        state.encode(model.tabs.map(\.relativePath) as NSArray, forKey: RestorationKey.tabRelativePaths)
        if let activeRelativePath = model.activeTab?.relativePath {
            state.encode(activeRelativePath as NSString, forKey: RestorationKey.activeRelativePath)
        }
        state.encode(model.sidebarVisible, forKey: RestorationKey.sidebarVisible)
        state.encode(model.sidebarWidth, forKey: RestorationKey.sidebarWidth)
        state.encode(Array(model.expandedDirectories) as NSArray, forKey: RestorationKey.expandedDirectories)
        state.encode(model.zoom, forKey: RestorationKey.zoom)
        state.encode(model.tableHeaderByPath as NSDictionary, forKey: RestorationKey.tableHeaderByPath)
    }

    static func restoreWindow(
        withIdentifier identifier: NSUserInterfaceItemIdentifier,
        state: NSCoder,
        completionHandler: @escaping (NSWindow?, Error?) -> Void
    ) {
        guard identifier == RestorationKey.windowIdentifier,
              let restorationState = WorkspaceRestorationState(state: state)
        else {
            completionHandler(nil, nil)
            return
        }

        completionHandler(AppCoordinator.shared.restoreWorkspace(state: restorationState), nil)
    }
}

private extension WorkspaceRestorationState {
    init?(state: NSCoder) {
        guard let workspaceNSURL = state.decodeObject(of: NSURL.self, forKey: WorkspaceWindowController.RestorationKey.workspaceURL) else {
            return nil
        }
        let workspaceURL = workspaceNSURL as URL

        let tabRelativePaths = Self.decodeStringArray(
            state.decodeObject(
                of: [NSArray.self, NSString.self],
                forKey: WorkspaceWindowController.RestorationKey.tabRelativePaths
            )
        )

        let activeRelativePath = state.decodeObject(
            of: NSString.self,
            forKey: WorkspaceWindowController.RestorationKey.activeRelativePath
        ) as String?

        let expandedDirectories = Self.decodeStringArray(
            state.decodeObject(
                of: [NSArray.self, NSString.self],
                forKey: WorkspaceWindowController.RestorationKey.expandedDirectories
            )
        )

        let tableHeaderByPath = Self.decodeBoolDictionary(
            state.decodeObject(
                of: [NSDictionary.self, NSString.self, NSNumber.self],
                forKey: WorkspaceWindowController.RestorationKey.tableHeaderByPath
            )
        )

        self.workspaceURL = workspaceURL.standardizedFileURL
        self.tabRelativePaths = tabRelativePaths
        self.activeRelativePath = activeRelativePath
        self.sidebarVisible = state.decodeBool(forKey: WorkspaceWindowController.RestorationKey.sidebarVisible)
        self.sidebarWidth = state.containsValue(forKey: WorkspaceWindowController.RestorationKey.sidebarWidth)
            ? state.decodeDouble(forKey: WorkspaceWindowController.RestorationKey.sidebarWidth)
            : 280
        self.expandedDirectories = Set(expandedDirectories)
        self.zoom = state.containsValue(forKey: WorkspaceWindowController.RestorationKey.zoom)
            ? state.decodeDouble(forKey: WorkspaceWindowController.RestorationKey.zoom)
            : 1
        self.tableHeaderByPath = tableHeaderByPath
    }

    private static func decodeStringArray(_ value: Any?) -> [String] {
        guard let values = value as? [Any] else { return [] }
        return values.compactMap { $0 as? String }
    }

    private static func decodeBoolDictionary(_ value: Any?) -> [String: Bool] {
        guard let values = value as? [AnyHashable: Any] else { return [:] }
        var result: [String: Bool] = [:]
        for (key, value) in values {
            guard let key = key as? String else { continue }
            if let value = value as? Bool {
                result[key] = value
            } else if let value = value as? NSNumber {
                result[key] = value.boolValue
            }
        }
        return result
    }
}
