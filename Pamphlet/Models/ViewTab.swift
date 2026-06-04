import Foundation

struct ViewTab: Identifiable, Equatable {
    let id: UUID
    var fileURL: URL
    var relativePath: String
    var mode: ViewMode
    var title: String
    var scrollPosition: Double

    init(fileURL: URL, relativePath: String, mode: ViewMode) {
        self.id = UUID()
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.mode = mode
        self.title = fileURL.lastPathComponent
        self.scrollPosition = 0
    }
}
