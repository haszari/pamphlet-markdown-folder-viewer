import XCTest
@testable import Pamphlet

final class ThemeTests: XCTestCase {
    func testThemeParserReadsRootAndDarkMediaVariables() {
        let css = """
        @import url("ignored.css");
        :root {
          --pamphlet-background: #ffffff;
          --pamphlet-foreground: #111111;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --pamphlet-background: #000000;
          }
        }
        """

        let light = ThemeVariableParser.extract(from: css, useDarkAppearance: false)
        XCTAssertEqual(light.variables["--pamphlet-background"], "#ffffff")
        XCTAssertEqual(light.variables["--pamphlet-foreground"], "#111111")
        XCTAssertFalse(light.sanitizedCSS.contains("@import"))

        let dark = ThemeVariableParser.extract(from: css, useDarkAppearance: true)
        XCTAssertEqual(dark.variables["--pamphlet-background"], "#000000")
        XCTAssertEqual(dark.variables["--pamphlet-foreground"], "#111111")
    }

    func testThemeReferenceRejectsUnsafePaths() {
        XCTAssertEqual(ThemeReference(rawValue: "built-in::default/theme.css")?.relativePath, "default/theme.css")
        XCTAssertNil(ThemeReference(rawValue: "built-in::../theme.css"))
        XCTAssertNil(ThemeReference(rawValue: "user::/tmp/theme.css"))
        XCTAssertNil(ThemeReference(rawValue: "user/Banana Corp/theme.css"))
    }

    func testThemeColorAcceptsHexOnly() {
        XCTAssertNotNil(ThemeColor(hex: "#fff"))
        XCTAssertNotNil(ThemeColor(hex: "#112233"))
        XCTAssertNotNil(ThemeColor(hex: "#112233cc"))
        XCTAssertNil(ThemeColor(hex: "red"))
        XCTAssertNil(ThemeColor(hex: "rgb(1 2 3)"))
    }

    func testAllThemeTokensUsePamphletPrefix() {
        XCTAssertFalse(ThemeToken.allCases.isEmpty)
        for token in ThemeToken.allCases {
            XCTAssertTrue(token.rawValue.hasPrefix(ThemeToken.prefix))
        }
    }
}

