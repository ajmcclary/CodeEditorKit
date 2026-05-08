import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Helper class for setting up TextKit2 components and configuration.
///
/// As of 0.2.0 the framework is TextKit2-only. The helper still centralizes
/// the platform-specific `NSTextView`/`UITextView` configuration (auto-correction,
/// scroll-view setup, layer flags, container sizing) but no longer chooses
/// between TextKit1 and TextKit2.
@MainActor
public enum TextKitSetupHelper {
    // MARK: - Configuration Structures

    /// Configuration options for TextKit setup
    public struct SetupOptions: Sendable {
        /// Whether to enable automatic text replacements
        public var enableAutomaticReplacements: Bool = false

        /// Whether to enable spell checking
        public var enableSpellChecking: Bool = false

        /// Whether to enable undo/redo
        public var enableUndo: Bool = true

        /// Whether to apply performance optimizations
        public var applyPerformanceOptimizations: Bool = true

        /// Default configuration for code editing
        public static let codeEditing = Self()

        /// Configuration for plain text editing
        public static let plainText = Self(
            enableAutomaticReplacements: true,
            enableSpellChecking: true
        )
    }

    /// Result of TextKit setup
    public struct SetupResult {
        /// The text container that was configured
        public let textContainer: NSTextContainer?

        /// Any warnings or notes about the setup
        public let notes: [String]
    }

    // MARK: - Main Setup Method

    /// Sets up TextKit2 for the given text view.
    /// - Parameters:
    ///   - textView: The text view to configure.
    ///   - options: Setup options.
    /// - Returns: Setup result with information about the configuration.
    public static func setupTextKit(
        for textView: CodeEditorView,
        options: SetupOptions = .codeEditing
    ) -> SetupResult {
        var notes: [String] = []
        notes.append("Using TextKit2")

        applyPlatformConfiguration(to: textView, options: options)
        let textContainer = configureTextContainer(for: textView, options: options)

        if options.applyPerformanceOptimizations {
            applyPerformanceOptimizations(to: textView)
            notes.append("Applied performance optimizations")
        }

        if textView.delegate == nil {
            textView.delegate = textView.delegateProxy
        }

        setupNotifications(for: textView)

        return SetupResult(textContainer: textContainer, notes: notes)
    }

    // MARK: - Platform Configuration

    /// Applies platform-specific configuration
    private static func applyPlatformConfiguration(
        to textView: CodeEditorView,
        options: SetupOptions
    ) {
        #if canImport(AppKit)
        // macOS configuration
        textView.isAutomaticQuoteSubstitutionEnabled = options.enableAutomaticReplacements
        textView.isAutomaticDashSubstitutionEnabled = options.enableAutomaticReplacements
        textView.isAutomaticTextReplacementEnabled = options.enableAutomaticReplacements
        textView.isAutomaticSpellingCorrectionEnabled = options.enableSpellChecking
        textView.isContinuousSpellCheckingEnabled = options.enableSpellChecking
        textView.allowsUndo = options.enableUndo

        // Text view properties
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        #else
        // iOS/Catalyst configuration
        textView.autocorrectionType = options.enableSpellChecking ? .default : .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = options.enableSpellChecking ? .default : .no

        // Disable automatic content inset adjustments
        textView.contentInsetAdjustmentBehavior = .never
        #endif
    }

    // MARK: - Text Container Configuration

    /// Configures the text container for optimal performance
    private static func configureTextContainer(
        for textView: CodeEditorView,
        options _: SetupOptions
    ) -> NSTextContainer? {
        #if canImport(AppKit)
        guard let textContainer = textView.textContainer else { return nil }

        // Container configuration
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 4.0

        return textContainer

        #else
        // iOS doesn't expose text container configuration
        return nil
        #endif
    }

    // MARK: - Performance Optimizations

    /// Applies platform performance optimizations.
    private static func applyPerformanceOptimizations(to textView: CodeEditorView) {
        #if canImport(AppKit)
        if let scrollView = textView.enclosingScrollView {
            scrollView.wantsLayer = true
            scrollView.canDrawSubviewsIntoLayer = true
        }
        textView.wantsLayer = true

        applyTextKit2Optimizations(to: textView)

        // Use ModernTextKitHelper for additional optimizations
        ModernTextKitHelper.applyPerformanceOptimizations(to: textView)

        #else
        textView.layer.shouldRasterize = false
        textView.layer.rasterizationScale = UIKitScreenMetrics.scale(for: textView)
        #endif
    }

    /// Applies TextKit2-specific optimizations
    private static func applyTextKit2Optimizations(to textView: CodeEditorView) {
        #if canImport(AppKit)
        guard let textLayoutManager = textView.textLayoutManager else { return }

        // TextKit2 automatically handles viewport-based layout
        textLayoutManager.textViewportLayoutController.delegate = nil

        // Ensure non-contiguous layout for better performance
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }
        #endif
    }

    // MARK: - Notification Setup

    /// Sets up necessary notifications for text view events
    private static func setupNotifications(for textView: CodeEditorView) {
        let notificationCenter = NotificationCenter.default

        // Text storage notifications
        notificationCenter.addObserver(
            textView,
            selector: #selector(textView.handleTextStorageDidProcessEditing(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textView.textStorage
        )

        #if canImport(AppKit)
        // Selection change notification (macOS only)
        notificationCenter.addObserver(
            textView,
            selector: #selector(textView.handleTextViewDidChangeSelection(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        #endif
    }

    // MARK: - Cleanup

    /// Removes notification observers for the text view
    public static func cleanupNotifications(for textView: CodeEditorView) {
        NotificationCenter.default.removeObserver(
            textView,
            name: NSTextStorage.didProcessEditingNotification,
            object: textView.textStorage
        )

        #if canImport(AppKit)
        NotificationCenter.default.removeObserver(
            textView,
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        #endif
    }
}
