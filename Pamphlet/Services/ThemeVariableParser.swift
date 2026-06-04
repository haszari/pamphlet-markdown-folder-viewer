import Foundation

struct ThemeExtraction: Equatable {
    let variables: [String: String]
    let sanitizedCSS: String
}

enum ThemeVariableParser {
    static func extract(from css: String, useDarkAppearance: Bool) -> ThemeExtraction {
        let withoutComments = stripComments(css)
        let sanitized = removeImports(withoutComments)
        let mediaRanges = darkMediaRanges(in: sanitized)
        var variables = rootVariables(in: sanitized, excluding: mediaRanges)

        if useDarkAppearance {
            for range in mediaRanges {
                let body = String(sanitized[range])
                variables.merge(rootVariables(in: body, excluding: [])) { _, dark in dark }
            }
        }

        return ThemeExtraction(variables: variables, sanitizedCSS: sanitized)
    }

    static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return trimmed }
        let first = trimmed.first
        let last = trimmed.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    static func localURLValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("url("), trimmed.hasSuffix(")") else { return nil }
        let inner = String(trimmed.dropFirst(4).dropLast())
        let path = unquote(inner)
        guard
            !path.isEmpty,
            !path.hasPrefix("/"),
            !path.contains("://"),
            ThemeReference.isSafeRelativePath(path)
        else {
            return nil
        }
        return path
    }

    private static func stripComments(_ css: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#) else { return css }
        return regex.stringByReplacingMatches(
            in: css,
            range: NSRange(css.startIndex..., in: css),
            withTemplate: ""
        )
    }

    private static func removeImports(_ css: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"@import\b[^;]*;"#, options: [.caseInsensitive]) else { return css }
        return regex.stringByReplacingMatches(
            in: css,
            range: NSRange(css.startIndex..., in: css),
            withTemplate: ""
        )
    }

    private static func darkMediaRanges(in css: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStart = css.startIndex

        while let mediaRange = css.range(of: "@media", range: searchStart..<css.endIndex) {
            guard
                let openBrace = css[mediaRange.lowerBound..<css.endIndex].firstIndex(of: "{"),
                let closeBrace = matchingBrace(in: css, openBrace: openBrace)
            else {
                break
            }

            let header = css[mediaRange.lowerBound..<openBrace].lowercased()
            if header.contains("prefers-color-scheme") && header.contains("dark") {
                ranges.append(css.index(after: openBrace)..<closeBrace)
            }
            searchStart = css.index(after: closeBrace)
        }

        return ranges
    }

    private static func rootVariables(in css: String, excluding excludedRanges: [Range<String.Index>]) -> [String: String] {
        var variables: [String: String] = [:]
        var searchStart = css.startIndex

        while let rootRange = css.range(of: ":root", range: searchStart..<css.endIndex) {
            guard
                !excludedRanges.contains(where: { $0.contains(rootRange.lowerBound) }),
                let openBrace = css[rootRange.upperBound..<css.endIndex].firstIndex(of: "{"),
                let closeBrace = matchingBrace(in: css, openBrace: openBrace)
            else {
                searchStart = rootRange.upperBound
                continue
            }

            let body = css[css.index(after: openBrace)..<closeBrace]
            variables.merge(parseDeclarations(String(body))) { _, new in new }
            searchStart = css.index(after: closeBrace)
        }

        return variables
    }

    private static func parseDeclarations(_ body: String) -> [String: String] {
        var variables: [String: String] = [:]
        for declaration in body.split(separator: ";", omittingEmptySubsequences: true) {
            guard let separator = declaration.firstIndex(of: ":") else { continue }
            let name = declaration[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = declaration[declaration.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.hasPrefix(ThemeToken.prefix), !value.isEmpty else { continue }
            variables[name] = value
        }
        return variables
    }

    private static func matchingBrace(in css: String, openBrace: String.Index) -> String.Index? {
        var depth = 0
        var index = openBrace
        while index < css.endIndex {
            if css[index] == "{" {
                depth += 1
            } else if css[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
            index = css.index(after: index)
        }
        return nil
    }
}

