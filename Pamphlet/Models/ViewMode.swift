import Foundation

enum ViewMode: Equatable {
    case markdown
    case text(language: String?)
    case code(language: String?)
    case table(delimiter: String)
    case image

    var rendererMode: String {
        switch self {
        case .markdown: "markdown"
        case .text: "text"
        case .code: "code"
        case .table: "table"
        case .image: "image"
        }
    }

    var language: String? {
        switch self {
        case .text(let language), .code(let language):
            language
        default:
            nil
        }
    }
}
