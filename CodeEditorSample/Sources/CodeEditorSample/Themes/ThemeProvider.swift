#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

    var backgroundColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        case .vsDark:
            PlatformColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        case .github:
            PlatformColor.white
        case .solarizedDark:
            PlatformColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0)
        case .minimal:
            PlatformColor.white
        case .presentation:
            PlatformColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        }
    }

    var textColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColors.label
        case .vsDark:
            PlatformColor(red: 0.84, green: 0.84, blue: 0.84, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)
        case .minimal:
            PlatformColor.black
        case .presentation:
            PlatformColor.white
        }
    }

    // MARK: - Syntax Colors

    var keywordColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor.systemPurple
        case .vsDark:
            PlatformColor(red: 0.33, green: 0.61, blue: 0.84, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.84, green: 0.2, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        case .minimal:
            PlatformColor.systemPurple
        case .presentation:
            PlatformColor(red: 0.68, green: 0.78, blue: 0.91, alpha: 1.0)
        }
    }

    var stringColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor.systemRed
        case .vsDark:
            PlatformColor(red: 0.82, green: 0.54, blue: 0.44, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.52, green: 0.6, blue: 0.0, alpha: 1.0)
        case .minimal:
            PlatformColor.systemRed
        case .presentation:
            PlatformColor(red: 0.78, green: 0.91, blue: 0.68, alpha: 1.0)
        }
    }

    var numberColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor.systemBlue
        case .vsDark:
            PlatformColor(red: 0.71, green: 0.84, blue: 0.66, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.0, green: 0.53, blue: 0.75, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.16, green: 0.63, blue: 0.6, alpha: 1.0)
        case .minimal:
            PlatformColor.systemBlue
        case .presentation:
            PlatformColor(red: 0.91, green: 0.78, blue: 0.68, alpha: 1.0)
        }
    }

    var commentColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor.systemGreen
        case .vsDark:
            PlatformColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            PlatformColor.systemGray
        case .presentation:
            PlatformColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
        }
    }

    var typeColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor.systemTeal
        case .vsDark:
            PlatformColor(red: 0.3, green: 0.81, blue: 0.69, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.42, green: 0.23, blue: 0.69, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.71, green: 0.54, blue: 0.0, alpha: 1.0)
        case .minimal:
            PlatformColor.systemTeal
        case .presentation:
            PlatformColor(red: 0.91, green: 0.68, blue: 0.78, alpha: 1.0)
        }
    }

    var functionColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor.systemIndigo
        case .vsDark:
            PlatformColor(red: 0.86, green: 0.86, blue: 0.64, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.58, green: 0.35, blue: 0.0, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        case .minimal:
            PlatformColor.systemIndigo
        case .presentation:
            PlatformColor(red: 0.78, green: 0.68, blue: 0.91, alpha: 1.0)
        }
    }

    // MARK: - UI Colors

    var selectedLineColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColors.textBackgroundColor.withAlphaComponent(0.1)
        case .vsDark:
            PlatformColor(white: 1.0, alpha: 0.05)
        case .github:
            PlatformColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0)
        case .minimal:
            PlatformColor.clear
        case .presentation:
            PlatformColor(white: 1.0, alpha: 0.08)
        }
    }

    var selectionColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColors.textBackgroundColor
        case .vsDark:
            PlatformColor(red: 0.26, green: 0.43, blue: 0.64, alpha: 1.0)
        case .github:
            PlatformColor(red: 0.7, green: 0.84, blue: 1.0, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 0.4)
        case .minimal:
            PlatformColors.textBackgroundColor
        case .presentation:
            PlatformColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.5)
        }
    }

    var gutterBackgroundColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColor(white: 0.96, alpha: 1.0)
        case .vsDark:
            backgroundColor
        case .github:
            PlatformColor(white: 0.98, alpha: 1.0)
        case .solarizedDark:
            backgroundColor
        case .minimal:
            PlatformColor.clear
        case .presentation:
            backgroundColor.withAlphaComponent(0.8)
        }
    }

    var gutterTextColor: PlatformColor {
        switch self {
        case .xcode:
            PlatformColors.secondaryLabel
        case .vsDark:
            PlatformColor(white: 0.5, alpha: 1.0)
        case .github:
            PlatformColor(white: 0.6, alpha: 1.0)
        case .solarizedDark:
            PlatformColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            PlatformColors.tertiaryLabel
        case .presentation:
            PlatformColor(white: 0.4, alpha: 1.0)
        }
    }

    // MARK: - Token Type Mapping

    func colorForTokenType(_ tokenType: TokenType) -> PlatformColor {
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
            PlatformColor.systemOrange
        case .operator:
            textColor
        case .punctuation:
            textColor.withAlphaComponent(0.7)
        case .whitespace:
            PlatformColor.clear
        case .preprocessor:
            PlatformColor.systemPink
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

// MARK: - PlatformColor Extension

extension PlatformColor {
    var hexString: String {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let color = usingColorSpace(.deviceRGB) else {
            return "#000000"
        }

        let red = Int(color.redComponent * 255)
        let green = Int(color.greenComponent * 255)
        let blue = Int(color.blueComponent * 255)
        
        return String(format: "#%02X%02X%02X", red, green, blue)
        #else
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let redInt = Int(red * 255)
        let greenInt = Int(green * 255)
        let blueInt = Int(blue * 255)
        
        return String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
        #endif
    }
}

#else
import CodeEditorPlugin
import Foundation
import UIKit

// iOS implementation - enhanced theme support
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
    
    var backgroundColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.systemBackground
        case .vsDark:
            return PlatformColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        case .github:
            return PlatformColors.systemBackground
        case .solarizedDark:
            return PlatformColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0)
        case .minimal:
            return PlatformColors.systemBackground
        case .presentation:
            return PlatformColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        }
    }
    
    var textColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.label
        case .vsDark:
            return PlatformColor(red: 0.84, green: 0.84, blue: 0.84, alpha: 1.0)
        case .github:
            return PlatformColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        case .solarizedDark:
            return PlatformColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)
        case .minimal:
            return PlatformColors.label
        case .presentation:
            return PlatformColors.label
        }
    }
    
    // MARK: - Syntax Colors
    
    var keywordColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.systemPurple
        case .vsDark:
            return PlatformColor(red: 0.33, green: 0.61, blue: 0.84, alpha: 1.0)
        case .github:
            return PlatformColor(red: 0.84, green: 0.2, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            return PlatformColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        case .minimal:
            return PlatformColors.systemPurple
        case .presentation:
            return PlatformColor(red: 0.68, green: 0.78, blue: 0.91, alpha: 1.0)
        }
    }
    
    var stringColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.systemRed
        case .vsDark:
            return PlatformColor(red: 0.82, green: 0.54, blue: 0.44, alpha: 1.0)
        case .github:
            return PlatformColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .solarizedDark:
            return PlatformColor(red: 0.52, green: 0.6, blue: 0.0, alpha: 1.0)
        case .minimal:
            return PlatformColors.systemRed
        case .presentation:
            return PlatformColor(red: 0.78, green: 0.91, blue: 0.68, alpha: 1.0)
        }
    }
    
    var numberColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.systemBlue
        case .vsDark:
            return PlatformColor(red: 0.71, green: 0.84, blue: 0.66, alpha: 1.0)
        case .github:
            return PlatformColor(red: 0.0, green: 0.53, blue: 0.75, alpha: 1.0)
        case .solarizedDark:
            return PlatformColor(red: 0.16, green: 0.63, blue: 0.6, alpha: 1.0)
        case .minimal:
            return PlatformColors.systemBlue
        case .presentation:
            return PlatformColor(red: 0.91, green: 0.78, blue: 0.68, alpha: 1.0)
        }
    }
    
    var commentColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.systemGreen
        case .vsDark:
            return PlatformColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0)
        case .github:
            return PlatformColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            return PlatformColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            return PlatformColors.secondaryLabel
        case .presentation:
            return PlatformColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
        }
    }
    
    // MARK: - UI Colors
    
    var selectedLineColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.systemBlue.withAlphaComponent(0.1)
        case .vsDark:
            return PlatformColor(white: 1.0, alpha: 0.05)
        case .github:
            return PlatformColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        case .solarizedDark:
            return PlatformColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0)
        case .minimal:
            return PlatformColor.clear
        case .presentation:
            return PlatformColor(white: 1.0, alpha: 0.08)
        }
    }
    
    var lineNumberColor: PlatformColor {
        switch self {
        case .xcode:
            return PlatformColors.secondaryLabel
        case .vsDark:
            return PlatformColor(white: 0.5, alpha: 1.0)
        case .github:
            return PlatformColor(white: 0.6, alpha: 1.0)
        case .solarizedDark:
            return PlatformColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            return PlatformColors.tertiaryLabel
        case .presentation:
            return PlatformColor(white: 0.4, alpha: 1.0)
        }
    }
    
    var insertionPointColor: PlatformColor {
        return PlatformColors.systemBlue
    }
}
#endif
