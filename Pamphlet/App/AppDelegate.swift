import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator.shared
    private var openRecentMenu: NSMenu?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        coordinator.open(urls: urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        coordinator.open(url: URL(fileURLWithPath: filename))
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        coordinator.open(urls: filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    @objc private func openDocument(_ sender: Any?) {
        coordinator.showOpenPanel()
    }

    @objc private func showPreferences(_ sender: Any?) {
        coordinator.showPreferences()
    }

    @objc private func openRecentDocument(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        coordinator.open(url: url)
    }

    @objc private func refresh(_ sender: Any?) {
        coordinator.activeWindowController?.model.refresh()
    }

    @objc private func toggleSidebar(_ sender: Any?) {
        coordinator.activeWindowController?.model.toggleSidebar()
    }

    @objc private func toggleCSVHeaderRow(_ sender: Any?) {
        coordinator.activeWindowController?.model.toggleActiveTableHeaderRow()
    }

    @objc private func closeTabOrWindow(_ sender: Any?) {
        guard let controller = coordinator.activeWindowController else {
            NSApp.keyWindow?.close()
            return
        }
        if controller.model.hasTabs {
            controller.model.closeActiveTab()
        } else {
            controller.window?.close()
        }
    }

    @objc private func zoomIn(_ sender: Any?) {
        coordinator.activeWindowController?.model.adjustZoom(by: 0.1)
    }

    @objc private func zoomOut(_ sender: Any?) {
        coordinator.activeWindowController?.model.adjustZoom(by: -0.1)
    }

    @objc private func resetZoom(_ sender: Any?) {
        coordinator.activeWindowController?.model.resetZoom()
    }

    @objc private func nextTab(_ sender: Any?) {
        coordinator.activeWindowController?.model.selectAdjacentTab(offset: 1)
    }

    @objc private func previousTab(_ sender: Any?) {
        coordinator.activeWindowController?.model.selectAdjacentTab(offset: -1)
    }

    @objc private func findInView(_ sender: Any?) {
        coordinator.activeWindowController?.model.findInView()
    }

    // Keep the app no-nib while the shell is small. A MainMenu nib would be
    // more conventional if the menu/app chrome grows or needs visual editing.
    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem(title: "Pamphlet", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Pamphlet", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "Preferences…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        let servicesItem = appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Pamphlet", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Pamphlet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.servicesMenu = servicesMenu

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        let openRecentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let openRecentMenu = NSMenu(title: "Open Recent")
        openRecentMenu.delegate = self
        openRecentItem.submenu = openRecentMenu
        fileMenu.addItem(openRecentItem)
        self.openRecentMenu = openRecentMenu
        fileMenu.addItem(withTitle: "Refresh", action: #selector(refresh(_:)), keyEquivalent: "r")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(closeTabOrWindow(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Find", action: #selector(findInView(_:)), keyEquivalent: "f")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let viewMenu = NSMenu(title: "View")
        let toggleSidebarItem = viewMenu.addItem(withTitle: "Toggle Tree", action: #selector(toggleSidebar(_:)), keyEquivalent: "t")
        toggleSidebarItem.keyEquivalentModifierMask = [.command]
        toggleSidebarItem.target = self
        let csvHeaderRowItem = viewMenu.addItem(withTitle: "CSV header row", action: #selector(toggleCSVHeaderRow(_:)), keyEquivalent: "")
        csvHeaderRowItem.target = self
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(zoomIn(_:)), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(resetZoom(_:)), keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Previous Tab", action: #selector(previousTab(_:)), keyEquivalent: "{").keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(withTitle: "Next Tab", action: #selector(nextTab(_:)), keyEquivalent: "}").keyEquivalentModifierMask = [.command, .shift]
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Pamphlet Help", action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        return mainMenu
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === openRecentMenu else { return }
        menu.removeAllItems()

        let recentURLs = NSDocumentController.shared.recentDocumentURLs
        if recentURLs.isEmpty {
            let emptyItem = NSMenuItem(title: "No Recent Documents", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for url in recentURLs {
                let item = NSMenuItem(title: displayName(for: url), action: #selector(openRecentDocument(_:)), keyEquivalent: "")
                item.representedObject = url
                item.target = self
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        clearItem.target = NSDocumentController.shared
        menu.addItem(clearItem)
    }

    private func displayName(for url: URL) -> String {
        let path = url.path
        let displayName = FileManager.default.displayName(atPath: path)
        return displayName.isEmpty ? url.lastPathComponent : displayName
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleCSVHeaderRow(_:)):
            let model = coordinator.activeWindowController?.model
            menuItem.state = model?.activeTableUsesHeaderRow == true ? .on : .off
            return model?.canToggleActiveTableHeaderRow == true
        default:
            return true
        }
    }
}
