import Foundation

enum FileNodeLoadReason: Equatable, Sendable {
    case root
    case foreground
    case background
    case refresh
}

enum FileNodeLoadState: Equatable, Sendable {
    case file
    case unloaded
    case loading(FileNodeLoadReason)
    case loaded
    case ignored
    case failed
}

struct FileNode: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let relativePath: String
    let name: String
    let isDirectory: Bool
    let isViewable: Bool
    var loadState: FileNodeLoadState
    var children: [FileNode]

    init(
        id: String,
        url: URL,
        relativePath: String,
        name: String,
        isDirectory: Bool,
        isViewable: Bool,
        loadState: FileNodeLoadState? = nil,
        children: [FileNode]
    ) {
        self.id = id
        self.url = url
        self.relativePath = relativePath
        self.name = name
        self.isDirectory = isDirectory
        self.isViewable = isViewable
        self.loadState = loadState ?? (isDirectory ? .unloaded : .file)
        self.children = children
    }

    var canExpand: Bool {
        isDirectory && loadState != .ignored
    }

    var systemImageName: String {
        if isDirectory { return "folder" }
        return isViewable ? "doc.text" : "doc"
    }
}
