import AppKit
import Foundation

struct ThemeColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var cssValue: String {
        if alpha < 1 {
            return String(format: "#%02X%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
        }
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(hex: String) {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("#") else { return nil }
        let raw = String(value.dropFirst())
        let expanded: String
        switch raw.count {
        case 3:
            expanded = raw.map { "\($0)\($0)" }.joined()
        case 6, 8:
            expanded = raw
        default:
            return nil
        }

        guard let number = UInt64(expanded, radix: 16) else { return nil }
        if expanded.count == 8 {
            self.red = Double((number >> 24) & 0xff) / 255
            self.green = Double((number >> 16) & 0xff) / 255
            self.blue = Double((number >> 8) & 0xff) / 255
            self.alpha = Double(number & 0xff) / 255
        } else {
            self.red = Double((number >> 16) & 0xff) / 255
            self.green = Double((number >> 8) & 0xff) / 255
            self.blue = Double(number & 0xff) / 255
            self.alpha = 1
        }
    }

    func mixed(with other: ThemeColor, amount: Double) -> ThemeColor {
        let clamped = min(1, max(0, amount))
        return ThemeColor(
            red: red + (other.red - red) * clamped,
            green: green + (other.green - green) * clamped,
            blue: blue + (other.blue - blue) * clamped,
            alpha: alpha + (other.alpha - alpha) * clamped
        )
    }
}

enum ThemeBadgePlacement: String {
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
}

enum ThemeBadgeAnchor: String {
    case window
    case content
}

struct ThemeLength: Equatable {
    let points: Double
    let cssValue: String

    init(points: Double, cssValue: String) {
        self.points = points
        self.cssValue = cssValue
    }

    init?(cssValue: String) {
        let value = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^([0-9]+(?:\.[0-9]+)?)(rem|px|em)$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
            let numberRange = Range(match.range(at: 1), in: value),
            let unitRange = Range(match.range(at: 2), in: value),
            let number = Double(value[numberRange])
        else {
            return nil
        }

        let unit = String(value[unitRange])
        let multiplier = unit == "px" ? 1.0 : 16.0
        self.points = number * multiplier
        self.cssValue = value
    }
}

struct ThemeBadge: Equatable {
    let emoji: String?
    let imageURL: URL?
    let placement: ThemeBadgePlacement
    let anchor: ThemeBadgeAnchor
    let marginX: ThemeLength
    let marginY: ThemeLength
    let opacity: Double
    let size: ThemeLength
}

struct ResolvedTheme: Equatable {
    let colors: ThemeColors
    let appearance: ThemeAppearance
    let variables: [String: String]
    let rawAppCSS: String
    let rawWorkspaceCSS: String
    let badge: ThemeBadge?
    let workspaceTitle: String?

    var rendererPayload: RendererPayload.ThemePayload {
        RendererPayload.ThemePayload(
            variables: variables,
            appCSS: rawAppCSS,
            workspaceCSS: rawWorkspaceCSS,
            appearance: appearance.rawValue
        )
    }
}

struct ThemeColors: Equatable {
    let background: ThemeColor
    let foreground: ThemeColor
    let mutedForeground: ThemeColor
    let accent: ThemeColor
    let windowBackground: ThemeColor
    let selectionBackground: ThemeColor
    let border: ThemeColor
    let codeBackground: ThemeColor
    let quoteBackground: ThemeColor
    let tableHeaderBackground: ThemeColor
}

struct AppTheme: Identifiable, Equatable {
    let reference: ThemeReference
    let displayName: String
    let cssURL: URL
    let assetBaseURL: URL

    var id: String { reference.rawValue }
}
