import Foundation
import UniformTypeIdentifiers
import WebKit

final class WorkspaceURLSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard
            let url = urlSchemeTask.request.url,
            let host = url.host?.removingPercentEncoding
        else {
            fail(urlSchemeTask)
            return
        }

        Task { @MainActor in
            guard let workspaceURL = WorkspaceRegistry.shared.workspaceURL(for: host) else {
                self.fail(urlSchemeTask)
                return
            }

            let relativePath = String(url.path.dropFirst()).removingPercentEncoding ?? ""
            let fileURL = workspaceURL.appendingPathComponent(relativePath).standardizedFileURL
            guard fileURL.isContained(in: workspaceURL), !fileURL.isDirectory else {
                self.fail(urlSchemeTask)
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let response = URLResponse(
                    url: url,
                    mimeType: Self.mimeType(for: fileURL),
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } catch {
                self.fail(urlSchemeTask)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func fail(_ task: WKURLSchemeTask) {
        task.didFailWithError(NSError(domain: "Pamphlet.WorkspaceURLSchemeHandler", code: 404))
    }

    private static func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension), let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}
