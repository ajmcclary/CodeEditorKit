import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Configuration DSL

/// A domain-specific language for building editor configurations in a more ergonomic way
///
/// This DSL provides a SwiftUI-like syntax for creating configurations:
/// ```swift
/// let config = EditorConfiguration {
///     Display {
///         FontSize(16)
///         LineNumbers(true)
///         SyntaxHighlighting(true)
///     }
///     
///     Layout {
///         TabWidth(4)
///         WrapLines(true)
///         LineHeight(1.5)
///     }
///     
///     Behavior {
///         Editable(true)
///         AutoIndent(true)
///         CodeCompletion(true)
///     }
///     
///     Performance {
///         MaxHighlightingLength(500_000)
///         UseHardwareAcceleration(true)
///     }
/// }
/// ```
@resultBuilder
public enum ConfigurationBuilder {
    /// Builds an editor configuration from a collection of configuration components
    /// - Parameter components: The configuration components to combine
    /// - Returns: A complete editor configuration with all components applied
    public static func buildBlock(_ components: ConfigurationComponent...) -> EditorConfiguration {
        var config = EditorConfiguration()

        for component in components {
            component.apply(to: &config)
        }

        return config
    }
}

// MARK: - Configuration Components

/// Protocol for DSL components that can modify a configuration
public protocol ConfigurationComponent {
    /// Applies this component's configuration changes to the provided editor configuration
    /// - Parameter configuration: The configuration to modify
    func apply(to configuration: inout EditorConfiguration)
}

// MARK: - Display Components

/// Result builder for creating display configuration components
@resultBuilder
public enum DisplayBuilder {
    /// Builds a collection of display components
    /// - Parameter components: Display components to combine
    /// - Returns: Array of display components
    public static func buildBlock(_ components: DisplayComponent...) -> [DisplayComponent] {
        components
    }
}

public struct Display: ConfigurationComponent {
    private let components: [DisplayComponent]

    public init(@DisplayBuilder _ builder: () -> [DisplayComponent]) {
        self.components = builder()
    }

    public func apply(to configuration: inout EditorConfiguration) {
        for component in components {
            component.apply(to: &configuration.display)
        }
    }
}

/// Protocol for components that modify display configuration
public protocol DisplayComponent {
    /// Applies this component's changes to the display configuration
    /// - Parameter display: The display configuration to modify
    func apply(to display: inout EditorConfiguration.Display)
}

public struct FontSize: DisplayComponent {
    private let size: CGFloat

    public init(_ size: CGFloat) {
        self.size = size
    }

    public func apply(to display: inout EditorConfiguration.Display) {
        display.fontSize = size
    }
}

public struct LineNumbers: DisplayComponent {
    private let enabled: Bool

    public init(_ enabled: Bool) {
        self.enabled = enabled
    }

    public func apply(to display: inout EditorConfiguration.Display) {
        display.isLineNumbersEnabled = enabled
    }
}

public struct SyntaxHighlighting: DisplayComponent {
    private let enabled: Bool

    public init(_ enabled: Bool) {
        self.enabled = enabled
    }

    public func apply(to display: inout EditorConfiguration.Display) {
        display.enableSyntaxHighlighting = enabled
    }
}

// Theme component removed - EditorConfiguration.Display doesn't have a theme property
// You can add custom theme support later if needed

public struct ShowMinimap: DisplayComponent {
    private let show: Bool

    public init(_ show: Bool) {
        self.show = show
    }

    public func apply(to display: inout EditorConfiguration.Display) {
        display.showMinimap = show
    }
}

// MARK: - Layout Components

/// Result builder for creating layout configuration components
@resultBuilder
public enum LayoutBuilder {
    /// Builds a collection of layout components
    /// - Parameter components: Layout components to combine
    /// - Returns: Array of layout components
    public static func buildBlock(_ components: LayoutComponent...) -> [LayoutComponent] {
        components
    }
}

public struct Layout: ConfigurationComponent {
    private let components: [LayoutComponent]

    public init(@LayoutBuilder _ builder: () -> [LayoutComponent]) {
        self.components = builder()
    }

    public func apply(to configuration: inout EditorConfiguration) {
        for component in components {
            component.apply(to: &configuration.layout)
        }
    }
}

/// Protocol for components that modify layout configuration
public protocol LayoutComponent {
    /// Applies this component's changes to the layout configuration
    /// - Parameter layout: The layout configuration to modify
    func apply(to layout: inout EditorConfiguration.Layout)
}

public struct TabWidth: LayoutComponent {
    private let width: Int

    public init(_ width: Int) {
        self.width = width
    }

    public func apply(to layout: inout EditorConfiguration.Layout) {
        layout.tabWidth = width
    }
}

public struct WrapLines: LayoutComponent {
    private let wrap: Bool

    public init(_ wrap: Bool) {
        self.wrap = wrap
    }

    public func apply(to layout: inout EditorConfiguration.Layout) {
        layout.wrapLines = wrap
    }
}

public struct LineHeight: LayoutComponent {
    private let multiple: CGFloat

    public init(_ multiple: CGFloat) {
        self.multiple = multiple
    }

    public func apply(to layout: inout EditorConfiguration.Layout) {
        layout.lineHeightMultiple = multiple
    }
}

public struct GutterWidth: LayoutComponent {
    private let width: CGFloat

    public init(_ width: CGFloat) {
        self.width = width
    }

    public func apply(to layout: inout EditorConfiguration.Layout) {
        layout.gutterWidth = width
    }
}

// MARK: - Behavior Components

/// Result builder for creating behavior configuration components
@resultBuilder
public enum BehaviorBuilder {
    /// Builds a collection of behavior components
    /// - Parameter components: Behavior components to combine
    /// - Returns: Array of behavior components
    public static func buildBlock(_ components: BehaviorComponent...) -> [BehaviorComponent] {
        components
    }
}

public struct Behavior: ConfigurationComponent {
    private let components: [BehaviorComponent]

    public init(@BehaviorBuilder _ builder: () -> [BehaviorComponent]) {
        self.components = builder()
    }

    public func apply(to configuration: inout EditorConfiguration) {
        for component in components {
            component.apply(to: &configuration.behavior)
        }
    }
}

/// Protocol for components that modify behavior configuration
public protocol BehaviorComponent {
    /// Applies this component's changes to the behavior configuration
    /// - Parameter behavior: The behavior configuration to modify
    func apply(to behavior: inout EditorConfiguration.Behavior)
}

public struct Editable: BehaviorComponent {
    private let editable: Bool

    public init(_ editable: Bool) {
        self.editable = editable
    }

    public func apply(to behavior: inout EditorConfiguration.Behavior) {
        behavior.isEditable = editable
    }
}

public struct AutoIndent: BehaviorComponent {
    private let enabled: Bool

    public init(_ enabled: Bool) {
        self.enabled = enabled
    }

    public func apply(to behavior: inout EditorConfiguration.Behavior) {
        behavior.autoIndent = enabled
    }
}

public struct CodeCompletion: BehaviorComponent {
    private let enabled: Bool

    public init(_ enabled: Bool) {
        self.enabled = enabled
    }

    public func apply(to behavior: inout EditorConfiguration.Behavior) {
        behavior.enableCodeCompletion = enabled
    }
}

// MARK: - Performance Components

/// Result builder for creating performance configuration components
@resultBuilder
public enum PerformanceBuilder {
    /// Builds a collection of performance components
    /// - Parameter components: Performance components to combine
    /// - Returns: Array of performance components
    public static func buildBlock(_ components: PerformanceComponent...) -> [PerformanceComponent] {
        components
    }
}

public struct Performance: ConfigurationComponent {
    private let components: [PerformanceComponent]

    public init(@PerformanceBuilder _ builder: () -> [PerformanceComponent]) {
        self.components = builder()
    }

    public func apply(to configuration: inout EditorConfiguration) {
        for component in components {
            component.apply(to: &configuration.performance)
        }
    }
}

/// Protocol for components that modify performance configuration
public protocol PerformanceComponent {
    /// Applies this component's changes to the performance configuration
    /// - Parameter performance: The performance configuration to modify
    func apply(to performance: inout EditorConfiguration.Performance)
}

public struct MaxHighlightingLength: PerformanceComponent {
    private let length: Int

    public init(_ length: Int) {
        self.length = length
    }

    public func apply(to performance: inout EditorConfiguration.Performance) {
        performance.maxSyntaxHighlightingLength = length
    }
}

public struct UseHardwareAcceleration: PerformanceComponent {
    private let use: Bool

    public init(_ use: Bool) {
        self.use = use
    }

    public func apply(to performance: inout EditorConfiguration.Performance) {
        performance.useHardwareAcceleration = use
    }
}

public struct SmoothScrolling: PerformanceComponent {
    private let enabled: Bool

    public init(_ enabled: Bool) {
        self.enabled = enabled
    }

    public func apply(to performance: inout EditorConfiguration.Performance) {
        performance.smoothScrolling = enabled
    }
}

// MARK: - Convenience Initializer

extension EditorConfiguration {
    /// Creates a configuration using the DSL syntax
    /// - Parameter builder: The configuration builder
    public init(@ConfigurationBuilder _ builder: () -> EditorConfiguration) {
        self = builder()
    }
}

// MARK: - Preset DSL

/// DSL for applying presets with modifications
public struct Preset: ConfigurationComponent {
    private let preset: PresetConfiguration
    private let modifications: [ConfigurationComponent]

    public init(_ preset: PresetConfiguration, @ConfigurationBuilder modifications: () -> [ConfigurationComponent] = { [] }) {
        self.preset = preset
        self.modifications = modifications()
    }

    public func apply(to configuration: inout EditorConfiguration) {
        // Apply preset
        switch preset {
        case .default:
            configuration = .default

        case .minimal:
            configuration = .minimal

        case .readOnly:
            configuration = .readOnly

        case .markdown:
            configuration = .markdown

        case .presentation:
            configuration = .presentation

        case .iOS:
            configuration = .iOS

        case .catalyst:
            configuration = .catalyst

        case .macOS:
            configuration = .macOS

        case .platformOptimized:
            configuration = .platformOptimized
        }

        // Apply modifications
        for modification in modifications {
            modification.apply(to: &configuration)
        }
    }
}

// MARK: - Usage Examples

/*
// Example 1: Simple configuration
let simpleConfig = EditorConfiguration {
    Display {
        FontSize(14)
        LineNumbers(true)
    }
    Layout {
        TabWidth(4)
    }
}

// Example 2: Complex configuration
let complexConfig = EditorConfiguration {
    Display {
        FontSize(16)
        LineNumbers(true)
        SyntaxHighlighting(true)
        ShowMinimap(false)
    }
    
    Layout {
        TabWidth(2)
        WrapLines(true)
        LineHeight(1.6)
        GutterWidth(50)
    }
    
    Behavior {
        Editable(true)
        AutoIndent(true)
        CodeCompletion(true)
    }
    
    Performance {
        MaxHighlightingLength(1_000_000)
        UseHardwareAcceleration(true)
        SmoothScrolling(true)
    }
}

// Example 3: Preset with modifications
let modifiedPreset = EditorConfiguration {
    Preset(.minimal) {
        Display {
            FontSize(18)
        }
        Layout {
            TabWidth(2)
        }
    }
}
*/
