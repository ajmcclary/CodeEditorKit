import CodeEditorPlatform
import CodeEditorSyntaxHighlighting
#if canImport(AppKit)
import AppKit
import Foundation
import os

// MARK: - ModernTextKitHelper

/// Helper for managing required TextKit2 and modern macOS features.
@MainActor
enum ModernTextKitHelper {
    /// Check if the required TextKit2 surface is available.
    package static var supportsRequiredTextKit2Surface: Bool {
        supportsRequiredTextKit2Surface(capabilities: CodeEditorDependencies.makePlatformCapabilities())
    }

    /// Check if the required TextKit2 surface is available with injectable capabilities.
    package static func supportsRequiredTextKit2Surface(capabilities: PlatformCapabilities) -> Bool {
        capabilities.supportsRequiredTextKit2Surface
    }

    /// Validate TextKit2 requirements for a specific text view.
    static func validatesRequiredTextKit2Surface(
        for textView: NSTextView,
        capabilities: PlatformCapabilities? = nil
    ) -> Bool {
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        guard textView.textContainer != nil else { return false }
        return capabilities.supportsRequiredTextKit2Surface
    }

    /// Validate that the required TextKit2 surface is active.
    static func validateRequiredTextKit2Surface(
        for textView: NSTextView,
        capabilities: PlatformCapabilities? = nil
    ) -> Bool {
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        if textView.textLayoutManager != nil {
            return true
        }

        guard validatesRequiredTextKit2Surface(for: textView, capabilities: capabilities) else {
            return false
        }

        os.Logger(subsystem: "com.codeeditor.plugin", category: "ModernTextKitHelper")
            .debug("Required TextKit2 surface is unavailable on this text view")

        return false
    }

    // MARK: - NSTextView Configuration

    /// Configure NSTextView with optimal settings for the current macOS version
    /// - Parameters:
    ///   - textView: The text view to configure
    ///   - capabilities: Platform capabilities (defaults to dependency factory)
    static func configureTextView(_ textView: NSTextView, capabilities: PlatformCapabilities? = nil) {
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        // Basic configuration that works across all versions
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        // macOS version-specific optimizations
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            configureForModernMacOS(textView)
        } else if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 13 {
            configureForMacOS13(textView)
        } else {
            configureForLegacyMacOS(textView)
        }

        if supportsRequiredTextKit2Surface {
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
    /// - Parameter capabilities: Platform capabilities (defaults to dependency factory)
    static func recommendedControlSize(capabilities: PlatformCapabilities? = nil) -> NSControl.ControlSize {
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        // Use platform capabilities to determine appropriate size
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            return .regular
        } else {
            return .small
        }
    }

    // MARK: - Performance Optimizations

    /// Apply performance optimizations based on system capabilities
    package static func applyPerformanceOptimizations(to textView: NSTextView) {
        // Disable expensive features during editing
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        // Skip layout manager configuration that would bypass the required TextKit2 surface.
        // TextKit2 handles these optimizations automatically

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
    package static var supportsRequiredTextKit2Surface: Bool { true }

    static func validatesRequiredTextKit2Surface(for _: Any) -> Bool { true }

    static func validateRequiredTextKit2Surface(for _: Any) -> Bool { true }
}

#endif
