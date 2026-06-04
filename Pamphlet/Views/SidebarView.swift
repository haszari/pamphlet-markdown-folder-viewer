import AppKit
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.tree) { node in
                    FileNodeRow(model: model, node: node, depth: 0)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct FileNodeRow: View {
    @ObservedObject var model: WorkspaceViewModel
    let node: FileNode
    let depth: Int

    private var isExpanded: Bool {
        model.expandedDirectories.contains(node.relativePath)
    }

    private var isSelected: Bool {
        model.activeTab?.relativePath == node.relativePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if node.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Color.clear.frame(width: 12)
                }

                Image(systemName: node.systemImageName)
                    .foregroundStyle(iconStyle)
                    .frame(width: 16)

                Text(node.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(textStyle)

                Spacer(minLength: 0)
            }
            .font(.system(size: 13))
            .padding(.leading, CGFloat(depth) * 16 + 8)
            .padding(.trailing, 8)
            .frame(height: 24)
            .background(rowBackground)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    model.toggleDirectory(node)
                } else {
                    model.activateTreeNode(node, openInNewTab: NSEvent.modifierFlags.contains(.command))
                }
            }
            .onTapGesture(count: 2) {
                if !node.isDirectory && !node.isViewable {
                    model.openWithSystem(node.url)
                }
            }
            .contextMenu {
                Button("Reveal in Finder") {
                    model.revealInFinder(node.url)
                }
                if !node.isDirectory {
                    Button("Open with System App") {
                        model.openWithSystem(node.url)
                    }
                }
            }

            if node.isDirectory && isExpanded {
                ForEach(node.children) { child in
                    FileNodeRow(model: model, node: child, depth: depth + 1)
                }
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isSelected ? Color(nsColor: .separatorColor).opacity(0.35) : Color.clear)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
    }

    private var iconStyle: HierarchicalShapeStyle {
        if isSelected {
            return .primary
        }
        return node.isViewable || node.isDirectory ? .primary : .secondary
    }

    private var textStyle: HierarchicalShapeStyle {
        if isSelected {
            return .primary
        }
        return node.isViewable || node.isDirectory ? .primary : .secondary
    }
}
