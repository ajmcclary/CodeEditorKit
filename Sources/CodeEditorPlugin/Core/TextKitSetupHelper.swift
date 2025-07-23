import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Helper class for setting up TextKit components and configuration
///
/// This class centralizes the complex TextKit initialization logic, making it
/// easier to maintain and test. It handles:
/// - TextKit version detection and setup
/// - Platform-specific configuration
/// - Performance optimizations
/// - Container configuration
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

        /// Whether to force TextKit2 if available
        public var preferTextKit2: Bool = true

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
        /// Whether TextKit2 is being used
        public let isUsingTextKit2: Bool

        /// The text container that was configured
        public let textContainer: NSTextContainer?

        /// Any warnings or notes about the setup
        public let notes: [String]
    }

    // MARK: - Main Setup Method

    /// Sets up TextKit for the given text view
    /// - Parameters:
    ///   - textView: The text view to configure
    ///   - options: Setup options
    /// - Returns: Setup result with information about the configuration
    public static func setupTextKit(
        for textView: CodeEditorView,
        options: SetupOptions = .codeEditing
    ) -> SetupResult {
        var notes: [String] = []

        // Detect TextKit version
        let isUsingTextKit2 = detectTextKitVersion(for: textView)
        if isUsingTextKit2 {
            notes.append("Using TextKit2")
        } else {
            notes.append("Using TextKit1")
        }

        // Apply platform-specific configuration
        applyPlatformConfiguration(to: textView, options: options)

        // Configure text container
        let textContainer = configureTextContainer(for: textView, options: options)

        // Apply performance optimizations
        if options.applyPerformanceOptimizations {
            applyPerformanceOptimizations(to: textView, isUsingTextKit2: isUsingTextKit2)
            notes.append("Applied performance optimizations")
        }

        // Set up delegate only if not already set by container
        if textView.delegate == nil {
            textView.delegate = textView.delegateProxy
        }

        // Set up notifications
        setupNotifications(for: textView)

        return SetupResult(
            isUsingTextKit2: isUsingTextKit2,
            textContainer: textContainer,
            notes: notes
        )
    }

    // MARK: - TextKit Version Detection

    /// Detects which version of TextKit is being used
    private static func detectTextKitVersion(for textView: CodeEditorView) -> Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Check if TextKit2 is available and being used
        if textView.textLayoutManager != nil {
            return true
        }

        // Try to ensure TextKit2 if preferred
        if ModernTextKitHelper.shouldUseTextKit2 {
            _ = ModernTextKitHelper.ensureTextKit2(for: textView)
            return textView.textLayoutManager != nil
        }

        return false
        #elseif targetEnvironment(macCatalyst)
        // Mac Catalyst: Check for TextKit2 using runtime detection
        // UITextView on Mac Catalyst can use TextKit2 starting from iOS 16
        if #available(iOS 16.0, *) {
            // TextKit2 is available on Mac Catalyst starting from iOS 16
            // We'll prefer TextKit2 for better performance and features
            return true
        }
        return false
        #else
        // iOS doesn't expose TextKit2 APIs directly
        return false
        #endif
    }

    // MARK: - Platform Configuration

    /// Applies platform-specific configuration
    private static func applyPlatformConfiguration(
        to textView: CodeEditorView,
        options: SetupOptions
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textContainer = textView.textContainer else { return nil }

        // Container configuration
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 4.0

        return textContainer

        #elseif targetEnvironment(macCatalyst)
        let textContainer = textView.textContainer

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

    /// Applies performance optimizations based on platform and TextKit version
    private static func applyPerformanceOptimizations(
        to textView: CodeEditorView,
        isUsingTextKit2: Bool
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Enable hardware acceleration
        if let scrollView = textView.enclosingScrollView {
            scrollView.wantsLayer = true
            scrollView.canDrawSubviewsIntoLayer = true
        }
        textView.wantsLayer = true

        // Apply TextKit-specific optimizations
        if isUsingTextKit2 {
            applyTextKit2Optimizations(to: textView)
        } else {
            applyTextKit1Optimizations(to: textView)
        }

        // Use ModernTextKitHelper for additional optimizations
        ModernTextKitHelper.applyPerformanceOptimizations(to: textView)

        #elseif targetEnvironment(macCatalyst)
        // Mac Catalyst specific optimizations
        // Avoid certain optimizations that interfere with text rendering
        textView.layer.shouldRasterize = false

        // For TextKit1 on Mac Catalyst, we need special handling
        if !isUsingTextKit2 {
            // Force proper text rendering by disabling some optimizations
            textView.layer.drawsAsynchronously = false

            // Ensure text attributes are preserved
            textView.allowsEditingTextAttributes = true
        }

        #else
        // iOS performance optimizations
        textView.layer.shouldRasterize = false
        textView.layer.rasterizationScale = UIScreen.main.scale
        #endif
    }

    /// Applies TextKit2-specific optimizations
    private static func applyTextKit2Optimizations(to textView: CodeEditorView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

    /// Applies TextKit1-specific optimizations
    private static func applyTextKit1Optimizations(to textView: CodeEditorView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // TextKit1 optimizations
        textView.layoutManager?.allowsNonContiguousLayout = true
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

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.removeObserver(
            textView,
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
        #endif
    }
}
