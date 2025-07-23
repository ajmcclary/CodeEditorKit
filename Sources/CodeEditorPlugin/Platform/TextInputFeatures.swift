import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Platform Abstraction for Text Input Features

/// Protocol defining cross-platform text input feature capabilities
public protocol TextInputFeatures: Sendable {
    /// Whether spell checking is supported on this platform
    var supportsSpellChecking: Bool { get }

    /// Whether grammar checking is supported on this platform
    var supportsGrammarChecking: Bool { get }

    /// Whether smart quotes substitution is supported
    var supportsSmartQuotes: Bool { get }

    /// Whether smart dashes substitution is supported
    var supportsSmartDashes: Bool { get }

    /// Whether text replacement is supported
    var supportsTextReplacement: Bool { get }

    /// Whether automatic spelling correction is supported
    var supportsAutomaticSpellingCorrection: Bool { get }

    /// Whether automatic text completion is supported
    var supportsAutomaticTextCompletion: Bool { get }

    /// Apply text input features to a text view
    @MainActor func apply(to textView: any TextInputFeatureTarget, configuration: EditorConfiguration.Behavior)
}

/// Protocol that text views must implement to support cross-platform text input features
@MainActor public protocol TextInputFeatureTarget: AnyObject {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    var nsTextView: NSTextView? { get }
    #endif
    #if canImport(UIKit)
    var uiTextView: UITextView? { get }
    #endif
}

// MARK: - Platform-Specific Implementations

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
/// AppKit implementation of text input features
public struct AppKitTextInputFeatures: TextInputFeatures {
    public let supportsSpellChecking = true
    public let supportsGrammarChecking = true
    public let supportsSmartQuotes = true
    public let supportsSmartDashes = true
    public let supportsTextReplacement = true
    public let supportsAutomaticSpellingCorrection = true
    public let supportsAutomaticTextCompletion = true

    public init() {}

    @MainActor public func apply(to textView: any TextInputFeatureTarget, configuration: EditorConfiguration.Behavior) {
        guard let nsTextView = textView.nsTextView else { return }

        // Spell checking
        nsTextView.isContinuousSpellCheckingEnabled = configuration.isContinuousSpellCheckingEnabled

        // Grammar checking
        nsTextView.isGrammarCheckingEnabled = configuration.isGrammarCheckingEnabled

        // Smart quotes and dashes
        nsTextView.isAutomaticQuoteSubstitutionEnabled = configuration.isAutomaticQuoteSubstitutionEnabled
        nsTextView.isAutomaticDashSubstitutionEnabled = configuration.isAutomaticDashSubstitutionEnabled

        // Text replacement
        nsTextView.isAutomaticTextReplacementEnabled = configuration.isAutomaticTextReplacementEnabled

        // Spelling correction
        nsTextView.isAutomaticSpellingCorrectionEnabled = configuration.isAutomaticSpellingCorrectionEnabled

        // Text completion
        nsTextView.isAutomaticTextCompletionEnabled = configuration.isAutomaticTextCompletionEnabled
    }
}

/// Platform-specific text input features implementation for the current platform
/// 
/// On macOS, this resolves to `AppKitTextInputFeatures` which provides full
/// support for spelling, grammar checking, smart quotes, and text replacement.
public typealias PlatformTextInputFeatures = AppKitTextInputFeatures

#elseif canImport(UIKit)
/// UIKit implementation of text input features
public struct UIKitTextInputFeatures: TextInputFeatures {
    public let supportsSpellChecking = true
    public let supportsGrammarChecking = false // UIKit doesn't have native grammar checking
    public let supportsSmartQuotes = true
    public let supportsSmartDashes = true
    public let supportsTextReplacement = false // Would need custom implementation
    public let supportsAutomaticSpellingCorrection = true
    public let supportsAutomaticTextCompletion = false // Would need custom implementation

    public init() {}

    @MainActor public func apply(to textView: any TextInputFeatureTarget, configuration: EditorConfiguration.Behavior) {
        guard let uiTextView = textView.uiTextView else { return }

        // Spell checking
        uiTextView.spellCheckingType = configuration.isContinuousSpellCheckingEnabled ? .yes : .no

        // Grammar checking - not supported in UIKit
        // configuration.isGrammarCheckingEnabled is ignored

        // Smart quotes and dashes
        uiTextView.smartQuotesType = configuration.isAutomaticQuoteSubstitutionEnabled ? .yes : .no
        uiTextView.smartDashesType = configuration.isAutomaticDashSubstitutionEnabled ? .yes : .no

        // Text replacement - would need custom implementation
        // configuration.isAutomaticTextReplacementEnabled is ignored

        // Spelling correction
        uiTextView.autocorrectionType = configuration.isAutomaticSpellingCorrectionEnabled ? .yes : .no

        // Text completion - would need custom implementation
        // configuration.isAutomaticTextCompletionEnabled is ignored
    }
}

/// Platform-specific text input features implementation for the current platform
/// 
/// On iOS, this resolves to `UIKitTextInputFeatures` which provides support
/// for spelling correction and smart quotes, with limited grammar checking.
public typealias PlatformTextInputFeatures = UIKitTextInputFeatures

#endif

// MARK: - Cross-Platform Factory

/// Factory for creating platform-appropriate text input features
public enum TextInputFeaturesFactory {
    /// Create text input features appropriate for the current platform
    public static func create() -> any TextInputFeatures {
        PlatformTextInputFeatures()
    }
}

// MARK: - CodeEditorView Extensions

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    public var nsTextView: NSTextView? { self }

    #if canImport(UIKit)
    public var uiTextView: UITextView? { nil }
    #endif
}
#elseif canImport(UIKit)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var nsTextView: NSTextView? { nil }
    #endif

    public var uiTextView: UITextView? { self }
}
#endif

// MARK: - EditorConfiguration Integration

extension EditorConfiguration {
    /// Apply text input features using the platform abstraction
    @MainActor public func applyTextInputFeatures(to textView: any TextInputFeatureTarget) {
        let features = TextInputFeaturesFactory.create()
        features.apply(to: textView, configuration: behavior)
    }
}
