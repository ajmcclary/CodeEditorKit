import AppKit
import CodeEditorPlugin
import Foundation

// MARK: - ColorTheme

enum ColorTheme: String, CaseIterable {
    case xcode
    case vsDark
    case github
    case solarizedDark
    case minimal
    case presentation

    var displayName: String {
        switch self {
        case .xcode: "Xcode Default"
        case .vsDark: "VS Code Dark"
        case .github: "GitHub Light"
        case .solarizedDark: "Solarized Dark"
        case .minimal: "Minimal"
        case .presentation: "Presentation"
        }
    }

    // MARK: - Background Colors

    var backgroundColor: NSColor {
        switch self {
        case .xcode:
            NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        case .vsDark:
            NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        case .github:
            NSColor.white
        case .solarizedDark:
            NSColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0)
        case .minimal:
            NSColor.white
        case .presentation:
            NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        }
    }

    var textColor: NSColor {
        switch self {
        case .xcode:
            NSColor.labelColor
        case .vsDark:
            NSColor(red: 0.84, green: 0.84, blue: 0.84, alpha: 1.0)
        case .github:
            NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)
        case .minimal:
            NSColor.black
        case .presentation:
            NSColor.white
        }
    }

    // MARK: - Syntax Colors

    var keywordColor: NSColor {
        switch self {
        case .xcode:
            NSColor.systemPurple
        case .vsDark:
            NSColor(red: 0.33, green: 0.61, blue: 0.84, alpha: 1.0)
        case .github:
            NSColor(red: 0.84, green: 0.2, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        case .minimal:
            NSColor.systemPurple
        case .presentation:
            NSColor(red: 0.68, green: 0.78, blue: 0.91, alpha: 1.0)
        }
    }

    var stringColor: NSColor {
        switch self {
        case .xcode:
            NSColor.systemRed
        case .vsDark:
            NSColor(red: 0.82, green: 0.54, blue: 0.44, alpha: 1.0)
        case .github:
            NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.52, green: 0.6, blue: 0.0, alpha: 1.0)
        case .minimal:
            NSColor.systemRed
        case .presentation:
            NSColor(red: 0.78, green: 0.91, blue: 0.68, alpha: 1.0)
        }
    }

    var numberColor: NSColor {
        switch self {
        case .xcode:
            NSColor.systemBlue
        case .vsDark:
            NSColor(red: 0.71, green: 0.84, blue: 0.66, alpha: 1.0)
        case .github:
            NSColor(red: 0.0, green: 0.53, blue: 0.75, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.16, green: 0.63, blue: 0.6, alpha: 1.0)
        case .minimal:
            NSColor.systemBlue
        case .presentation:
            NSColor(red: 0.91, green: 0.78, blue: 0.68, alpha: 1.0)
        }
    }

    var commentColor: NSColor {
        switch self {
        case .xcode:
            NSColor.systemGreen
        case .vsDark:
            NSColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0)
        case .github:
            NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            NSColor.systemGray
        case .presentation:
            NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
        }
    }

    var typeColor: NSColor {
        switch self {
        case .xcode:
            NSColor.systemTeal
        case .vsDark:
            NSColor(red: 0.3, green: 0.81, blue: 0.69, alpha: 1.0)
        case .github:
            NSColor(red: 0.42, green: 0.23, blue: 0.69, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.71, green: 0.54, blue: 0.0, alpha: 1.0)
        case .minimal:
            NSColor.systemTeal
        case .presentation:
            NSColor(red: 0.91, green: 0.68, blue: 0.78, alpha: 1.0)
        }
    }

    var functionColor: NSColor {
        switch self {
        case .xcode:
            NSColor.systemIndigo
        case .vsDark:
            NSColor(red: 0.86, green: 0.86, blue: 0.64, alpha: 1.0)
        case .github:
            NSColor(red: 0.58, green: 0.35, blue: 0.0, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        case .minimal:
            NSColor.systemIndigo
        case .presentation:
            NSColor(red: 0.78, green: 0.68, blue: 0.91, alpha: 1.0)
        }
    }

    // MARK: - UI Colors

    var selectedLineColor: NSColor {
        switch self {
        case .xcode:
            NSColor.selectedTextBackgroundColor.withAlphaComponent(0.1)
        case .vsDark:
            NSColor(white: 1.0, alpha: 0.05)
        case .github:
            NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0)
        case .minimal:
            NSColor.clear
        case .presentation:
            NSColor(white: 1.0, alpha: 0.08)
        }
    }

    var selectionColor: NSColor {
        switch self {
        case .xcode:
            NSColor.selectedTextBackgroundColor
        case .vsDark:
            NSColor(red: 0.26, green: 0.43, blue: 0.64, alpha: 1.0)
        case .github:
            NSColor(red: 0.7, green: 0.84, blue: 1.0, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 0.4)
        case .minimal:
            NSColor.selectedTextBackgroundColor
        case .presentation:
            NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.5)
        }
    }

    var gutterBackgroundColor: NSColor {
        switch self {
        case .xcode:
            NSColor(white: 0.96, alpha: 1.0)
        case .vsDark:
            backgroundColor
        case .github:
            NSColor(white: 0.98, alpha: 1.0)
        case .solarizedDark:
            backgroundColor
        case .minimal:
            NSColor.clear
        case .presentation:
            backgroundColor.withAlphaComponent(0.8)
        }
    }

    var gutterTextColor: NSColor {
        switch self {
        case .xcode:
            NSColor.secondaryLabelColor
        case .vsDark:
            NSColor(white: 0.5, alpha: 1.0)
        case .github:
            NSColor(white: 0.6, alpha: 1.0)
        case .solarizedDark:
            NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            NSColor.tertiaryLabelColor
        case .presentation:
            NSColor(white: 0.4, alpha: 1.0)
        }
    }

    // MARK: - Token Type Mapping

    func colorForTokenType(_ tokenType: TokenType) -> NSColor {
        switch tokenType {
        case .keyword:
            keywordColor
        case .identifier:
            textColor
        case .string:
            stringColor
        case .number:
            numberColor
        case .comment:
            commentColor
        case .type:
            typeColor
        case .function:
            functionColor
        case .property:
            NSColor.systemOrange
        case .operator:
            textColor
        case .punctuation:
            textColor.withAlphaComponent(0.7)
        case .whitespace:
            NSColor.clear
        case .preprocessor:
            NSColor.systemPink
        case .unknown:
            textColor
        }
    }

    // MARK: - Theme Export

    var themeConfiguration: [String: Any] {
        [
            "name": displayName,
            "colors": [
                "background": backgroundColor.hexString,
                "text": textColor.hexString,
                "keyword": keywordColor.hexString,
                "string": stringColor.hexString,
                "number": numberColor.hexString,
                "comment": commentColor.hexString,
                "type": typeColor.hexString,
                "function": functionColor.hexString,
                "selectedLine": selectedLineColor.hexString,
                "selection": selectionColor.hexString,
                "gutterBackground": gutterBackgroundColor.hexString,
                "gutterText": gutterTextColor.hexString
            ]
        ]
    }
}

// MARK: - NSColor Extension

extension NSColor {
    var hexString: String {
        guard let color = usingColorSpace(.deviceRGB) else {
            return "#000000"
        }

        let red = Int(color.redComponent * 255)
        let green = Int(color.greenComponent * 255)
        let blue = Int(color.blueComponent * 255)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
