import Foundation

@MainActor
final class WorkspaceRegistry {
    static let shared = WorkspaceRegistry()
    private var workspaces: [String: URL] = [:]

    private init() {}

    func register(token: String, workspaceURL: URL) {
        workspaces[token] = workspaceURL.standardizedFileURL
    }

    func workspaceURL(for token: String) -> URL? {
        workspaces[token]
    }
}
