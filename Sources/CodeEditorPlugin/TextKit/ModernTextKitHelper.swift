#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import Foundation
import os

// MARK: - ModernTextKitHelper

/// Helper for managing TextKit2 and modern macOS features
@MainActor
enum ModernTextKitHelper {
    /// Check if TextKit2 should be used
    static var shouldUseTextKit2: Bool {
        PlatformCapabilities.shared.preferTextKit2
    }
    
    /// Check if we can opt into TextKit2 for a specific text view
    static func canOptIntoTextKit2(for textView: NSTextView) -> Bool {
        // Basic requirement checks
        guard textView.textContainer != nil else { return false }
        
        // Only opt into TextKit2 on macOS 13+ where it's more stable
        guard PlatformCapabilities.shared.preferTextKit2 else {
            return false
        }
        
        // Additional checks can be added here for specific compatibility requirements
        return true
    }
    
    /// Force TextKit2 initialization if possible and beneficial
    static func ensureTextKit2(for textView: NSTextView) -> Bool {
        // Check if TextKit2 is already active
        if textView.textLayoutManager != nil {
            return true
        }
        
        // Only attempt to force TextKit2 on compatible systems
        guard canOptIntoTextKit2(for: textView) else {
            return false
        }
        
        // TextKit2 should be default on macOS 13+
        // If it's not active, there might be a specific reason
        if PlatformCapabilities.shared.preferTextKit2 {
            // Log the situation for debugging
            os.Logger(subsystem: "com.codeeditor.plugin", category: "ModernTextKitHelper")
                .debug("TextKit2 not active, using TextKit1 fallback")
        }
        
        return false
    }

    // MARK: - NSTextView Configuration

    /// Configure NSTextView with optimal settings for the current macOS version
    static func configureTextView(_ textView: NSTextView) {
        // Basic configuration that works across all versions
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        // macOS version-specific optimizations
        let capabilities = PlatformCapabilities.shared
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            configureForModernMacOS(textView)
        } else if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 13 {
            configureForMacOS13(textView)
        } else {
            configureForLegacyMacOS(textView)
        }

        // TextKit2 specific configuration
        if shouldUseTextKit2 {
            configureTextKit2Features(textView)
        }
    }

    // MARK: - Version-Specific Configuration

    private static func configureForModernMacOS(_ textView: NSTextView) {
        // macOS 14+ specific optimizations
        
        // Use adaptive colors for better appearance
        textView.backgroundColor = AdaptiveColorSystem.textBackgroundColor
        textView.insertionPointColor = PlatformColors.controlAccentColor

        // Configure selection appearance
        textView.selectedTextAttributes = [
            .backgroundColor: AdaptiveColorSystem.selectionColor,
            .foregroundColor: PlatformColors.selectedTextColor
        ]

        // Enhanced text smoothing for high-resolution displays
        textView.allowsDocumentBackgroundColorChange = false
        
        // Optimize for performance
        textView.isAutomaticTextCompletionEnabled = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
    }

    private static func configureForMacOS13(_ textView: NSTextView) {
        // macOS 13 Ventura specific settings
        
        // Basic TextKit2 optimizations
        textView.allowsDocumentBackgroundColorChange = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        
        // Performance tuning
        textView.isAutomaticTextCompletionEnabled = false
    }

    private static func configureForLegacyMacOS(_ textView: NSTextView) {
        // macOS 12 and earlier
        
        // Legacy performance optimizations
        textView.isAutomaticTextCompletionEnabled = false
    }

    // MARK: - TextKit2 Features

    private static func configureTextKit2Features(_ textView: NSTextView) {
        guard let textLayoutManager = textView.textLayoutManager else { return }
        
        // Configure TextKit2 specific features
        // Note: TextKit2 configuration is handled automatically by the system
        // Additional configuration can be added here as needed
        
        // Ensure layout manager is properly configured
        _ = textLayoutManager.usageBoundsForTextContainer
    }

    // MARK: - Control Size Support

    /// Get the recommended control size based on platform capabilities
    static func recommendedControlSize() -> NSControl.ControlSize {
        // Use platform capabilities to determine appropriate size
        let capabilities = PlatformCapabilities.shared
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            return .regular
        } else {
            return .small
        }
    }

    // MARK: - Performance Optimizations

    /// Apply performance optimizations based on system capabilities
    static func applyPerformanceOptimizations(to textView: NSTextView) {
        // Disable expensive features during editing
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        
        // Configure layout manager if using TextKit1
        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = true
            layoutManager.backgroundLayoutEnabled = true
        }
        
        // Configure text container
        if let textContainer = textView.textContainer {
            textContainer.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }
    }

    // MARK: - Color System Integration

    /// Configure text view with adaptive colors
    static func applyAdaptiveColors(to textView: NSTextView) {
        textView.backgroundColor = AdaptiveColorSystem.textBackgroundColor
        textView.insertionPointColor = PlatformColors.controlAccentColor
        
        // Configure selection colors
        textView.selectedTextAttributes = [
            .backgroundColor: AdaptiveColorSystem.selectionColor,
            .foregroundColor: PlatformColors.selectedTextColor
        ]
    }

    // MARK: - Layout Region Support
    
    // NOTE: Layout region API support has been removed as it was based on
    // speculative future macOS versions. This functionality can be added
    // when/if such APIs become available in future macOS releases.
}

#else

// MARK: - IOS Stub

/// iOS stub for ModernTextKitHelper
enum ModernTextKitHelper {
    static var shouldUseTextKit2: Bool { false }
    
    static func canOptIntoTextKit2(for _: Any) -> Bool { false }
    
    static func ensureTextKit2(for _: Any) -> Bool { false }
}

#endif
