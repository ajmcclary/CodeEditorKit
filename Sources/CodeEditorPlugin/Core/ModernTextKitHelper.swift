import AppKit
import Foundation
import os.log

// MARK: - ModernTextKitHelper

/// Helper class to handle TextKit2 API changes and compatibility across macOS versions
@MainActor
public final class ModernTextKitHelper: @unchecked Sendable {
    // MARK: - TextKit2 Detection

    /// Check if TextKit2 should be used (and is stable)
    public static var shouldUseTextKit2: Bool {
        MacOSVersionDetection.hasStableTextKit2
    }

    /// Check if we can safely opt into TextKit2 for a text view
    public static func canOptIntoTextKit2(for textView: NSTextView) -> Bool {
        // Only opt into TextKit2 on macOS 23+ where it's more stable
        guard MacOSVersionDetection.hasStableTextKit2 else {
            return false
        }

        // Additional checks for macOS 26+ compatibility
        if MacOSVersionDetection.isMacOS26OrLater {
            return canUseTextKit2OnMacOS26(textView)
        }

        // Additional checks can be added here for specific compatibility requirements
        return true
    }
    
    /// Enhanced TextKit2 compatibility check for macOS 26+
    private static func canUseTextKit2OnMacOS26(_ textView: NSTextView) -> Bool {
        // macOS 26 has improved TextKit2 stability
        // Check for any known issues or requirements
        
        // Ensure the text view is properly configured
        guard textView.textStorage != nil else {
            return false
        }
        
        // macOS 26+ should handle TextKit2 well for most use cases
        return true
    }
    
    /// Force TextKit2 initialization if possible and beneficial
    public static func ensureTextKit2(for textView: NSTextView) -> Bool {
        // Check if TextKit2 is already active
        if textView.textLayoutManager != nil {
            return true
        }
        
        // Only attempt to force TextKit2 on compatible systems
        guard canOptIntoTextKit2(for: textView) else {
            return false
        }
        
        // On macOS 26+, TextKit2 should be the default
        // If it's not active, there might be a specific reason
        if MacOSVersionDetection.isMacOS26OrLater {
            // Log the situation for debugging
            os.Logger(subsystem: "com.codeeditor.plugin", category: "ModernTextKitHelper")
                .debug("TextKit2 not active on macOS 26+, using TextKit1 fallback")
        }
        
        return false
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
        if MacOSVersionDetection.isMacOS26OrLater {
            configureForMacOS26(textView)
        } else if MacOSVersionDetection.isMacOS25OrLater {
            configureForMacOS25(textView)
        } else if MacOSVersionDetection.isMacOS24OrLater {
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
        if MacOSVersionDetection.supportsTextViewSoundAttachments {
            // Sound attachments are automatically supported in macOS 26
            // No additional configuration needed
        }

        // Optimize for Liquid Glass design
        if MacOSVersionDetection.supportsLiquidGlassDesign {
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
        
        // Check if we're on macOS 26+ for enhanced TextKit2 features
        if MacOSVersionDetection.isMacOS26OrLater {
            configureTextKit2ForMacOS26(textView)
        }

        // Ensure we're using TextKit2 layout manager
        if let textLayoutManager = textView.textLayoutManager {
            // TextKit2 is active
            configureTextLayoutManager(textLayoutManager)
            
            // Enable advanced TextKit2 features if available
            if MacOSVersionDetection.isMacOS26OrLater {
                configureAdvancedTextLayoutFeatures(textLayoutManager)
            }
        } else {
            // Fallback to TextKit1 if needed
            if let layoutManager = textView.layoutManager {
                configureLayoutManager(layoutManager)
            }
        }
    }
    
    /// Configure TextKit2 features specific to macOS 26+
    private static func configureTextKit2ForMacOS26(_ textView: NSTextView) {
        // macOS 26 introduced improved TextKit2 stability and new features
        
        // Enable enhanced text rendering if available
        if MacOSVersionDetection.supportsLiquidGlassDesign {
            // Optimize text rendering for Liquid Glass design
            // Use available properties that improve rendering
            textView.backgroundColor = AdaptiveColorSystem.textBackgroundColor
            textView.insertionPointColor = NSColor.controlAccentColor
        }
        
        // Configure for better performance with large documents
        textView.allowsUndo = true
        textView.isAutomaticTextCompletionEnabled = false
        
        // Disable features that can impact performance in code editing
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        
        // Enhanced text view features
        textView.usesFindBar = true
        textView.usesFontPanel = true
        textView.usesRuler = false // Disable ruler for code editing
    }
    
    /// Configure advanced TextKit2 layout features for macOS 26+
    private static func configureAdvancedTextLayoutFeatures(_ textLayoutManager: NSTextLayoutManager) {
        // Configure text layout manager for optimal performance on macOS 26+
        
        // Enable enhanced layout caching if available
        if let textContainer = textLayoutManager.textContainer {
            textContainer.maximumNumberOfLines = 0 // No line limit
            textContainer.lineBreakMode = .byWordWrapping
            
            // Optimize for large documents
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }
        
        // Configure text selection behavior
        textLayoutManager.limitsLayoutForSuspiciousContents = true
        
        // Enable text rendering optimizations if available
        textLayoutManager.usesHyphenation = false
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
        if MacOSVersionDetection.isMacOS26OrLater {
            // Optimize for Liquid Glass design
            textContainer.lineBreakMode = .byWordWrapping
        }

        return textContainer
    }

    // MARK: - Performance Optimization

    /// Apply performance optimizations based on macOS version
    public static func optimizeTextViewPerformance(_ textView: NSTextView) {
        // Disable expensive features that aren't needed for code editing
        textView.isRichText = true // We need this for syntax highlighting
        textView.importsGraphics = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.allowsUndo = true

        // Version-specific optimizations
        if MacOSVersionDetection.isMacOS26OrLater {
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
    public static func configureLayoutRegions(for _: NSView) {
        guard MacOSVersionDetection.supportsLayoutRegionAPI else {
            return
        }

        // This would use the new NSView.LayoutRegion API in macOS 26
        // Implementation would depend on the actual API when available

        // Placeholder for when the API is available:
        // if #available(macOS 26.0, *) {
        //     // Use new layout region API
        //     view.layoutRegions = [.safeArea, .cornerAvoidance]
        // }
    }

    deinit {
        // Cleanup if needed
    }
}

// MARK: - NSTextView Extension

extension NSTextView {
    /// Apply modern configuration for the current macOS version
    func applyModernConfiguration() {
        ModernTextKitHelper.configureTextView(self)
        ModernTextKitHelper.optimizeTextViewPerformance(self)
    }

    /// Check if this text view is using TextKit2
    var isUsingTextKit2: Bool {
        textLayoutManager != nil
    }

    /// Get the appropriate text content manager for the current configuration
    var modernTextContentManager: NSTextContentManager? {
        // This property should be accessed from the text view directly
        // as the helper doesn't store a reference to the text view
        nil
    }
}
