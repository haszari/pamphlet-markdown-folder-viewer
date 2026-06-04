import Foundation

enum ThemeToken: String, CaseIterable {
    case background = "--pamphlet-background"
    case foreground = "--pamphlet-foreground"
    case mutedForeground = "--pamphlet-muted-foreground"
    case accent = "--pamphlet-accent"
    case appearance = "--pamphlet-appearance"
    case windowBackground = "--pamphlet-window-background"
    case selectionBackground = "--pamphlet-selection-background"
    case border = "--pamphlet-border"
    case fontFamily = "--pamphlet-font-family"
    case headingFontFamily = "--pamphlet-heading-font-family"
    case monospaceFontFamily = "--pamphlet-monospace-font-family"
    case codeBackground = "--pamphlet-code-background"
    case quoteBackground = "--pamphlet-quote-background"
    case workspaceTitle = "--pamphlet-workspace-title"
    case badge = "--pamphlet-badge"
    case badgeEmoji = "--pamphlet-badge-emoji"
    case badgeImage = "--pamphlet-badge-image"
    case badgePlacement = "--pamphlet-badge-placement"
    case badgeAnchor = "--pamphlet-badge-anchor"
    case badgeMarginX = "--pamphlet-badge-margin-x"
    case badgeMarginY = "--pamphlet-badge-margin-y"
    case badgeOpacity = "--pamphlet-badge-opacity"
    case badgeSize = "--pamphlet-badge-size"

    static let prefix = "--pamphlet-"
}

enum ThemeAppearance: String {
    case light
    case dark
    case adaptive
}

enum ThemeNamespace: String {
    case builtIn = "built-in"
    case user
}

struct ThemeReference: Hashable {
    static let separator = "::"
    static let fallback = ThemeReference(namespace: .builtIn, relativePath: "default/theme.css")

    let namespace: ThemeNamespace
    let relativePath: String

    var rawValue: String {
        "\(namespace.rawValue)\(Self.separator)\(relativePath)"
    }

    init(namespace: ThemeNamespace, relativePath: String) {
        self.namespace = namespace
        self.relativePath = relativePath
    }

    init?(rawValue: String) {
        let parts = rawValue.components(separatedBy: Self.separator)
        guard
            parts.count == 2,
            let namespace = ThemeNamespace(rawValue: parts[0]),
            Self.isSafeRelativePath(parts[1])
        else {
            return nil
        }
        self.namespace = namespace
        self.relativePath = parts[1]
    }

    static func isSafeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty, !value.hasPrefix("/") else { return false }
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains { component in
            component == ".." || component.isEmpty
        }
    }
}

