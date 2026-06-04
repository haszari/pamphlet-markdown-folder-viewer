import SwiftUI
import WebKit

struct WebRendererView: NSViewRepresentable {
    let payload: RendererPayload
    let zoom: Double
    let onLinkClick: (LinkClick) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkClick: onLinkClick)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "linkClick")
        configuration.setURLSchemeHandler(WorkspaceURLSchemeHandler(), forURLScheme: "pamphlet-file")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.pageZoom = zoom
        let themeKey = payload.theme.variables
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "|")
        let key = "\(payload.filePath)|\(payload.refreshVersion)|\(payload.mode)|\(payload.content?.hashValue ?? 0)|\(payload.imageUrl ?? "")|\(payload.theme.appCSS.hashValue)|\(payload.theme.workspaceCSS.hashValue)|\(themeKey.hashValue)"
        guard context.coordinator.lastRenderKey != key else { return }
        context.coordinator.lastRenderKey = key
        webView.loadHTMLString(makeHTML(payload: payload), baseURL: Bundle.main.resourceURL)
    }

    private func makeHTML(payload: RendererPayload) -> String {
        do {
            let assets = try RendererAssets.load()
            let data = try JSONEncoder().encode(payload)
            let encoded = data.base64EncodedString()
            return """
            <!doctype html>
            <html>
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style>\(assets.stylesheet)</style>
            </head>
            <body>
              <div id="root"></div>
              <script>\(assets.script)</script>
              <script>
                window.Pamphlet.render(JSON.parse(atob("\(encoded)")));
              </script>
            </body>
            </html>
            """
        } catch {
            return """
            <!doctype html>
            <html>
            <body style="font: 13px -apple-system; padding: 24px;">
              <p>\(escapeHTML(error.localizedDescription))</p>
            </body>
            </html>
            """
        }
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastRenderKey: String?
        private let onLinkClick: (LinkClick) -> Void

        init(onLinkClick: @escaping (LinkClick) -> Void) {
            self.onLinkClick = onLinkClick
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                message.name == "linkClick",
                let object = message.body as? [String: Any],
                let data = try? JSONSerialization.data(withJSONObject: object),
                let click = try? JSONDecoder().decode(LinkClick.self, from: data)
            else {
                return
            }
            onLinkClick(click)
        }
    }
}
