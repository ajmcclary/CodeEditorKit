import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Comprehensive configuration system for customizing code editor behavior and appearance.
///
/// `EditorConfiguration` provides a structured, type-safe way to configure all aspects of the code editor.
/// The configuration is organized into four main categories:
///
/// - **Layout**: Text formatting, spacing, and visual layout
/// - **Display**: Visual elements like syntax highlighting, line numbers, and annotations
/// - **Behavior**: Editing behavior, auto-completion, and text processing
/// - **Performance**: Optimization settings and resource limits
///
/// ## Basic Usage
///
/// ```swift
/// var config = EditorConfiguration()
/// config.display.fontSize = 16
/// config.display.syntaxHighlighting = true
/// config.layout.tabWidth = 4
/// config.behavior.autoIndent = true
/// 
/// // Apply to an editor
/// config.apply(to: editor)
/// ```
///
/// ## Preset Configurations
///
/// Use built-in presets for common scenarios:
///
/// ```swift
/// let readOnly = EditorConfiguration.readOnly        // For display-only
/// let minimal = EditorConfiguration.minimal          // Lightweight editing
/// let markdown = EditorConfiguration.markdown        // Markdown optimized
/// let presentation = EditorConfiguration.presentation // Presentation mode
/// ```
///
/// ## Immutable Updates
///
/// Use the `with()` methods for immutable configuration updates:
///
/// ```swift
/// let newConfig = config.with(display: modifiedDisplay)
///                      .with(layout: modifiedLayout)
/// ```
///
/// ## Builder Pattern
///
/// Use `EditorConfigurationBuilder` for fluent configuration:
///
/// ```swift
/// let config = EditorConfigurationBuilder()
///     .showLineNumbers(true)
///     .fontSize(16)
///     .tabWidth(4)
///     .wrapLines(false)
///     .build()
/// ```
///
/// ## Validation
///
/// Validate configuration before applying:
///
/// ```swift
/// let errors = config.validate()
/// if errors.isEmpty {
///     config.apply(to: editor)
/// } else {
///     // Handle configuration errors appropriately
///     logger.error("Configuration errors: \(errors)")
/// }
/// 
/// // Or throw on validation failure
/// try config.validateAndThrow()
/// ```
///
/// ## Performance Considerations
///
/// - Large `maxHighlightingLength` values may impact performance
/// - Hardware acceleration is enabled by default when available
/// - Adjust `textChangeDebounceInterval` for responsive vs. efficient highlighting
/// - Use read-only presets for display scenarios to optimize performance
public struct EditorConfiguration: Equatable, Codable, Sendable {
    // MARK: - Nested Configuration Structures
    
    /// Layout-related configuration
    public struct Layout: Equatable, Codable, Sendable {
        /// Tab width in spaces
        public var tabWidth: Int = 4
        
        /// Whether to insert spaces instead of tabs
        public var insertSpacesForTabs: Bool = true
        
        /// Line spacing multiplier
        public var lineSpacing: CGFloat = 1.2
        
        /// Whether to wrap long lines
        public var wrapLines: Bool = false
        
        /// Gutter width for line numbers
        public var gutterWidth: CGFloat = 60.0
        
        /// Padding for line numbers within the gutter
        public var lineNumberPadding: CGFloat = 8.0
        
        /// Size of annotation badges
        public var annotationBadgeSize: CGFloat = 16.0
        
        /// Padding around annotation badges
        public var annotationBadgePadding: CGFloat = 4.0
        
        /// Width of the minimap view
        public var minimapWidth: CGFloat = 120.0
        
        public init() {}
    }
    
    /// Display-related configuration
    public struct Display: Equatable, Codable, Sendable {
        /// Whether to show line numbers in the gutter
        public var showLineNumbers: Bool = true
        
        /// Whether to highlight the current line
        public var highlightSelectedLine: Bool = true
        
        /// Whether to show invisible characters (spaces, tabs, newlines)
        public var showInvisibleCharacters: Bool = false
        
        /// Font size for the editor text
        public var fontSize: CGFloat = 14.0
        
        /// Whether to enable syntax highlighting
        public var enableSyntaxHighlighting: Bool = true
        
        /// Shorter alias for enableSyntaxHighlighting
        public var syntaxHighlighting: Bool {
            get { enableSyntaxHighlighting }
            set { enableSyntaxHighlighting = newValue }
        }
        
        /// Whether to enable the annotation system
        public var enableAnnotations: Bool = true
        
        /// Shorter alias for enableAnnotations
        public var annotations: Bool {
            get { enableAnnotations }
            set { enableAnnotations = newValue }
        }
        
        /// Whether to show indent guides
        public var showIndentGuides: Bool = true
        
        /// Whether to show the minimap
        public var showMinimap: Bool = false
        
        public init() {}
    }
    
    /// Behavior-related configuration
    public struct Behavior: Equatable, Codable, Sendable {
        /// Whether the editor is editable
        public var isEditable: Bool = true
        
        /// Whether text is selectable
        public var isSelectable: Bool = true
        
        /// Whether to auto-indent new lines
        public var autoIndent: Bool = true
        
        /// Whether to automatically close brackets
        public var autoCloseBrackets: Bool = true
        
        /// Whether to automatically close quotes
        public var autoCloseQuotes: Bool = true
        
        /// Whether to enable code completion
        public var enableCodeCompletion: Bool = true
        
        /// Shorter alias for enableCodeCompletion
        public var codeCompletion: Bool {
            get { enableCodeCompletion }
            set { enableCodeCompletion = newValue }
        }
        
        /// Whether to enable continuous spell checking
        public var isContinuousSpellCheckingEnabled: Bool = false
        
        /// Whether to enable grammar checking
        public var isGrammarCheckingEnabled: Bool = false
        
        /// Whether to enable automatic quote substitution
        public var isAutomaticQuoteSubstitutionEnabled: Bool = false
        
        /// Shorter alias for isAutomaticQuoteSubstitutionEnabled
        public var autoQuoteSubstitution: Bool {
            get { isAutomaticQuoteSubstitutionEnabled }
            set { isAutomaticQuoteSubstitutionEnabled = newValue }
        }
        
        /// Whether to enable automatic dash substitution
        public var isAutomaticDashSubstitutionEnabled: Bool = false
        
        /// Whether to enable automatic text replacement
        public var isAutomaticTextReplacementEnabled: Bool = false
        
        /// Whether to enable automatic spelling correction
        public var isAutomaticSpellingCorrectionEnabled: Bool = false
        
        /// Whether to enable automatic text completion
        public var isAutomaticTextCompletionEnabled: Bool = false
        
        public init() {}
    }
    
    /// Performance-related configuration
    public struct Performance: Equatable, Codable, Sendable {
        /// Maximum file size for syntax highlighting (in bytes)
        public var maxSyntaxHighlightingLength: Int = 500_000
        
        /// Shorter alias for maxSyntaxHighlightingLength
        public var maxHighlightingLength: Int {
            get { maxSyntaxHighlightingLength }
            set { maxSyntaxHighlightingLength = newValue }
        }
        
        /// Whether to use hardware acceleration
        public var useHardwareAcceleration: Bool = true
        
        /// Whether to enable smooth scrolling
        public var smoothScrolling: Bool = true
        
        /// Debounce interval for text changes (in seconds)
        public var textChangeDebounceInterval: TimeInterval = 0.1
        
        public init() {}
    }
    
    // MARK: - Configuration Properties
    
    /// Layout configuration
    public var layout = Layout()
    
    /// Display configuration
    public var display = Display()
    
    /// Behavior configuration
    public var behavior = Behavior()
    
    /// Performance configuration
    public var performance = Performance()
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(layout: Layout = Layout(), display: Display = Display(), behavior: Behavior = Behavior(), performance: Performance = Performance()) {
        self.layout = layout
        self.display = display
        self.behavior = behavior
        self.performance = performance
    }
    
    // MARK: - Convenience Methods
    
    /// Create a new configuration with updated layout
    public func with(layout: Layout) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    /// Create a new configuration with updated display
    public func with(display: Display) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    /// Create a new configuration with updated behavior
    public func with(behavior: Behavior) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    /// Create a new configuration with updated performance
    public func with(performance: Performance) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance)
    }
    
    // MARK: - Presets
    
    /// Default configuration for general code editing
    public static let `default` = Self()
    
    /// Minimal configuration for simple text editing
    public static let minimal: EditorConfiguration = {
        var display = Display()
        display.showLineNumbers = false
        display.highlightSelectedLine = false
        display.enableSyntaxHighlighting = false
        display.enableAnnotations = false
        display.showIndentGuides = false
        
        var behavior = Behavior()
        behavior.enableCodeCompletion = false
        
        return Self(display: display, behavior: behavior)
    }()
    
    /// Read-only configuration for viewing code
    public static let readOnly: EditorConfiguration = {
        var behavior = Behavior()
        behavior.isEditable = false
        behavior.enableCodeCompletion = false
        behavior.isContinuousSpellCheckingEnabled = false
        behavior.isGrammarCheckingEnabled = false
        
        return Self(behavior: behavior)
    }()
    
    /// Performance-optimized configuration for large files
    public static let performance: EditorConfiguration = {
        var display = Display()
        display.showLineNumbers = false
        display.enableAnnotations = false
        
        var performance = Performance()
        performance.smoothScrolling = false
        performance.textChangeDebounceInterval = 0.3
        performance.maxSyntaxHighlightingLength = 100_000
        
        return Self(display: display, performance: performance)
    }()
    
    /// Presentation mode configuration
    public static let presentation: EditorConfiguration = {
        var display = Display()
        display.fontSize = 20.0
        display.highlightSelectedLine = true
        display.showInvisibleCharacters = false
        
        var layout = Layout()
        layout.lineSpacing = 1.5
        
        var behavior = Behavior()
        behavior.isEditable = false
        
        return Self(layout: layout, display: display, behavior: behavior)
    }()
    
    /// Markdown editing configuration
    public static let markdown: EditorConfiguration = {
        var display = Display()
        display.showLineNumbers = false
        
        var layout = Layout()
        layout.wrapLines = true
        
        var behavior = Behavior()
        behavior.isContinuousSpellCheckingEnabled = true
        behavior.autoIndent = true
        
        return Self(layout: layout, display: display, behavior: behavior)
    }()
    
    // MARK: - Validation
    
    /// Validate the configuration and return any validation errors
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate display settings
        if display.fontSize <= 0 {
            errors.append(ValidationError(field: "display.fontSize", value: display.fontSize, constraint: "must be greater than 0"))
        }
        if display.fontSize > 100 {
            errors.append(ValidationError(field: "display.fontSize", value: display.fontSize, constraint: "must be 100 or less"))
        }
        
        // Validate layout settings
        if layout.tabWidth <= 0 {
            errors.append(ValidationError(field: "layout.tabWidth", value: layout.tabWidth, constraint: "must be greater than 0"))
        }
        if layout.tabWidth > 32 {
            errors.append(ValidationError(field: "layout.tabWidth", value: layout.tabWidth, constraint: "must be 32 or less"))
        }
        
        if layout.lineSpacing < 0 {
            errors.append(ValidationError(field: "layout.lineSpacing", value: layout.lineSpacing, constraint: "must be 0 or greater"))
        }
        if layout.lineSpacing > 50 {
            errors.append(ValidationError(field: "layout.lineSpacing", value: layout.lineSpacing, constraint: "must be 50 or less"))
        }
        
        if layout.gutterWidth < 0 {
            errors.append(ValidationError(field: "layout.gutterWidth", value: layout.gutterWidth, constraint: "must be 0 or greater"))
        }
        
        // Validate performance settings
        if performance.maxSyntaxHighlightingLength < 0 {
            errors.append(ValidationError(field: "performance.maxSyntaxHighlightingLength", value: performance.maxSyntaxHighlightingLength, constraint: "must be 0 or greater"))
        }
        
        if performance.textChangeDebounceInterval < 0 {
            errors.append(ValidationError(field: "performance.textChangeDebounceInterval", value: performance.textChangeDebounceInterval, constraint: "must be 0 or greater"))
        }
        if performance.textChangeDebounceInterval > 5.0 {
            errors.append(ValidationError(field: "performance.textChangeDebounceInterval", value: performance.textChangeDebounceInterval, constraint: "must be 5 seconds or less"))
        }
        
        return errors
    }
    
    /// Validate the configuration and throw an error if invalid
    public func validateAndThrow() throws {
        let errors = validate()
        if !errors.isEmpty {
            throw CodeEditorError.configurationValidationFailed(errors)
        }
    }
    
    // MARK: - Configuration Application
    
    /// Apply configuration to a CodeEditorView
    @MainActor public func apply(to view: CodeEditorView) {
        // Only set configuration if it's different
        if view.configuration != self {
            // Set the view's configuration property which will trigger applyConfiguration()
            view.configuration = self
        }
        
        // Apply cross-platform text input features
        applyTextInputFeatures(to: view)
        
        // Also apply additional settings that aren't handled by the internal applyConfiguration
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.font = PlatformFonts.monospacedSystemFont(ofSize: display.fontSize, weight: .regular)
        view.textColor = PlatformColors.label
        
        if layout.wrapLines {
            view.textContainer?.widthTracksTextView = true
            view.isHorizontallyResizable = false
        } else {
            view.textContainer?.widthTracksTextView = false
            view.isHorizontallyResizable = true
        }
        #elseif canImport(UIKit)
        view.font = PlatformFonts.monospacedSystemFont(ofSize: display.fontSize, weight: .regular)
        view.textColor = PlatformColors.label
        #endif
    }
}

// MARK: - Configuration Builder

/// Builder pattern for creating configurations
public class EditorConfigurationBuilder {
    deinit {}
    
    private var configuration = EditorConfiguration()
    
    public init() {}
    
    public init(base: EditorConfiguration) {
        self.configuration = base
    }
    
    // Display
    public func showLineNumbers(_ show: Bool) -> Self {
        var display = configuration.display
        display.showLineNumbers = show
        configuration = configuration.with(display: display)
        return self
    }
    
    public func highlightSelectedLine(_ highlight: Bool) -> Self {
        var display = configuration.display
        display.highlightSelectedLine = highlight
        configuration = configuration.with(display: display)
        return self
    }
    
    public func showInvisibleCharacters(_ show: Bool) -> Self {
        var display = configuration.display
        display.showInvisibleCharacters = show
        configuration = configuration.with(display: display)
        return self
    }
    
    public func wrapLines(_ wrap: Bool) -> Self {
        var layout = configuration.layout
        layout.wrapLines = wrap
        configuration = configuration.with(layout: layout)
        return self
    }
    
    public func fontSize(_ size: CGFloat) -> Self {
        var display = configuration.display
        display.fontSize = size
        configuration = configuration.with(display: display)
        return self
    }
    
    public func lineSpacing(_ spacing: CGFloat) -> Self {
        var layout = configuration.layout
        layout.lineSpacing = spacing
        configuration = configuration.with(layout: layout)
        return self
    }
    
    // Behavior
    public func editable(_ editable: Bool) -> Self {
        var behavior = configuration.behavior
        behavior.isEditable = editable
        configuration = configuration.with(behavior: behavior)
        return self
    }
    
    public func autoIndent(_ auto: Bool) -> Self {
        var behavior = configuration.behavior
        behavior.autoIndent = auto
        configuration = configuration.with(behavior: behavior)
        return self
    }
    
    public func tabWidth(_ width: Int) -> Self {
        var layout = configuration.layout
        layout.tabWidth = width
        configuration = configuration.with(layout: layout)
        return self
    }
    
    public func insertSpacesForTabs(_ spaces: Bool) -> Self {
        var layout = configuration.layout
        layout.insertSpacesForTabs = spaces
        configuration = configuration.with(layout: layout)
        return self
    }
    
    // Performance
    public func maxSyntaxHighlightingLength(_ length: Int) -> Self {
        var performance = configuration.performance
        performance.maxSyntaxHighlightingLength = length
        configuration = configuration.with(performance: performance)
        return self
    }
    
    public func hardwareAcceleration(_ enable: Bool) -> Self {
        var performance = configuration.performance
        performance.useHardwareAcceleration = enable
        configuration = configuration.with(performance: performance)
        return self
    }
    
    public func smoothScrolling(_ smooth: Bool) -> Self {
        var performance = configuration.performance
        performance.smoothScrolling = smooth
        configuration = configuration.with(performance: performance)
        return self
    }
    
    // Features
    public func codeCompletion(_ enable: Bool) -> Self {
        var behavior = configuration.behavior
        behavior.enableCodeCompletion = enable
        configuration = configuration.with(behavior: behavior)
        return self
    }
    
    public func annotations(_ enable: Bool) -> Self {
        var display = configuration.display
        display.enableAnnotations = enable
        configuration = configuration.with(display: display)
        return self
    }
    
    public func syntaxHighlighting(_ enable: Bool) -> Self {
        var display = configuration.display
        display.enableSyntaxHighlighting = enable
        configuration = configuration.with(display: display)
        return self
    }
    
    // Build
    public func build() -> EditorConfiguration {
        configuration
    }
}
