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
/// config.behavior.isAutoIndentEnabled = true
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
/// ## Direct Configuration
///
/// Mutate the nested configuration sections directly:
///
/// ```swift
/// var config = EditorConfiguration()
/// config.display.isLineNumbersEnabled = true
/// config.display.fontSize = 16
/// config.layout.tabWidth = 4
/// config.layout.wrapLines = false
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
///     print("Configuration errors: \(errors)")
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
public struct EditorConfiguration: Codable, Sendable {
    // MARK: - Nested Configuration Structures
    // See separate files:
    // - EditorConfiguration+Display.swift
    // - EditorConfiguration+Layout.swift
    // - EditorConfiguration+Behavior.swift  
    // - EditorConfiguration+Performance.swift

    // MARK: - Configuration Properties

    /// Layout configuration
    public var layout = Layout()

    /// Display configuration
    public var display = Display()

    /// Behavior configuration
    public var behavior = Behavior()

    /// Performance configuration
    public var performance = Performance()

    /// Event system for publishing and subscribing to editor events
    /// If nil, no events will be published
    public var eventSystem: UnifiedEventSystem?

    /// Actor coordinator for managing specialized actors
    /// If nil, a new instance will be created when needed
    @available(macOS 13.0, iOS 16.0, *)
    public var actorCoordinator: ActorCoordinator?

    /// Workspace root URL for LSP and file operations
    /// If set, enables language server protocol features with the specified workspace root
    public var workspaceRoot: URL?

    // MARK: - Injectable Dependencies
    //
    // These properties support dependency injection instead of singleton access.
    //
    // ## Isolation contract (Swift 6 strict concurrency)
    //
    // `EditorConfiguration` is a `Sendable` value type, but four of these
    // injection slots are `@MainActor`-isolated because the underlying
    // services touch UIKit / AppKit state (`PlatformCapabilities`,
    // `UnifiedPerformanceSystem`, `LanguageMetadataRegistry`,
    // `PlatformServiceLayer`). Reading or writing those properties from a
    // background actor will fail to compile under strict concurrency — that
    // is intentional. The expected usage pattern is:
    //
    //   1. Build a configuration from any actor context using
    //      `EditorConfiguration(layout:display:behavior:performance:)`
    //      (the non-`@MainActor` initializer).
    //   2. If you need to inject MainActor-bound services, switch to the
    //      `@MainActor public init(...)` overload (declared below) or
    //      assign the properties from a `@MainActor`-isolated context.
    //   3. `Codable` round-trips drop the four `@MainActor` slots and the
    //      `eventSystem` slot — they are treated as runtime-only injection
    //      points. See `init(from:)` and `encode(to:)` at the bottom of this
    //      file. Consumers persisting configuration to disk get the value
    //      types (`layout`, `display`, `behavior`, `performance`); they
    //      re-inject the live services after decoding.
    //
    // `paragraphStyleCache` is an actor-agnostic cache (its own internal
    // `DispatchQueue` provides thread-safety — see ParagraphStyleCache.swift)
    // so it does not require `@MainActor` isolation here.

    /// Platform capabilities provider.
    /// `@MainActor` because the underlying detection touches UIKit/AppKit.
    /// If nil, the configured dependency factory will be used.
    @MainActor public var platformCapabilities: PlatformCapabilities?

    /// Unified performance monitoring system.
    /// `@MainActor` because the system observes view-hierarchy events.
    /// If nil, the configured dependency factory will be used.
    @MainActor public var unifiedPerformanceSystem: UnifiedPerformanceSystem?

    /// Paragraph style cache for text rendering.
    /// Internally synchronized — safe to use from any actor.
    /// If nil, the configured dependency factory will be used.
    public var paragraphStyleCache: ParagraphStyleCache?

    /// Language metadata registry for completion and highlighting.
    /// `@MainActor` because the registry caches view-derived metrics.
    /// If nil, the configured dependency factory will be used.
    @MainActor public var languageMetadataRegistry: LanguageMetadataRegistry?

    /// Platform service layer for cross-platform operations.
    /// `@MainActor` because the layer dispatches to AppKit/UIKit services.
    /// If nil, the configured dependency factory will be used.
    @MainActor public var platformServiceLayer: PlatformServiceLayer?

    // MARK: - Initialization

    public init() {}

    public init(layout: Layout = Layout(), display: Display = Display(), behavior: Behavior = Behavior(), performance: Performance = Performance(), eventSystem: UnifiedEventSystem? = nil) {
        self.layout = layout
        self.display = display
        self.behavior = behavior
        self.performance = performance
        self.eventSystem = eventSystem
    }

    /// Full initializer with all injectable dependencies
    @MainActor
    public init(
        layout: Layout = Layout(),
        display: Display = Display(),
        behavior: Behavior = Behavior(),
        performance: Performance = Performance(),
        eventSystem: UnifiedEventSystem? = nil,
        platformCapabilities: PlatformCapabilities? = nil,
        unifiedPerformanceSystem: UnifiedPerformanceSystem? = nil,
        paragraphStyleCache: ParagraphStyleCache? = nil,
        languageMetadataRegistry: LanguageMetadataRegistry? = nil,
        platformServiceLayer: PlatformServiceLayer? = nil
    ) {
        self.layout = layout
        self.display = display
        self.behavior = behavior
        self.performance = performance
        self.eventSystem = eventSystem
        self.platformCapabilities = platformCapabilities
        self.unifiedPerformanceSystem = unifiedPerformanceSystem
        self.paragraphStyleCache = paragraphStyleCache
        self.languageMetadataRegistry = languageMetadataRegistry
        self.platformServiceLayer = platformServiceLayer
    }

    // MARK: - Convenience Methods

    /// Create a new configuration with updated layout
    public func with(layout: Layout) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance, eventSystem: eventSystem)
    }

    /// Create a new configuration with updated display
    public func with(display: Display) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance, eventSystem: eventSystem)
    }

    /// Create a new configuration with updated behavior
    public func with(behavior: Behavior) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance, eventSystem: eventSystem)
    }

    /// Create a new configuration with updated performance
    public func with(performance: Performance) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance, eventSystem: eventSystem)
    }

    /// Create a new configuration with updated event system
    public func with(eventSystem: UnifiedEventSystem?) -> Self {
        Self(layout: layout, display: display, behavior: behavior, performance: performance, eventSystem: eventSystem)
    }

    // MARK: - Validation

    /// Validate the configuration and return any validation errors
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Validate display settings
        if !PlatformConstants.validFontSizeRange.contains(display.fontSize) {
            errors.append(ValidationError(
                field: "display.fontSize",
                value: display.fontSize,
                constraint: "must be between \(PlatformConstants.validFontSizeRange.lowerBound) and \(PlatformConstants.validFontSizeRange.upperBound)"
            ))
        }

        // Validate layout settings
        if !PlatformConstants.validTabWidthRange.contains(layout.tabWidth) {
            errors.append(ValidationError(
                field: "layout.tabWidth",
                value: layout.tabWidth,
                constraint: "must be between \(PlatformConstants.validTabWidthRange.lowerBound) and \(PlatformConstants.validTabWidthRange.upperBound)"
            ))
        }

        if !PlatformConstants.validLineHeightMultipleRange.contains(layout.lineHeightMultiple) {
            errors.append(ValidationError(
                field: "layout.lineHeightMultiple",
                value: layout.lineHeightMultiple,
                constraint: "must be between \(PlatformConstants.validLineHeightMultipleRange.lowerBound) and \(PlatformConstants.validLineHeightMultipleRange.upperBound)"
            ))
        }

        if !PlatformConstants.validGutterWidthRange.contains(layout.gutterWidth) {
            errors.append(ValidationError(
                field: "layout.gutterWidth",
                value: layout.gutterWidth,
                constraint: "must be \(PlatformConstants.validGutterWidthRange.lowerBound) or greater"
            ))
        }

        // Validate performance settings
        if !PlatformConstants.validHighlightingLengthRange.contains(performance.maxSyntaxHighlightingLength) {
            errors.append(ValidationError(
                field: "performance.maxSyntaxHighlightingLength",
                value: performance.maxSyntaxHighlightingLength,
                constraint: "must be \(PlatformConstants.validHighlightingLengthRange.lowerBound) or greater"
            ))
        }

        if !PlatformConstants.validDebounceIntervalRange.contains(performance.textChangeDebounceInterval.timeInterval) {
            errors.append(ValidationError(
                field: "performance.textChangeDebounceInterval",
                value: performance.textChangeDebounceInterval.timeInterval,
                constraint: "must be between \(PlatformConstants.validDebounceIntervalRange.lowerBound) and \(PlatformConstants.validDebounceIntervalRange.upperBound) seconds"
            ))
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
        // Validate configuration before applying
        do {
            try validateAndThrow()
        } catch {
            // Log validation error but continue with application
            // This ensures backward compatibility while alerting developers
            CrossPlatformLogger.logger().warning("[CodeEditorPlugin] Configuration validation warning: \(error)")
        }

        // Set the view's configuration property which will trigger applyConfiguration()
        // This will apply all the settings internally
        view.configuration = self

        // Apply cross-platform text input features that aren't handled by applyConfiguration
        applyTextInputFeatures(to: view)
    }

    /// Create a CodeFoldingConfiguration from this EditorConfiguration.
    ///
    /// Maps the code folding settings from this EditorConfiguration to a
    /// CodeFoldingConfiguration that can be used by the CodeFoldingEngine.
    ///
    /// - Returns: A configured CodeFoldingConfiguration instance
    internal func createCodeFoldingConfiguration() -> CodeFoldingConfiguration {
        var config = CodeFoldingConfiguration()
        config.enabled = display.isCodeFoldingEnabled
        config.showGutterControls = display.areFoldingControlsVisible
        config.minimumLineCount = display.minimumFoldableLines
        config.animatesFolding = performance.animateCodeFolding
        return config
    }
}

// MARK: - Equatable

extension EditorConfiguration: Equatable {
    public static func == (lhs: EditorConfiguration, rhs: EditorConfiguration) -> Bool {
        // Compare all properties except eventSystem
        lhs.layout == rhs.layout &&
        lhs.display == rhs.display &&
        lhs.behavior == rhs.behavior &&
        lhs.performance == rhs.performance
        // eventSystem is intentionally excluded from equality comparison
    }
}

// MARK: - Codable

extension EditorConfiguration {
    enum CodingKeys: String, CodingKey {
        case layout
        case display
        case behavior
        case performance
        // eventSystem and injectable dependencies are intentionally excluded from serialization
    }

    /// Initializes an EditorConfiguration from a decoder
    /// - Parameter decoder: The decoder to read configuration data from
    /// - Throws: DecodingError if the configuration cannot be decoded
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.layout = try container.decode(Layout.self, forKey: .layout)
        self.display = try container.decode(Display.self, forKey: .display)
        self.behavior = try container.decode(Behavior.self, forKey: .behavior)
        self.performance = try container.decode(Performance.self, forKey: .performance)
        // Non-serialized properties are always nil when decoding
        self.eventSystem = nil
        self.platformCapabilities = nil
        self.unifiedPerformanceSystem = nil
        self.paragraphStyleCache = nil
        self.languageMetadataRegistry = nil
        self.platformServiceLayer = nil
    }

    /// Encodes the EditorConfiguration to an encoder
    /// - Parameter encoder: The encoder to write configuration data to
    /// - Throws: EncodingError if the configuration cannot be encoded
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layout, forKey: .layout)
        try container.encode(display, forKey: .display)
        try container.encode(behavior, forKey: .behavior)
        try container.encode(performance, forKey: .performance)
        // eventSystem is not encoded
    }
}
