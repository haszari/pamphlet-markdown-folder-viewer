import Foundation
import UniformTypeIdentifiers

enum ViewableTypeDetector {
    private static let markdownExtensions = Set(["md", "markdown"])
    private static let csvExtensions = Set(["csv"])
    private static let tsvExtensions = Set(["tsv", "tab"])
    private static let targetedTextNames = Set(["makefile", "dockerfile"])
    private static let targetedDotfiles = Set([".gitignore", ".env"])

    static func mode(for url: URL) -> ViewMode? {
        guard !url.isDirectory else { return nil }

        let name = url.lastPathComponent
        let lowerName = name.lowercased()
        let ext = url.pathExtension.lowercased()

        if markdownExtensions.contains(ext) {
            return .markdown
        }
        if csvExtensions.contains(ext) {
            return .table(delimiter: ",")
        }
        if tsvExtensions.contains(ext) {
            return .table(delimiter: "\t")
        }
        if ext == "svg" {
            return .code(language: "xml")
        }
        if let imageType = UTType(filenameExtension: ext), imageType.conforms(to: .image) {
            return .image
        }
        if targetedTextNames.contains(lowerName) || targetedDotfiles.contains(lowerName) {
            return .text(language: language(forExtension: ext, fileName: lowerName))
        }
        if let language = language(forExtension: ext, fileName: lowerName) {
            return .code(language: language)
        }
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .html) {
                return .code(language: "html")
            }
            if type.conforms(to: .sourceCode) {
                return .code(language: language(forExtension: ext, fileName: lowerName))
            }
            if type.conforms(to: .text) || type.conforms(to: .json) || type.conforms(to: .xml) {
                return .text(language: language(forExtension: ext, fileName: lowerName))
            }
        }

        if ext.isEmpty || lowerName.hasPrefix(".") {
            return looksLikeUTF8Text(url) ? .text(language: nil) : nil
        }

        return nil
    }

    static func isViewable(_ url: URL) -> Bool {
        mode(for: url) != nil
    }

    private static func looksLikeUTF8Text(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 4096)) ?? Data()
        guard !data.contains(0) else { return false }
        return String(data: data, encoding: .utf8) != nil
    }

    private static func language(forExtension ext: String, fileName: String) -> String? {
        if fileName == "makefile" { return "makefile" }
        if fileName == "dockerfile" { return "dockerfile" }
        switch ext {
        case "js", "mjs", "cjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "jsx": return "javascript"
        case "swift": return "swift"
        case "py": return "python"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "cs": return "csharp"
        case "sh", "bash", "zsh": return "bash"
        case "fish": return "fish"
        case "sql": return "sql"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "xml", "svg": return "xml"
        case "html", "htm": return "html"
        case "css": return "css"
        case "toml": return "toml"
        case "ini", "env": return "ini"
        case "md", "markdown": return "markdown"
        default: return nil
        }
    }
}
