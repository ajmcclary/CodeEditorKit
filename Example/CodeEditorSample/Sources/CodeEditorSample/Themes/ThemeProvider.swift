import Foundation
import AppKit
import CodeEditorPlugin

// MARK: - Color Theme

enum ColorTheme: String, CaseIterable {
    case xcode
    case vsDark
    case github
    case solarizedDark
    case minimal
    case presentation
    
    var displayName: String {
        switch self {
        case .xcode: return "Xcode Default"
        case .vsDark: return "VS Code Dark"
        case .github: return "GitHub Light"
        case .solarizedDark: return "Solarized Dark"
        case .minimal: return "Minimal"
        case .presentation: return "Presentation"
        }
    }
    
    // MARK: - Background Colors
    
    var backgroundColor: NSColor {
        switch self {
        case .xcode:
            return NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        case .vsDark:
            return NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        case .github:
            return NSColor.white
        case .solarizedDark:
            return NSColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0)
        case .minimal:
            return NSColor.white
        case .presentation:
            return NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        }
    }
    
    var textColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.labelColor
        case .vsDark:
            return NSColor(red: 0.84, green: 0.84, blue: 0.84, alpha: 1.0)
        case .github:
            return NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)
        case .minimal:
            return NSColor.black
        case .presentation:
            return NSColor.white
        }
    }
    
    // MARK: - Syntax Colors
    
    var keywordColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.systemPurple
        case .vsDark:
            return NSColor(red: 0.33, green: 0.61, blue: 0.84, alpha: 1.0)
        case .github:
            return NSColor(red: 0.84, green: 0.2, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        case .minimal:
            return NSColor.systemPurple
        case .presentation:
            return NSColor(red: 0.68, green: 0.78, blue: 0.91, alpha: 1.0)
        }
    }
    
    var stringColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.systemRed
        case .vsDark:
            return NSColor(red: 0.82, green: 0.54, blue: 0.44, alpha: 1.0)
        case .github:
            return NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.52, green: 0.6, blue: 0.0, alpha: 1.0)
        case .minimal:
            return NSColor.systemRed
        case .presentation:
            return NSColor(red: 0.78, green: 0.91, blue: 0.68, alpha: 1.0)
        }
    }
    
    var numberColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.systemBlue
        case .vsDark:
            return NSColor(red: 0.71, green: 0.84, blue: 0.66, alpha: 1.0)
        case .github:
            return NSColor(red: 0.0, green: 0.53, blue: 0.75, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.16, green: 0.63, blue: 0.6, alpha: 1.0)
        case .minimal:
            return NSColor.systemBlue
        case .presentation:
            return NSColor(red: 0.91, green: 0.78, blue: 0.68, alpha: 1.0)
        }
    }
    
    var commentColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.systemGreen
        case .vsDark:
            return NSColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0)
        case .github:
            return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            return NSColor.systemGray
        case .presentation:
            return NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
        }
    }
    
    var typeColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.systemTeal
        case .vsDark:
            return NSColor(red: 0.3, green: 0.81, blue: 0.69, alpha: 1.0)
        case .github:
            return NSColor(red: 0.42, green: 0.23, blue: 0.69, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.71, green: 0.54, blue: 0.0, alpha: 1.0)
        case .minimal:
            return NSColor.systemTeal
        case .presentation:
            return NSColor(red: 0.91, green: 0.68, blue: 0.78, alpha: 1.0)
        }
    }
    
    var functionColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.systemIndigo
        case .vsDark:
            return NSColor(red: 0.86, green: 0.86, blue: 0.64, alpha: 1.0)
        case .github:
            return NSColor(red: 0.58, green: 0.35, blue: 0.0, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
        case .minimal:
            return NSColor.systemIndigo
        case .presentation:
            return NSColor(red: 0.78, green: 0.68, blue: 0.91, alpha: 1.0)
        }
    }
    
    // MARK: - UI Colors
    
    var selectedLineColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.selectedTextBackgroundColor.withAlphaComponent(0.1)
        case .vsDark:
            return NSColor(white: 1.0, alpha: 0.05)
        case .github:
            return NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0)
        case .minimal:
            return NSColor.clear
        case .presentation:
            return NSColor(white: 1.0, alpha: 0.08)
        }
    }
    
    var selectionColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.selectedTextBackgroundColor
        case .vsDark:
            return NSColor(red: 0.26, green: 0.43, blue: 0.64, alpha: 1.0)
        case .github:
            return NSColor(red: 0.7, green: 0.84, blue: 1.0, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 0.4)
        case .minimal:
            return NSColor.selectedTextBackgroundColor
        case .presentation:
            return NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.5)
        }
    }
    
    var gutterBackgroundColor: NSColor {
        switch self {
        case .xcode:
            return NSColor(white: 0.96, alpha: 1.0)
        case .vsDark:
            return backgroundColor
        case .github:
            return NSColor(white: 0.98, alpha: 1.0)
        case .solarizedDark:
            return backgroundColor
        case .minimal:
            return NSColor.clear
        case .presentation:
            return backgroundColor.withAlphaComponent(0.8)
        }
    }
    
    var gutterTextColor: NSColor {
        switch self {
        case .xcode:
            return NSColor.secondaryLabelColor
        case .vsDark:
            return NSColor(white: 0.5, alpha: 1.0)
        case .github:
            return NSColor(white: 0.6, alpha: 1.0)
        case .solarizedDark:
            return NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0)
        case .minimal:
            return NSColor.tertiaryLabelColor
        case .presentation:
            return NSColor(white: 0.4, alpha: 1.0)
        }
    }
    
    // MARK: - Token Type Mapping
    
    func colorForTokenType(_ tokenType: TokenType) -> NSColor {
        switch tokenType {
        case .keyword:
            return keywordColor
        case .identifier:
            return textColor
        case .string:
            return stringColor
        case .number:
            return numberColor
        case .comment:
            return commentColor
        case .type:
            return typeColor
        case .function:
            return functionColor
        case .property:
            return NSColor.systemOrange
        case .operator:
            return textColor
        case .punctuation:
            return textColor.withAlphaComponent(0.7)
        case .whitespace:
            return NSColor.clear
        case .preprocessor:
            return NSColor.systemPink
        case .unknown:
            return textColor
        }
    }
    
    // MARK: - Theme Export
    
    var themeConfiguration: [String: Any] {
        return [
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
        guard let color = usingColorSpace(.deviceRGB) else { return "#000000" }
        
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}