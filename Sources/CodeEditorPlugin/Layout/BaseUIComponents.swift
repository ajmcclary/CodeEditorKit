import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
/// Platform-specific accessibility traits type for AppKit
public typealias PlatformAccessibilityTraits = NSAccessibility.Role
#elseif canImport(UIKit)
import UIKit
/// Platform-specific accessibility traits type for UIKit
public typealias PlatformAccessibilityTraits = UIAccessibilityTraits
#endif

// MARK: - Base UI Component Infrastructure

/// Protocol for configurable UI components
/// Protocol for UI components that can be configured with data
@MainActor
public protocol ConfigurableUIComponent {
    /// Configuration type for this component
    associatedtype Configuration
    /// Configures the component with the provided configuration
    /// - Parameter configuration: Configuration data for the component
    func configure(with configuration: Configuration)
}

/// Protocol for themeable UI components
/// Protocol for UI components that support theming
@MainActor
public protocol ThemeableUIComponent {
    /// Theme type for this component
    associatedtype Theme

    /// Current theme applied to the component
    var theme: Theme { get set }

    /// Applies the specified theme to the component
    /// - Parameter theme: Theme to apply
    func applyTheme(_ theme: Theme)
}

/// Protocol for reusable UI components that can be reset to initial state
/// Protocol for UI components that can be reused and reset
@MainActor
public protocol ReusableUIComponent {
    /// Prepares the component for reuse by resetting its state
    func prepareForReuse()
}

/// Base theme protocol defining common styling properties
public protocol BaseUITheme {
    /// Primary accent color for the theme
    var primaryColor: PlatformColor { get }
    /// Secondary color for less prominent elements
    var secondaryColor: PlatformColor { get }
    /// Background color for themed components
    var backgroundColor: PlatformColor { get }
    /// Text color for themed components
    var textColor: PlatformColor { get }
    /// Default font for themed components
    var font: PlatformFont { get }
}

/// Standard theme implementation
public struct StandardUITheme: BaseUITheme, @unchecked Sendable {
    public let primaryColor: PlatformColor
    public let secondaryColor: PlatformColor
    public let backgroundColor: PlatformColor
    public let textColor: PlatformColor
    public let font: PlatformFont

    public static let `default` = Self(
        primaryColor: PlatformColors.systemBlue,
        secondaryColor: PlatformColors.secondaryLabel,
        backgroundColor: PlatformColors.controlBackground,
        textColor: PlatformColors.label,
        font: PlatformFonts.systemFont(ofSize: 14)
    )

    public static let compact = Self(
        primaryColor: PlatformColors.systemBlue,
        secondaryColor: PlatformColors.secondaryLabel,
        backgroundColor: PlatformColors.controlBackground,
        textColor: PlatformColors.label,
        font: PlatformFonts.systemFont(ofSize: 12)
    )
}

// MARK: - Base View Components

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

/// Base configurable view for AppKit
open class BaseConfigurableView<Config, Theme: BaseUITheme>: NSView, ConfigurableUIComponent, ThemeableUIComponent {
    public typealias Configuration = Config

    private var _theme: Theme
    public var theme: Theme {
        get { _theme }
        set {
            _theme = newValue
            applyTheme(newValue)
        }
    }

    public init(theme: Theme) {
        self._theme = theme
        super.init(frame: .zero)
        setupView()
        applyTheme(theme)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override to setup view hierarchy and constraints
    open func setupView() {
        // Override in subclasses
    }

    /// Override to configure the view with data
    open func configure(with _: Config) {
        // Override in subclasses
    }

    /// Override to apply theme changes
    open func applyTheme(_: Theme) {
        // Override in subclasses
    }
}

/// Base reusable table cell view for AppKit
open class BaseReusableTableCellView<Config, Theme: BaseUITheme>: NSTableCellView, ConfigurableUIComponent, ThemeableUIComponent, ReusableUIComponent {
    public typealias Configuration = Config

    private var _theme: Theme
    public var theme: Theme {
        get { _theme }
        set {
            _theme = newValue
            applyTheme(newValue)
        }
    }

    public init(theme: Theme) {
        self._theme = theme
        super.init(frame: .zero)
        setupView()
        applyTheme(theme)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override to setup view hierarchy and constraints
    open func setupView() {
        // Override in subclasses
    }

    /// Override to configure the view with data
    open func configure(with _: Config) {
        // Override in subclasses
    }

    /// Override to apply theme changes
    open func applyTheme(_: Theme) {
        // Override in subclasses
    }
}

#elseif canImport(UIKit)

/// Base configurable view for UIKit
open class BaseConfigurableView<Config, Theme: BaseUITheme>: UIView, ConfigurableUIComponent, ThemeableUIComponent {
    public typealias Configuration = Config

    private var _theme: Theme
    public var theme: Theme {
        get { _theme }
        set {
            _theme = newValue
            applyTheme(newValue)
        }
    }

    public init(theme: Theme) {
        self._theme = theme
        super.init(frame: .zero)
        setupView()
        applyTheme(theme)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override to setup view hierarchy and constraints
    open func setupView() {
        // Override in subclasses
    }

    /// Override to configure the view with data
    open func configure(with _: Config) {
        // Override in subclasses
    }

    /// Override to apply theme changes
    open func applyTheme(_ theme: Theme) {
        backgroundColor = theme.backgroundColor
    }
}

/// Base reusable table cell view for UIKit
open class BaseReusableTableViewCell<Config, Theme: BaseUITheme>: UITableViewCell, ConfigurableUIComponent, ThemeableUIComponent, ReusableUIComponent {
    public typealias Configuration = Config

    private var _theme: Theme
    public var theme: Theme {
        get { _theme }
        set {
            _theme = newValue
            applyTheme(newValue)
        }
    }

    public init(theme: Theme, reuseIdentifier: String?) {
        self._theme = theme
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        setupView()
        applyTheme(theme)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override to setup view hierarchy and constraints
    open func setupView() {
        // Override in subclasses
    }

    /// Override to configure the view with data
    open func configure(with _: Config) {
        // Override in subclasses
    }

    /// Override to apply theme changes
    open func applyTheme(_ theme: Theme) {
        backgroundColor = theme.backgroundColor
        contentView.backgroundColor = theme.backgroundColor
    }
}

#endif

// MARK: - UI Component Factory

/// Factory for creating reusable UI components
public enum UIComponentFactory {
    /// Theme registry for component themes
    @MainActor
    private static var themeRegistry: [String: Any] = [:]

    /// Registers a theme for a component type
    @MainActor
    public static func registerTheme<T>(_ theme: T, for componentType: String) {
        themeRegistry[componentType] = theme
    }

    /// Gets a registered theme for a component type
    @MainActor
    public static func getTheme<T>(for componentType: String, as _: T.Type) -> T? {
        themeRegistry[componentType] as? T
    }

    /// Creates a themed component
    @available(*, unavailable)
    public static func createComponent<Component, Theme>(
        type _: Component.Type,
        theme _: Theme
    ) -> Component where Component: ThemeableUIComponent, Component.Theme == Theme {
        // This would need specific implementations for each component type
        fatalError("createComponent must be implemented for specific component types")
    }
}

// MARK: - Layout Utility Components

/// Utility for creating consistent spacing between components
public enum UISpacing {
    /// Tiny spacing value (4 points)
    public static let tiny: CGFloat = 4
    /// Small spacing value (8 points)
    public static let small: CGFloat = 8
    /// Medium spacing value (12 points)
    public static let medium: CGFloat = 12
    /// Large spacing value (16 points)
    public static let large: CGFloat = 16
    /// Extra large spacing value (24 points)
    public static let extraLarge: CGFloat = 24

    /// Returns spacing appropriate for the current platform
    public static func platformDefault() -> CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return medium
        #else
        return large
        #endif
    }
}

/// Utility for creating consistent margins around components
public enum UIMargins {
    /// Tiny margin value (4 points)
    public static let tiny: CGFloat = 4
    /// Small margin value (8 points)
    public static let small: CGFloat = 8
    /// Medium margin value (16 points)
    public static let medium: CGFloat = 16
    /// Large margin value (20 points)
    public static let large: CGFloat = 20
    /// Extra large margin value (32 points)
    public static let extraLarge: CGFloat = 32

    /// Returns margins appropriate for the current platform
    public static func platformDefault() -> CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return medium
        #else
        return large
        #endif
    }
}

// MARK: - Accessibility Helpers

/// Utility for consistent accessibility support
public enum AccessibilityHelper {
    /// Configures accessibility for a labeled control
    @MainActor
    public static func configureControl<T: PlatformView>(
        _ view: T,
        label: String,
        hint: String? = nil,
        traits: PlatformAccessibilityTraits? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.setAccessibilityLabel(label)
        if let hint {
            view.setAccessibilityHelp(hint)
        }
        #elseif canImport(UIKit)
        view.accessibilityLabel = label
        if let hint {
            view.accessibilityHint = hint
        }
        if let traits {
            view.accessibilityTraits = traits
        }
        #endif
    }

    /// Configures accessibility for a button
    @MainActor
    public static func configureButton<T: PlatformView>(
        _ view: T,
        label: String,
        hint: String? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        configureControl(view, label: label, hint: hint)
        view.setAccessibilityRole(.button)
        #elseif canImport(UIKit)
        configureControl(view, label: label, hint: hint, traits: .button)
        #endif
    }

    /// Configures accessibility for a text field
    @MainActor
    public static func configureTextField<T: PlatformView>(
        _ view: T,
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        configureControl(view, label: label, hint: hint)
        view.setAccessibilityRole(.textField)
        if let value {
            view.setAccessibilityValue(value)
        }
        #elseif canImport(UIKit)
        configureControl(view, label: label, hint: hint, traits: PlatformAccessibilityTraits.none)
        if let value {
            view.accessibilityValue = value
        }
        #endif
    }
}

// MARK: - Platform Abstraction Extensions
