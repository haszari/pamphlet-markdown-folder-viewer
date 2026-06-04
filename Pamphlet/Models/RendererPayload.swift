import Foundation

struct RendererPayload: Codable, Equatable {
    struct ThemePayload: Codable, Equatable {
        let variables: [String: String]
        let appCSS: String
        let workspaceCSS: String
        let appearance: String
    }

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
    let theme: ThemePayload
}

struct LinkClick: Decodable {
    let href: String
    let isExternal: Bool
    let isWorkspaceLocal: Bool
    let resolvedPath: String?
    let metaKey: Bool
}
