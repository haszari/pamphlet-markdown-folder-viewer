import AppKit
import Foundation
import os

@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    static let defaultThemeReference = ThemeReference.fallback
    private static let defaultThemeKey = "defaultThemeReference"

    @Published private(set) var appThemes: [AppTheme] = []

    private let logger = Logger(subsystem: "Pamphlet", category: "ThemeStore")
    private let fileManager: FileManager
    private let bundle: Bundle
    private let userDefaults: UserDefaults

    init(fileManager: FileManager = .default, bundle: Bundle = .main, userDefaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.bundle = bundle
        self.userDefaults = userDefaults
        reloadAppThemes()
    }

    var selectedThemeReference: ThemeReference {
        get {
            guard
                let raw = userDefaults.string(forKey: Self.defaultThemeKey),
                let reference = ThemeReference(rawValue: raw)
            else {
                return Self.defaultThemeReference
            }
            return reference
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Self.defaultThemeKey)
        }
    }

    var effectiveSelectedTheme: AppTheme {
        appThemes.first { $0.reference == selectedThemeReference }
            ?? appThemes.first { $0.reference == Self.defaultThemeReference }
            ?? Self.hardcodedDefaultTheme()
    }

    var userThemesURL: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Pamphlet/Themes", isDirectory: true)
    }

    func reloadAppThemes() {
        appThemes = discoverBuiltInThemes() + discoverUserThemes()
    }

    func revealUserThemesFolder() {
        guard let userThemesURL else { return }
        try? fileManager.createDirectory(at: userThemesURL, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([userThemesURL])
    }

    func resolveTheme(workspaceURL: URL, useDarkAppearance: Bool) -> ResolvedTheme {
        reloadAppThemes()
        let appTheme = effectiveSelectedTheme
        let appCSS = (try? String(contentsOf: appTheme.cssURL, encoding: .utf8)) ?? Self.defaultCSS
        let appExtraction = ThemeVariableParser.extract(from: appCSS, useDarkAppearance: useDarkAppearance)

        let workspaceThemeURL = workspaceURL.appendingPathComponent(".pamphlet.css")
        let workspaceCSS = (try? String(contentsOf: workspaceThemeURL, encoding: .utf8)) ?? ""
        let workspaceExtraction = ThemeVariableParser.extract(from: workspaceCSS, useDarkAppearance: useDarkAppearance)

        var variables = Self.fallbackVariables(useDarkAppearance: useDarkAppearance)
        var appVariables = validatedVariables(appExtraction.variables, source: appTheme.cssURL)
        appVariables.removeValue(forKey: ThemeToken.workspaceTitle.rawValue)
        let workspaceVariables = validatedVariables(workspaceExtraction.variables, source: workspaceThemeURL)
        variables.merge(appVariables) { _, new in new }
        variables.merge(workspaceVariables) { _, new in new }

        return makeResolvedTheme(
            variables: variables,
            workspaceVariables: workspaceVariables,
            rawAppCSS: appExtraction.sanitizedCSS,
            rawWorkspaceCSS: workspaceExtraction.sanitizedCSS,
            workspaceURL: workspaceURL,
            appAssetBaseURL: appTheme.assetBaseURL
        )
    }

    private func discoverBuiltInThemes() -> [AppTheme] {
        guard let themesURL = bundle.resourceURL?.appendingPathComponent("Themes") else {
            return Self.hardcodedThemes()
        }
        let themes = discoverThemes(in: themesURL, namespace: .builtIn, allowDirectFiles: false)
        return themes.isEmpty ? Self.hardcodedThemes() : themes
    }

    private func discoverUserThemes() -> [AppTheme] {
        guard let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return []
        }
        let themesURL = supportURL.appendingPathComponent("Pamphlet/Themes", isDirectory: true)
        return discoverThemes(in: themesURL, namespace: .user, allowDirectFiles: true)
    }

    private func discoverThemes(in rootURL: URL, namespace: ThemeNamespace, allowDirectFiles: Bool) -> [AppTheme] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var themes: [AppTheme] = []
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                let cssURL = url.appendingPathComponent("theme.css")
                guard fileManager.fileExists(atPath: cssURL.path) else { continue }
                let relativePath = "\(url.lastPathComponent)/theme.css"
                guard ThemeReference.isSafeRelativePath(relativePath) else { continue }
                themes.append(AppTheme(
                    reference: ThemeReference(namespace: namespace, relativePath: relativePath),
                    displayName: displayName(from: url.lastPathComponent),
                    cssURL: cssURL,
                    assetBaseURL: url
                ))
            } else if allowDirectFiles && url.pathExtension.lowercased() == "css" {
                let relativePath = url.lastPathComponent
                guard ThemeReference.isSafeRelativePath(relativePath) else { continue }
                themes.append(AppTheme(
                    reference: ThemeReference(namespace: namespace, relativePath: relativePath),
                    displayName: displayName(from: url.deletingPathExtension().lastPathComponent),
                    cssURL: url,
                    assetBaseURL: url.deletingLastPathComponent()
                ))
            }
        }

        return themes.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func displayName(from value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return "" }
                return first.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private func validatedVariables(_ variables: [String: String], source: URL) -> [String: String] {
        var result: [String: String] = [:]
        for (name, value) in variables {
            guard let token = ThemeToken(rawValue: name), isValid(value: value, for: token) else {
                logger.debug("Ignoring invalid theme value \(name, privacy: .public) from \(source.path, privacy: .public)")
                continue
            }
            result[name] = value
        }
        return result
    }

    private func isValid(value: String, for token: ThemeToken) -> Bool {
        let lowercased = value.lowercased()
        guard !lowercased.contains("var("), !lowercased.contains("color-mix(") else { return false }

        switch token {
        case .background, .foreground, .mutedForeground, .accent, .windowBackground, .selectionBackground, .border, .codeBackground, .quoteBackground:
            return ThemeColor(hex: value) != nil
        case .appearance:
            return ThemeAppearance(rawValue: value) != nil
        case .badgePlacement:
            return ThemeBadgePlacement(rawValue: value) != nil
        case .badgeAnchor:
            return ThemeBadgeAnchor(rawValue: value) != nil
        case .badgeMarginX, .badgeMarginY, .badgeSize:
            return ThemeLength(cssValue: value) != nil
        case .badgeOpacity:
            guard let opacity = Double(value) else { return false }
            return opacity >= 0 && opacity <= 1
        case .badge:
            return value == "none"
        case .badgeImage:
            return ThemeVariableParser.localURLValue(value) != nil
        case .fontFamily, .headingFontFamily, .monospaceFontFamily, .workspaceTitle, .badgeEmoji:
            return true
        }
    }

    private func makeResolvedTheme(
        variables: [String: String],
        workspaceVariables: [String: String],
        rawAppCSS: String,
        rawWorkspaceCSS: String,
        workspaceURL: URL,
        appAssetBaseURL: URL
    ) -> ResolvedTheme {
        let background = color(.background, variables) ?? ThemeColor(hex: "#ffffff")!
        let foreground = color(.foreground, variables) ?? ThemeColor(hex: "#1f2328")!
        let accent = color(.accent, variables) ?? ThemeColor(hex: "#0969da")!
        let mutedForeground = color(.mutedForeground, variables) ?? foreground.mixed(with: background, amount: 0.38)
        let windowBackground = color(.windowBackground, variables) ?? background.mixed(with: foreground, amount: 0.04)
        let selectionBackground = color(.selectionBackground, variables) ?? accent.mixed(with: background, amount: 0.78)
        let border = color(.border, variables) ?? foreground.mixed(with: background, amount: 0.82)
        let codeBackground = color(.codeBackground, variables) ?? foreground.mixed(with: background, amount: 0.92)
        let quoteBackground = color(.quoteBackground, variables) ?? foreground.mixed(with: background, amount: 0.95)
        let tableHeaderBackground = foreground.mixed(with: background, amount: 0.94)
        let appearance = variables[ThemeToken.appearance.rawValue].flatMap(ThemeAppearance.init(rawValue:)) ?? .adaptive

        var resolvedVariables = variables
        resolvedVariables[ThemeToken.background.rawValue] = background.cssValue
        resolvedVariables[ThemeToken.foreground.rawValue] = foreground.cssValue
        resolvedVariables[ThemeToken.accent.rawValue] = accent.cssValue
        resolvedVariables[ThemeToken.mutedForeground.rawValue] = mutedForeground.cssValue
        resolvedVariables[ThemeToken.windowBackground.rawValue] = windowBackground.cssValue
        resolvedVariables[ThemeToken.selectionBackground.rawValue] = selectionBackground.cssValue
        resolvedVariables[ThemeToken.border.rawValue] = border.cssValue
        resolvedVariables[ThemeToken.codeBackground.rawValue] = codeBackground.cssValue
        resolvedVariables[ThemeToken.quoteBackground.rawValue] = quoteBackground.cssValue
        resolvedVariables["--pamphlet-table-header-background"] = tableHeaderBackground.cssValue
        resolvedVariables[ThemeToken.appearance.rawValue] = appearance.rawValue

        return ResolvedTheme(
            colors: ThemeColors(
                background: background,
                foreground: foreground,
                mutedForeground: mutedForeground,
                accent: accent,
                windowBackground: windowBackground,
                selectionBackground: selectionBackground,
                border: border,
                codeBackground: codeBackground,
                quoteBackground: quoteBackground,
                tableHeaderBackground: tableHeaderBackground
            ),
            appearance: appearance,
            variables: resolvedVariables,
            rawAppCSS: rawAppCSS,
            rawWorkspaceCSS: rawWorkspaceCSS,
            badge: badge(from: variables, workspaceVariables: workspaceVariables, workspaceURL: workspaceURL, appAssetBaseURL: appAssetBaseURL),
            workspaceTitle: variables[ThemeToken.workspaceTitle.rawValue].map(ThemeVariableParser.unquote)
        )
    }

    private func color(_ token: ThemeToken, _ variables: [String: String]) -> ThemeColor? {
        variables[token.rawValue].flatMap(ThemeColor.init(hex:))
    }

    private func badge(from variables: [String: String], workspaceVariables: [String: String], workspaceURL: URL, appAssetBaseURL: URL) -> ThemeBadge? {
        if variables[ThemeToken.badge.rawValue] == "none" {
            return nil
        }

        let imageURL: URL?
        if let imageValue = variables[ThemeToken.badgeImage.rawValue],
           let path = ThemeVariableParser.localURLValue(imageValue) {
            let baseURL = workspaceVariables[ThemeToken.badgeImage.rawValue] == imageValue ? workspaceURL : appAssetBaseURL
            imageURL = baseURL.appendingPathComponent(path)
        } else {
            imageURL = nil
        }

        let emoji = variables[ThemeToken.badgeEmoji.rawValue].map(ThemeVariableParser.unquote)
        guard imageURL != nil || emoji != nil else { return nil }

        return ThemeBadge(
            emoji: emoji,
            imageURL: imageURL,
            placement: variables[ThemeToken.badgePlacement.rawValue].flatMap(ThemeBadgePlacement.init(rawValue:)) ?? .bottomLeft,
            anchor: variables[ThemeToken.badgeAnchor.rawValue].flatMap(ThemeBadgeAnchor.init(rawValue:)) ?? .window,
            marginX: variables[ThemeToken.badgeMarginX.rawValue].flatMap(ThemeLength.init(cssValue:)) ?? ThemeLength(points: 24, cssValue: "1.5rem"),
            marginY: variables[ThemeToken.badgeMarginY.rawValue].flatMap(ThemeLength.init(cssValue:)) ?? ThemeLength(points: 24, cssValue: "1.5rem"),
            opacity: variables[ThemeToken.badgeOpacity.rawValue].flatMap(Double.init) ?? 0.12,
            size: variables[ThemeToken.badgeSize.rawValue].flatMap(ThemeLength.init(cssValue:)) ?? ThemeLength(points: 96, cssValue: "6rem")
        )
    }

    private static func fallbackVariables(useDarkAppearance: Bool) -> [String: String] {
        if useDarkAppearance {
            return [
                ThemeToken.background.rawValue: "#1F2328",
                ThemeToken.foreground.rawValue: "#F6F8FA",
                ThemeToken.accent.rawValue: "#7CB7FF",
                ThemeToken.appearance.rawValue: ThemeAppearance.adaptive.rawValue,
            ]
        }

        return [
            ThemeToken.background.rawValue: "#FFFFFF",
            ThemeToken.foreground.rawValue: "#1F2328",
            ThemeToken.accent.rawValue: "#0969DA",
            ThemeToken.appearance.rawValue: ThemeAppearance.adaptive.rawValue,
        ]
    }

    private static let defaultCSS = """
    :root {
      --pamphlet-appearance: adaptive;
      --pamphlet-background: #ffffff;
      --pamphlet-foreground: #1f2328;
      --pamphlet-accent: #0969da;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --pamphlet-background: #1f2328;
        --pamphlet-foreground: #f6f8fa;
        --pamphlet-accent: #7cb7ff;
      }
    }
    """

    private static func hardcodedDefaultTheme() -> AppTheme {
        let tempURL = URL(fileURLWithPath: "/dev/null")
        return AppTheme(reference: .fallback, displayName: "Default", cssURL: tempURL, assetBaseURL: tempURL.deletingLastPathComponent())
    }

    private static func hardcodedThemes() -> [AppTheme] {
        [hardcodedDefaultTheme()]
    }
}
