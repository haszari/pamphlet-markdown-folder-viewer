import Foundation

enum RendererAssets {
    struct BundleAssets {
        let script: String
        let stylesheet: String
    }

    static func load() throws -> BundleAssets {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw RendererAssetError.missingResourceDirectory
        }

        let rendererURL = resourceURL.appendingPathComponent("Renderer", isDirectory: true)
        let scriptURL = rendererURL.appendingPathComponent("renderer.js")
        let stylesheetURL = rendererURL.appendingPathComponent("renderer.css")

        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw RendererAssetError.missingFile(scriptURL.path)
        }
        guard FileManager.default.fileExists(atPath: stylesheetURL.path) else {
            throw RendererAssetError.missingFile(stylesheetURL.path)
        }

        return BundleAssets(
            script: try String(contentsOf: scriptURL, encoding: .utf8),
            stylesheet: try String(contentsOf: stylesheetURL, encoding: .utf8)
        )
    }
}

enum RendererAssetError: LocalizedError {
    case missingResourceDirectory
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingResourceDirectory:
            return "Renderer assets are missing. Build the renderer package before running the app."
        case .missingFile(let path):
            return "Renderer asset missing at \(path). Build the renderer package before running the app."
        }
    }
}
