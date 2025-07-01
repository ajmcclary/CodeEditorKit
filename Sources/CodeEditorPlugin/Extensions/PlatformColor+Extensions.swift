import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - PlatformColor Extensions

/// Cross-platform color extensions to provide consistent API across iOS and macOS
extension PlatformColor {
    /// Returns a color with the specified alpha component
    /// This abstracts the platform differences between UIColor and NSColor
    public func withAlpha(_ alpha: CGFloat) -> PlatformColor {
        #if canImport(UIKit)
        return withAlphaComponent(alpha)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return withAlphaComponent(alpha)
        #endif
    }
    
    /// Creates a color from RGBA components (0.0 to 1.0)
    public static func rgba(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> PlatformColor {
        #if canImport(UIKit)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }
    
    /// Creates a color from HSB components
    public static func hsb(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat = 1.0) -> PlatformColor {
        #if canImport(UIKit)
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        #endif
    }
    
    /// Creates a color from a hex string (e.g., "#FF0000", "FF0000", "#F00")
    public convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex)
        
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        
        let length = hex.count - (hex.hasPrefix("#") ? 1 : 0)
        
        let red, green, blue, alpha: CGFloat
        
        switch length {
        case 3: // RGB (12-bit)
            red = CGFloat((hexNumber & 0xF00) >> 8) / 15.0
            green = CGFloat((hexNumber & 0x0F0) >> 4) / 15.0
            blue = CGFloat(hexNumber & 0x00F) / 15.0
            alpha = 1.0
        case 4: // ARGB (16-bit)
            alpha = CGFloat((hexNumber & 0xF000) >> 12) / 15.0
            red = CGFloat((hexNumber & 0x0F00) >> 8) / 15.0
            green = CGFloat((hexNumber & 0x00F0) >> 4) / 15.0
            blue = CGFloat(hexNumber & 0x000F) / 15.0
        case 6: // RRGGBB (24-bit)
            red = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            green = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(hexNumber & 0x0000FF) / 255.0
            alpha = 1.0
        case 8: // RRGGBBAA (32-bit)
            red = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
            green = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(hexNumber & 0x000000FF) / 255.0

        default:
            return nil
        }
        
        #if canImport(UIKit)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }
    
    /// Returns the RGBA components of the color
    public var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        return (red, green, blue, alpha)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let color = usingColorSpace(.deviceRGB) else { return nil }
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red, green, blue, alpha)
        #endif
    }
    
    /// Blends this color with another color by the specified amount
    /// - Parameters:
    ///   - color: The color to blend with
    ///   - amount: The blend amount (0.0 = this color, 1.0 = other color)
    /// - Returns: The blended color
    public func blended(with color: PlatformColor, amount: CGFloat) -> PlatformColor {
        guard let components1 = rgbaComponents,
              let components2 = color.rgbaComponents else {
            return self
        }
        
        let clampedAmount = max(0, min(1, amount))
        let inverseAmount = 1 - clampedAmount
        
        return .rgba(
            red: components1.red * inverseAmount + components2.red * clampedAmount,
            green: components1.green * inverseAmount + components2.green * clampedAmount,
            blue: components1.blue * inverseAmount + components2.blue * clampedAmount,
            alpha: components1.alpha * inverseAmount + components2.alpha * clampedAmount
        )
    }
    
    /// Returns a lighter version of the color
    /// - Parameter amount: The amount to lighten (0.0 to 1.0)
    /// - Returns: The lightened color
    public func lightened(by amount: CGFloat = 0.2) -> PlatformColor {
        blended(with: .white, amount: amount)
    }
    
    /// Returns a darker version of the color
    /// - Parameter amount: The amount to darken (0.0 to 1.0)
    /// - Returns: The darkened color
    public func darkened(by amount: CGFloat = 0.2) -> PlatformColor {
        blended(with: .black, amount: amount)
    }
}

// MARK: - Semantic Color Extensions

extension PlatformColor {
    /// Returns an appropriate highlight color for the selected line
    /// Adapts to light/dark mode automatically
    public static var selectedLineHighlight: PlatformColor {
        #if canImport(UIKit)
        return PlatformColors.tintColor.withAlpha(0.15)
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return PlatformColors.controlAccentColor.withAlpha(0.15)
        #endif
    }
    
    /// Returns an appropriate color for code editor background
    public static var codeBackground: PlatformColor {
        #if canImport(UIKit)
        return PlatformColors.systemBackground
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return PlatformColors.textBackgroundColor
        #endif
    }
    
    /// Returns an appropriate color for gutter background
    static var gutterBackground: PlatformColor {
        #if canImport(UIKit)
        return PlatformColors.secondarySystemBackground
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return PlatformColors.controlBackground
        #endif
    }
    
    /// Returns an appropriate color for line numbers
    public static var lineNumberColor: PlatformColor {
        #if canImport(UIKit)
        return PlatformColors.tertiaryLabel
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return PlatformColors.tertiaryLabel
        #endif
    }
}

// MARK: - Platform-Specific Helpers

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension NSColor {
    /// Convenience property to match UIColor API
    public static var label: NSColor {
        .labelColor
    }
    
    /// Convenience property to match UIColor API
    public static var secondaryLabel: NSColor {
        .secondaryLabelColor
    }
    
    /// Convenience property to match UIColor API
    public static var tertiaryLabel: NSColor {
        .tertiaryLabelColor
    }
}
#endif
