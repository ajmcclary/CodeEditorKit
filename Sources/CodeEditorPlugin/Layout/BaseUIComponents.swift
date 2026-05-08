import Foundation
#if canImport(AppKit)
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
@MainActor
public protocol ConfigurableUIComponent {
    /// Configuration type for this component
    associatedtype Configuration
    /// Configures the component with the provided configuration
    /// - Parameter configuration: Configuration data for the component
    func configure(with configuration: Configuration)
}

/// Protocol for UI components that consume the editor's `Theme` value type.
///
/// Conformers expose `appliedTheme` storage and an equality-gated
/// `apply(theme:)` method. The editor's container view fans theme
/// application out to subviews; each subview's `apply(theme:)` reads the
/// fields it needs from the supplied `Theme`.
@MainActor
public protocol ThemeableUIComponent: AnyObject {
    /// The theme last applied via `apply(theme:)`. nil before the first
    /// apply.
    var appliedTheme: Theme? { get }

    /// Apply a theme. Implementations should early-return when the new
    /// theme equals the previously-applied theme to avoid redundant
    /// redraws.
    func apply(theme: Theme)
}

/// Protocol for reusable UI components that can be reset to initial state
@MainActor
public protocol ReusableUIComponent {
    /// Prepares the component for reuse by resetting its state
    func prepareForReuse()
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
        #if canImport(AppKit)
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
        #if canImport(AppKit)
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
        #if canImport(AppKit)
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
        #if canImport(AppKit)
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
        #if canImport(AppKit)
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
