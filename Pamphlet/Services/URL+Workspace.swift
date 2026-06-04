import Foundation

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    func isContained(in directory: URL) -> Bool {
        let filePath = standardizedFileURL.path
        let directoryPath = directory.standardizedFileURL.path
        return filePath == directoryPath || filePath.hasPrefix(directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/")
    }

    func relativePath(from directory: URL) -> String? {
        let filePath = standardizedFileURL.path
        let directoryPath = directory.standardizedFileURL.path
        guard filePath.isContainedPath(in: directoryPath) else { return nil }
        if filePath == directoryPath { return "" }
        let prefix = directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"
        return String(filePath.dropFirst(prefix.count))
    }
}

private extension String {
    func isContainedPath(in directoryPath: String) -> Bool {
        self == directoryPath || self.hasPrefix(directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/")
    }
}
