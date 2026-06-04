import Foundation

struct FileNode: Identifiable, Equatable {
    let id: String
    let url: URL
    let relativePath: String
    let name: String
    let isDirectory: Bool
    let isViewable: Bool
    var children: [FileNode]

    var systemImageName: String {
        if isDirectory { return "folder" }
        return isViewable ? "doc.text" : "doc"
    }
}
