import SwiftUI

struct ViewPane: View {
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            if let payload = model.activePayload {
                WebRendererView(payload: payload, zoom: model.zoom, onLinkClick: model.handleLinkClick)
            }
        }
    }
}
