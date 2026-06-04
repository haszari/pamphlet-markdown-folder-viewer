import SwiftUI

struct TabStripView: View {
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.tabs) { tab in
                    Button {
                        model.selectTab(tab)
                    } label: {
                        HStack(spacing: 6) {
                            Text(tab.title)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button {
                                if model.activeTabID != tab.id {
                                    model.selectTab(tab)
                                }
                                model.closeActiveTab()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color(nsColor: model.theme.colors.mutedForeground.nsColor))
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .foregroundStyle(Color(nsColor: model.theme.colors.foreground.nsColor))
                        .background(model.activeTabID == tab.id ? Color(nsColor: model.theme.colors.background.nsColor) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Reveal in Finder") {
                            model.revealInFinder(tab.fileURL)
                        }
                        Button("Close Tab") {
                            if model.activeTabID != tab.id {
                                model.selectTab(tab)
                            }
                            model.closeActiveTab()
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: model.theme.colors.windowBackground.nsColor))
    }
}
