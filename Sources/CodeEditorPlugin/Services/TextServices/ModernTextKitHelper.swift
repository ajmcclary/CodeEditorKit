import Foundation
import AppKit

// MARK: - Modern TextKit2 Helper for macOS 26 Compatibility

/// Helper class to handle TextKit2 API changes and compatibility across macOS versions
@MainActor
public final class ModernTextKitHelper: @unchecked Sendable {
    
    // MARK: - TextKit2 Detection
    
    /// Check if TextKit2 should be used (and is stable)
    public static var shouldUseTextKit2: Bool {
        return macOSVersionDetection.hasStableTextKit2
    }
    
    /// Check if we can safely opt into TextKit2 for a text view
    public static func canOptIntoTextKit2(for textView: NSTextView) -> Bool {
        // Only opt into TextKit2 on macOS 23+ where it's more stable
        guard macOSVersionDetection.hasStableTextKit2 else { return false }
        
        // Additional checks can be added here for specific compatibility requirements
        return true
    }
    
    // MARK: - NSTextView Configuration
    
    /// Configure NSTextView with optimal settings for the current macOS version
    public static func configureTextView(_ textView: NSTextView) {
        // Basic configuration that works across all versions
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        
        // macOS version-specific optimizations
        if macOSVersionDetection.isMacOS26OrLater {
            configureForMacOS26(textView)
        } else if macOSVersionDetection.isMacOS25OrLater {
            configureForMacOS25(textView)
        } else if macOSVersionDetection.isMacOS24OrLater {
            configureForMacOS24(textView)
        }
        
        // TextKit2 specific configuration
        if shouldUseTextKit2 {
            configureTextKit2Features(textView)
        }
    }
    
    // MARK: - Version-Specific Configuration
    
    private static func configureForMacOS26(_ textView: NSTextView) {
        // macOS 26 Tahoe specific optimizations
        
        // Enable sound attachment support if available
        if macOSVersionDetection.supportsTextViewSoundAttachments {
            // Sound attachments are automatically supported in macOS 26
            // No additional configuration needed
        }
        
        // Optimize for Liquid Glass design
        if macOSVersionDetection.supportsLiquidGlassDesign {
            // Use adaptive background colors
            textView.backgroundColor = AdaptiveColorSystem.textBackgroundColor
            textView.insertionPointColor = NSColor.controlAccentColor
            
            // Configure selection appearance for Liquid Glass
            textView.selectedTextAttributes = [
                .backgroundColor: AdaptiveColorSystem.selectionColor,
                .foregroundColor: NSColor.selectedTextColor
            ]
        }
    }
    
    private static func configureForMacOS25(_ textView: NSTextView) {
        // macOS 25 specific optimizations
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.controlAccentColor
    }
    
    private static func configureForMacOS24(_ textView: NSTextView) {
        // macOS 24 specific optimizations
        textView.backgroundColor = NSColor.textBackgroundColor
    }
    
    private static func configureTextKit2Features(_ textView: NSTextView) {
        // TextKit2 specific configuration
        
        // Ensure we're using TextKit2 layout manager
        if let textLayoutManager = textView.textLayoutManager {
            // TextKit2 is active
            configureTextLayoutManager(textLayoutManager)
        } else {
            // Fallback to TextKit1 if needed
            if let layoutManager = textView.layoutManager {
                configureLayoutManager(layoutManager)
            }
        }
    }
    
    // MARK: - TextKit2 Layout Manager Configuration
    
    private static func configureTextLayoutManager(_ textLayoutManager: NSTextLayoutManager) {
        // Configure TextKit2 layout manager for optimal performance
        
        // Enable text container configurations that work well with modern macOS
        if let textContainer = textLayoutManager.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.lineFragmentPadding = 0
        }
    }
    
    // MARK: - TextKit1 Layout Manager Configuration (Fallback)
    
    private static func configureLayoutManager(_ layoutManager: NSLayoutManager) {
        // Configure TextKit1 layout manager for compatibility
        layoutManager.allowsNonContiguousLayout = true
        // Use default hyphenation instead of deprecated hyphenationFactor
        layoutManager.usesDefaultHyphenation = false
        
        if let textContainer = layoutManager.textContainers.first {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.lineFragmentPadding = 0
        }
    }
    
    // MARK: - Text Container Utilities
    
    /// Create a properly configured text container for the current macOS version
    public static func createTextContainer(size: NSSize) -> NSTextContainer {
        let textContainer = NSTextContainer(size: size)
        
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 0
        
        // macOS version-specific optimizations
        if macOSVersionDetection.isMacOS26OrLater {
            // Optimize for Liquid Glass design
            textContainer.lineBreakMode = .byWordWrapping
        }
        
        return textContainer
    }
    
    // MARK: - Performance Optimization
    
    /// Apply performance optimizations based on macOS version
    public static func optimizeTextViewPerformance(_ textView: NSTextView) {
        // Disable expensive features that aren't needed for code editing
        textView.isRichText = true  // We need this for syntax highlighting
        textView.importsGraphics = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.allowsUndo = true
        
        // Version-specific optimizations
        if macOSVersionDetection.isMacOS26OrLater {
            // macOS 26+ optimizations
            optimizeForModernMacOS(textView)
        } else {
            // Legacy macOS optimizations
            optimizeForLegacyMacOS(textView)
        }
    }
    
    private static func optimizeForModernMacOS(_ textView: NSTextView) {
        // Modern macOS performance optimizations
        textView.usesInspectorBar = false
        textView.isAutomaticTextCompletionEnabled = false
    }
    
    private static func optimizeForLegacyMacOS(_ textView: NSTextView) {
        // Legacy macOS performance optimizations
        textView.isAutomaticTextCompletionEnabled = false
    }
    
    // MARK: - Layout Region Support (macOS 26+)
    
    /// Configure layout guides for corner-avoiding layouts if available
    public static func configureLayoutRegions(for view: NSView) {
        guard macOSVersionDetection.supportsLayoutRegionAPI else { return }
        
        // This would use the new NSView.LayoutRegion API in macOS 26
        // Implementation would depend on the actual API when available
        
        // Placeholder for when the API is available:
        // if #available(macOS 26.0, *) {
        //     // Use new layout region API
        //     view.layoutRegions = [.safeArea, .cornerAvoidance]
        // }
    }
}

// MARK: - NSTextView Extension

extension NSTextView {
    
    /// Apply modern configuration for the current macOS version
    public func applyModernConfiguration() {
        ModernTextKitHelper.configureTextView(self)
        ModernTextKitHelper.optimizeTextViewPerformance(self)
    }
    
    /// Check if this text view is using TextKit2
    public var isUsingTextKit2: Bool {
        return textLayoutManager != nil
    }
    
    /// Get the appropriate text content manager for the current configuration
    public var modernTextContentManager: NSTextContentManager? {
        // This property should be accessed from the text view directly
        // as the helper doesn't store a reference to the text view
        return nil
    }
}