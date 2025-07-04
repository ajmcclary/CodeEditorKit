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
    
    /// Layout-related configuration.
    ///
    /// Controls the visual layout and spacing of the editor components including
    /// tab handling, line spacing, and gutter dimensions.
    public struct Layout: Equatable, Codable, Sendable {
        /// Tab width in spaces.
        ///
        /// Determines how many spaces a tab character represents when displayed.
        /// Common values are 2, 4, or 8 spaces.
        ///
        /// - Note: This affects display only. Use `insertSpacesForTabs` to control
        ///         whether pressing Tab inserts spaces or tab characters.
        public var tabWidth: Int = 4
        
        /// Whether to insert spaces instead of tabs.
        ///
        /// When `true`, pressing the Tab key inserts spaces equal to `tabWidth`.
        /// When `false`, pressing Tab inserts a tab character.
        ///
        /// - Important: Many modern coding standards recommend using spaces for
        ///              consistent formatting across different editors.
        public var insertSpacesForTabs: Bool = true
        
        /// Line spacing multiplier.
        ///
        /// Controls the vertical spacing between lines. A value of 1.0 provides
        /// minimal spacing, while higher values increase readability.
        ///
        /// - Note: Typical values range from 1.2 to 1.5 for comfortable reading.
        public var lineSpacing: CGFloat = 1.2
        
        /// Whether to wrap long lines.
        ///
        /// When `true`, lines that exceed the visible width wrap to the next line.
        /// When `false`, horizontal scrolling is required to see long lines.
        ///
        /// - Note: Code editors typically have wrapping disabled by default.
        public var wrapLines: Bool = false
        
        /// Gutter width for line numbers.
        ///
        /// The total width of the gutter area where line numbers are displayed.
        /// Adjust this if you need to display large line numbers (e.g., files with
        /// more than 9999 lines).
        public var gutterWidth: CGFloat = 60.0
        
        /// Padding for line numbers within the gutter.
        ///
        /// The horizontal padding between the line numbers and the gutter edges.
        /// Affects the spacing and alignment of line numbers.
        public var lineNumberPadding: CGFloat = 8.0
        
        /// Size of annotation badges.
        ///
        /// The diameter of circular badges displayed for annotations like
        /// TODO, FIXME, and WARNING markers.
        public var annotationBadgeSize: CGFloat = 16.0
        
        /// Padding around annotation badges.
        ///
        /// The spacing between annotation badges and surrounding elements.
        /// Affects the visual density of annotations in the gutter.
        public var annotationBadgePadding: CGFloat = 4.0
        
        /// Width of the minimap view.
        ///
        /// The width of the code minimap shown on the right side of the editor.
        /// The minimap provides a zoomed-out view of the entire file.
        ///
        /// - Note: Only applies when `display.showMinimap` is `true`.
        public var minimapWidth: CGFloat = 120.0
        
        /// Size of fold/unfold control buttons in the gutter.
        ///
        /// The diameter of the circular fold/unfold buttons (▶️/▼) displayed
        /// in the gutter next to foldable code regions.
        ///
        /// - Note: Only applies when `display.showFoldingControls` is `true`.
        public var foldingControlSize: CGFloat = 14.0
        
        /// Padding around folding control buttons.
        ///
        /// The spacing between folding control buttons and surrounding elements
        /// in the gutter. Affects the visual density of folding controls.
        public var foldingControlPadding: CGFloat = 2.0
        
        public init() {}
    }
    
    /// Display-related configuration.
    ///
    /// Controls visual elements like line numbers, syntax highlighting,
    /// and editor annotations.
    public struct Display: Equatable, Codable, Sendable {
        /// Whether to show line numbers in the gutter.
        ///
        /// When enabled, displays line numbers in the left gutter area.
        /// Line numbers help with navigation and debugging.
        public var showLineNumbers: Bool = true
        
        /// Whether to highlight the current line.
        ///
        /// When enabled, the line containing the cursor is highlighted
        /// with a subtle background color to improve focus.
        public var highlightSelectedLine: Bool = true
        
        /// Whether to show invisible characters (spaces, tabs, newlines).
        ///
        /// When enabled, displays visual representations of whitespace:
        /// - Spaces appear as dots (·)
        /// - Tabs appear as arrows (→)
        /// - Newlines appear as paragraph marks (¶)
        public var showInvisibleCharacters: Bool = false
        
        /// Font size for the editor text.
        ///
        /// The point size of the monospaced font used in the editor.
        /// Common values range from 11 to 18 points.
        ///
        /// - Note: The editor uses the system's default monospaced font.
        public var fontSize: CGFloat = 14.0
        
        /// Whether to enable syntax highlighting.
        ///
        /// When enabled, code is colored based on syntax tokens like
        /// keywords, strings, comments, and types. Supports 17+ languages.
        ///
        /// - Note: Disable for better performance with very large files.
        public var enableSyntaxHighlighting: Bool = true
        
        /// Shorter alias for enableSyntaxHighlighting
        public var syntaxHighlighting: Bool {
            get { enableSyntaxHighlighting }
            set { enableSyntaxHighlighting = newValue }
        }
        
        /// Whether to enable the annotation system.
        ///
        /// When enabled, displays badges for TODO, FIXME, NOTE, WARNING,
        /// and ERROR comments found in the code.
        public var enableAnnotations: Bool = true
        
        /// Shorter alias for enableAnnotations
        public var annotations: Bool {
            get { enableAnnotations }
            set { enableAnnotations = newValue }
        }
        
        /// Whether to show indent guides.
        ///
        /// When enabled, displays vertical lines at each indentation level
        /// to help visualize code structure and nesting.
        public var showIndentGuides: Bool = true
        
        /// Whether to show the minimap.
        ///
        /// When enabled, displays a zoomed-out view of the entire file
        /// on the right side for quick navigation.
        ///
        /// - Note: Useful for navigating large files but consumes screen space.
        public var showMinimap: Bool = false
        
        /// Whether to enable code folding.
        ///
        /// When enabled, allows collapsing and expanding code sections
        /// like functions, classes, blocks, and comments for better navigation.
        /// Supports 17+ programming languages with language-specific folding.
        public var enableCodeFolding: Bool = true
        
        /// Shorter alias for enableCodeFolding
        public var codeFolding: Bool {
            get { enableCodeFolding }
            set { enableCodeFolding = newValue }
        }
        
        /// Whether to show folding controls in the gutter.
        ///
        /// When enabled, displays ▶️/▼ fold/unfold buttons in the gutter
        /// next to foldable code regions. Allows interactive folding control.
        public var showFoldingControls: Bool = false
        
        /// Minimum number of lines required for a foldable region.
        ///
        /// Code sections with fewer lines than this threshold will not
        /// be considered foldable. Prevents folding of very small blocks.
        ///
        /// - Note: Typical values range from 2 to 5 lines.
        public var minimumFoldableLines: Int = 3
        
        public init() {}
    }
    
    /// Behavior-related configuration.
    ///
    /// Controls editor behavior including editing capabilities, auto-completion,
    /// and text processing features.
    public struct Behavior: Equatable, Codable, Sendable {
        /// Whether the editor is editable.
        ///
        /// When `false`, the editor becomes read-only and users cannot
        /// modify the content. Useful for displaying code without allowing edits.
        public var isEditable: Bool = true
        
        /// Whether text is selectable.
        ///
        /// When `false`, users cannot select text in the editor.
        /// This is independent of `isEditable` - text can be selectable but not editable.
        public var isSelectable: Bool = true
        
        /// Whether to auto-indent new lines.
        ///
        /// When enabled, pressing Enter maintains the indentation level
        /// of the previous line and adds appropriate indentation after
        /// opening braces or similar constructs.
        public var autoIndent: Bool = true
        
        /// Whether to automatically close brackets.
        ///
        /// When enabled, typing an opening bracket ([, {, or () automatically
        /// inserts the corresponding closing bracket and positions the cursor
        /// between them.
        public var autoCloseBrackets: Bool = true
        
        /// Whether to automatically close quotes.
        ///
        /// When enabled, typing a quote (" or ') automatically inserts
        /// the matching closing quote and positions the cursor between them.
        public var autoCloseQuotes: Bool = true
        
        /// Whether to enable code completion.
        ///
        /// When enabled, the editor shows completion suggestions as you type.
        /// Supports language-specific completions and LSP integration.
        ///
        /// - SeeAlso: ``CodeEditorView/requestCompletion(triggerKind:triggerCharacter:)``
        public var enableCodeCompletion: Bool = true
        
        /// Shorter alias for enableCodeCompletion
        public var codeCompletion: Bool {
            get { enableCodeCompletion }
            set { enableCodeCompletion = newValue }
        }
        
        /// Whether to enable continuous spell checking.
        ///
        /// When enabled, misspelled words are underlined with a red squiggle.
        /// Typically disabled in code editors to avoid false positives.
        public var isContinuousSpellCheckingEnabled: Bool = false
        
        /// Whether to enable grammar checking.
        ///
        /// When enabled, grammatical errors are highlighted.
        /// Usually disabled in code editors as code syntax differs from natural language.
        public var isGrammarCheckingEnabled: Bool = false
        
        /// Whether to enable automatic quote substitution.
        ///
        /// When enabled, straight quotes are replaced with curly quotes.
        /// Should be disabled for code editors to preserve literal string syntax.
        public var isAutomaticQuoteSubstitutionEnabled: Bool = false
        
        /// Shorter alias for isAutomaticQuoteSubstitutionEnabled
        public var autoQuoteSubstitution: Bool {
            get { isAutomaticQuoteSubstitutionEnabled }
            set { isAutomaticQuoteSubstitutionEnabled = newValue }
        }
        
        /// Whether to enable automatic dash substitution.
        ///
        /// When enabled, double hyphens (--) are replaced with em dashes.
        /// Should be disabled for code editors to preserve operators and comments.
        public var isAutomaticDashSubstitutionEnabled: Bool = false
        
        /// Whether to enable automatic text replacement.
        ///
        /// When enabled, system-wide text replacements are applied.
        /// Should be disabled for code editors to preserve exact syntax.
        public var isAutomaticTextReplacementEnabled: Bool = false
        
        /// Whether to enable automatic spelling correction.
        ///
        /// When enabled, misspelled words are automatically corrected.
        /// Should be disabled for code editors to preserve variable names and syntax.
        public var isAutomaticSpellingCorrectionEnabled: Bool = false
        
        /// Whether to enable automatic text completion.
        ///
        /// When enabled, the system suggests completions for common words.
        /// Different from code completion - this is for natural language.
        ///
        /// - Note: Usually disabled in favor of language-specific code completion.
        public var isAutomaticTextCompletionEnabled: Bool = false
        
        /// Whether to automatically scroll to cursor position.
        ///
        /// When enabled, the editor automatically scrolls to make the cursor
        /// visible when navigating to a specific line or position (e.g., via
        /// minimap clicks, symbol navigation, or search results).
        ///
        /// When disabled, navigation actions will move the cursor but won't
        /// automatically scroll the view.
        ///
        /// - Note: This does not affect manual scrolling or cursor movement.
        public var autoScrollToCursor: Bool = false
        
        public init() {}
    }
    
    /// Performance-related configuration.
    ///
    /// Controls performance optimizations and resource limits to ensure
    /// smooth operation with large files.
    public struct Performance: Equatable, Codable, Sendable {
        /// Maximum file size for syntax highlighting (in bytes).
        ///
        /// Files larger than this limit will not have syntax highlighting applied
        /// to prevent performance degradation. Default is 500KB.
        ///
        /// - Note: Set to 0 to disable the limit (not recommended for production).
        public var maxSyntaxHighlightingLength: Int = 500_000
        
        /// Shorter alias for maxSyntaxHighlightingLength
        public var maxHighlightingLength: Int {
            get { maxSyntaxHighlightingLength }
            set { maxSyntaxHighlightingLength = newValue }
        }
        
        /// Whether to use hardware acceleration.
        ///
        /// When enabled, leverages GPU acceleration for rendering when available.
        /// This can significantly improve scrolling and rendering performance.
        ///
        /// - Note: Disable if experiencing rendering issues on older hardware.
        public var useHardwareAcceleration: Bool = true
        
        /// Whether to enable smooth scrolling.
        ///
        /// When enabled, scrolling animations are interpolated for a smoother
        /// visual experience. May impact performance on slower systems.
        public var smoothScrolling: Bool = true
        
        /// Debounce interval for text changes (in seconds).
        ///
        /// Delays processing of rapid text changes to improve performance.
        /// Syntax highlighting and other expensive operations wait for this
        /// duration of inactivity before processing.
        ///
        /// - Note: Lower values provide more responsive feedback but use more CPU.
        public var textChangeDebounceInterval: TimeInterval = 0.1
        
        /// Whether to animate code folding operations.
        ///
        /// When enabled, folding and unfolding operations are animated
        /// for a smoother visual experience. May impact performance on slower systems.
        ///
        /// - Note: Disable for better performance with very large files.
        public var animateCodeFolding: Bool = true
        
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
    
    /// Apply configuration to a CodeEditorView.
    ///
    /// Updates the editor view with all settings from this configuration.
    /// This method handles platform-specific differences and ensures all
    /// configuration options are properly applied.
    ///
    /// ## What Gets Applied
    ///
    /// - Display settings (font size, line numbers, syntax highlighting)
    /// - Layout settings (tab width, line spacing, gutter width)
    /// - Behavior settings (editability, auto-indent, completion)
    /// - Performance settings (hardware acceleration, debouncing)
    /// - Platform-specific text input features
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfiguration.minimal
    /// config.apply(to: editorView)
    /// 
    /// // Or apply directly via the property
    /// editorView.configuration = config
    /// ```
    ///
    /// - Parameter view: The CodeEditorView to configure
    ///
    /// - Note: Setting the view's `configuration` property directly also
    ///         triggers this method internally.
    ///
    /// - SeeAlso: ``CodeEditorView/configuration``
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
    
    /// Create a CodeFoldingConfiguration from this EditorConfiguration.
    ///
    /// Maps the code folding settings from this EditorConfiguration to a
    /// CodeFoldingConfiguration that can be used by the CodeFoldingEngine.
    ///
    /// - Returns: A configured CodeFoldingConfiguration instance
    public func createCodeFoldingConfiguration() -> CodeFoldingConfiguration {
        var config = CodeFoldingConfiguration()
        config.enabled = display.enableCodeFolding
        config.showGutterControls = display.showFoldingControls
        config.minimumLineCount = display.minimumFoldableLines
        config.animatesFolding = performance.animateCodeFolding
        return config
    }
}
