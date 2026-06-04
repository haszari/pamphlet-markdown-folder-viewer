import AppKit
import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if model.sidebarVisible {
                WorkspaceSplitView(model: model)
            } else {
                WorkspaceContentView(model: model)
            }
        }
        .background(Color(nsColor: model.theme.colors.windowBackground.nsColor))
        .themeBadgeOverlay(model.theme.badge?.anchor == .window ? model.theme.badge : nil)
        .frame(minWidth: 760, minHeight: 460)
        .onChange(of: colorScheme) { _, _ in
            model.reloadTheme()
        }
    }
}

private struct WorkspaceContentView: View {
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.tabs.count >= 2 {
                TabStripView(model: model)
                Divider()
            }
            ViewPane(model: model)
        }
        .background(Color(nsColor: model.theme.colors.windowBackground.nsColor))
    }
}

private struct WorkspaceSplitView: NSViewRepresentable {
    @ObservedObject var model: WorkspaceViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        let sidebarView = NSHostingView(rootView: SidebarView(model: model))
        let contentView = NSHostingView(rootView: WorkspaceContentView(model: model))
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        splitView.addArrangedSubview(sidebarView)
        splitView.addArrangedSubview(contentView)
        context.coordinator.sidebarView = sidebarView
        context.coordinator.contentView = contentView

        DispatchQueue.main.async {
            context.coordinator.applySidebarWidthIfPossible(to: splitView)
        }
        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.model = model
        context.coordinator.sidebarView?.rootView = SidebarView(model: model)
        context.coordinator.contentView?.rootView = WorkspaceContentView(model: model)

        let currentWidth = Double(splitView.arrangedSubviews.first?.frame.width ?? CGFloat(model.sidebarWidth))
        if !context.coordinator.isResizing && abs(currentWidth - model.sidebarWidth) > 0.5 {
            context.coordinator.applySidebarWidthIfPossible(to: splitView)
        }
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var model: WorkspaceViewModel
        var sidebarView: NSHostingView<SidebarView>?
        var contentView: NSHostingView<WorkspaceContentView>?
        var isResizing = false
        private var isApplyingSidebarWidth = false
        private var hasAppliedInitialSidebarWidth = false

        init(model: WorkspaceViewModel) {
            self.model = model
        }

        @MainActor
        @discardableResult
        func applySidebarWidthIfPossible(to splitView: NSSplitView) -> Bool {
            guard splitView.bounds.width > 0 else { return false }
            isApplyingSidebarWidth = true
            hasAppliedInitialSidebarWidth = true
            splitView.setPosition(model.sidebarWidth, ofDividerAt: 0)
            DispatchQueue.main.async { [weak self] in
                self?.isApplyingSidebarWidth = false
            }
            return true
        }

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            180
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            min(460, splitView.bounds.width - 320)
        }

        func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
            view === contentView
        }

        func splitViewWillResizeSubviews(_ notification: Notification) {
            isResizing = true
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard !isApplyingSidebarWidth else {
                isResizing = false
                return
            }
            guard
                let splitView = notification.object as? NSSplitView,
                let sidebarWidth = splitView.arrangedSubviews.first?.frame.width
            else {
                return
            }
            if !hasAppliedInitialSidebarWidth {
                applySidebarWidthIfPossible(to: splitView)
                return
            }

            model.resizeSidebar(to: sidebarWidth)
            isResizing = false
        }
    }
}
