import SwiftUI

struct ViewPane: View {
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        ZStack {
            Color(nsColor: model.theme.colors.background.nsColor)
            if let payload = model.activePayload {
                WebRendererView(payload: payload, zoom: model.zoom, onLinkClick: model.handleLinkClick)
            }
        }
        .themeBadgeOverlay(model.theme.badge?.anchor == .content ? model.theme.badge : nil)
    }
}
