import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// A cross-platform color wrapper that supports Codable
struct CodableColor: Codable, Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(color: PlatformColor) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Convert to RGB color space if needed
        if let rgbColor = color.usingColorSpace(.deviceRGB) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        } else {
            // Fallback for colors that can't be converted
            self.red = 0.5
            self.green = 0.5
            self.blue = 0.5
            self.alpha = 0.1
        }
        #elseif canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        #endif
    }

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var platformColor: PlatformColor {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
        #elseif canImport(UIKit)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }

    /// Default selected line highlight color
    static let defaultSelectedLineHighlight = Self(
        red: 0.0,
        green: 0.0,
        blue: 1.0,
        alpha: 0.1
    )
}
