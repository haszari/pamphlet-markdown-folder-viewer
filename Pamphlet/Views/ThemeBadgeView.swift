import SwiftUI

struct ThemeBadgeView: View {
    let badge: ThemeBadge

    var body: some View {
        badgeContent
            .frame(width: badge.size.points, height: badge.size.points)
            .opacity(badge.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badgeContent: some View {
        if let imageURL = badge.imageURL, let image = NSImage(contentsOf: imageURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else if let emoji = badge.emoji {
            Text(emoji)
                .font(.system(size: badge.size.points * 0.72))
                .minimumScaleFactor(0.2)
                .lineLimit(1)
        }
    }
}

extension View {
    func themeBadgeOverlay(_ badge: ThemeBadge?) -> some View {
        overlay(alignment: badge?.alignment ?? .bottomLeading) {
            if let badge {
                ThemeBadgeView(badge: badge)
                    .padding(.horizontal, badge.marginX.points)
                    .padding(.vertical, badge.marginY.points)
            }
        }
    }
}

private extension ThemeBadge {
    var alignment: Alignment {
        switch placement {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }
}

