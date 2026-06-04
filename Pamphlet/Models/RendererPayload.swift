import Foundation

struct RendererPayload: Codable, Equatable {
    struct TableOptions: Codable, Equatable {
        let delimiter: String
        let firstRowHeader: Bool
    }

    let mode: String
    let content: String?
    let language: String?
    let imageUrl: String?
    let fileName: String
    let filePath: String
    let workspaceToken: String
    let refreshVersion: Int
    let table: TableOptions?
}

struct LinkClick: Decodable {
    let href: String
    let isExternal: Bool
    let isWorkspaceLocal: Bool
    let resolvedPath: String?
    let metaKey: Bool
}
