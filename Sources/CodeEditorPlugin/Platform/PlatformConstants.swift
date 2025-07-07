import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Centralized platform-specific constants to reduce duplication across the codebase
public enum PlatformConstants {
    // MARK: - Font Constants
    
    /// Default monospaced font size
    public static let defaultFontSize: CGFloat = 14.0
    
    /// Minimum allowed font size
    public static let minimumFontSize: CGFloat = 8.0
    
    /// Maximum allowed font size
    public static let maximumFontSize: CGFloat = 72.0
    
    // MARK: - Layout Constants
    
    /// Default tab width in spaces
    public static let defaultTabWidth: Int = 4
    
    /// Default line height multiple
    public static let defaultLineHeightMultiple: CGFloat = 1.2
    
    /// Default gutter width
    public static let defaultGutterWidth: CGFloat = 50.0
    
    /// Default text container inset
    public static let defaultTextContainerInset = EdgeInsets(
        top: 8,
        left: 8,
        bottom: 8,
        right: 8
    )
    
    /// Default line number padding
    public static let defaultLineNumberPadding: CGFloat = 8.0
    
    /// Default annotation badge size
    public static let defaultAnnotationBadgeSize: CGFloat = 16.0
    
    /// Default annotation badge padding
    public static let defaultAnnotationBadgePadding: CGFloat = 4.0
    
    /// Default minimap width
    public static let defaultMinimapWidth: CGFloat = 100.0
    
    /// Default folding control size
    public static let defaultFoldingControlSize: CGFloat = 12.0
    
    /// Default folding control padding
    public static let defaultFoldingControlPadding: CGFloat = 4.0
    
    // MARK: - Performance Constants
    
    /// Maximum file size for syntax highlighting (characters)
    public static let maxSyntaxHighlightingLength: Int = 500_000
    
    /// Maximum visible lines to render
    public static let maxVisibleLines: Int = 1_000
    
    /// Default highlighting debounce interval (seconds)
    public static let defaultHighlightingDebounceInterval: TimeInterval = 0.1
    
    /// Default text change debounce interval (milliseconds)
    public static let defaultTextChangeDebounceInterval: Int = 100
    
    // MARK: - UI Constants
    
    /// Default number of visible lines
    public static let defaultVisibleLines: Int = 50
    
    /// Minimum foldable lines
    public static let minimumFoldableLines: Int = 3
    
    /// Maximum history size for configuration hot reload
    public static let maxConfigurationHistorySize: Int = 50
    
    /// Default animation duration (seconds)
    public static let defaultAnimationDuration: TimeInterval = 0.3
    
    // MARK: - Platform-Specific Values
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    
    /// Default cursor blink period (macOS)
    public static let cursorBlinkPeriod: TimeInterval = 0.5
    
    /// Default scroll elasticity
    public static let scrollElasticity: Bool = true
    
    #elseif canImport(UIKit)
    
    /// Default keyboard appearance
    public static let defaultKeyboardAppearance: UIKeyboardAppearance = .default
    
    /// Default autocorrection type
    public static let defaultAutocorrectionType: UITextAutocorrectionType = .no
    
    /// Default smart quotes type
    public static let defaultSmartQuotesType: UITextSmartQuotesType = .no
    
    #endif
    
    // MARK: - Validation Constants
    
    /// Valid font size range
    public static let validFontSizeRange: ClosedRange<CGFloat> = minimumFontSize...maximumFontSize
    
    /// Valid tab width range
    public static let validTabWidthRange: ClosedRange<Int> = 1...16
    
    /// Valid line height multiple range
    public static let validLineHeightMultipleRange: ClosedRange<CGFloat> = 0.5...3.0
}
