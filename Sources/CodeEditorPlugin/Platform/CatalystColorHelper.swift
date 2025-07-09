import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if targetEnvironment(macCatalyst)
import UIKit

/// Helper for handling Mac Catalyst-specific color conversion and application
///
/// Mac Catalyst has unique challenges with color conversion from SwiftUI to UIKit.
/// This helper centralizes the logic for reliable color handling on Catalyst.
public enum CatalystColorHelper {
    /// Converts a SwiftUI color to a guaranteed visible UIColor for Mac Catalyst
    ///
    /// Handles problematic SwiftUI colors that don't convert well on Catalyst,
    /// ensuring text remains visible in both light and dark modes.
    ///
    /// - Parameter color: The SwiftUI color to convert
    /// - Returns: A UIColor that is guaranteed to be visible
    @available(iOS 14.0, macCatalyst 14.0, *)
    public static func effectiveTextColor(from color: Color) -> UIColor {
        // Handle special SwiftUI colors first
        if color == Color.primary {
            // Use dynamic color that works with getRed
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .white : .black
            }
        } else if color == Color.clear {
            // Clear color should become a visible color
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .white : .black
            }
        } else if color == Color.accentColor {
            // Use a concrete blue color
            return UIColor.systemBlue
        }
        
        // For custom colors, try conversion but with fallback
        let converted = PlatformColor.from(color)
        
        // Verify the converted color has valid components
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        
        // Try to get RGB components
        if converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            // Check if color is visible
            if alpha > 0.1 && (red + green + blue) > 0.1 {
                return converted
            }
        }
        
        // If getRed fails or color is not visible, fallback to dynamic color
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .white : .black
        }
    }
    
    /// Applies text color to a text view with Catalyst-specific handling
    ///
    /// This method ensures the color is properly applied on Mac Catalyst,
    /// working around timing issues and text storage quirks.
    ///
    /// - Parameters:
    ///   - color: The color to apply
    ///   - textView: The text view to apply the color to
    @MainActor
    public static func applyTextColor(_ color: UIColor, to textView: CodeEditorView) async {
        // Apply color to the text view
        textView.textColor = color
        
        // Apply color to text storage immediately
        let textStorage = textView.textStorage
        if textStorage.length > 0 {
            textStorage.beginEditing()
            textStorage.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()
        }
        
        // Also apply through the dedicated Mac Catalyst method
        textView.applyTextColorForMacCatalyst()
        
        // Apply again after a delay to handle timing issues
        try? await Task.sleep(for: .milliseconds(100))
        textView.applyTextColorForMacCatalyst()
    }
}
#endif
