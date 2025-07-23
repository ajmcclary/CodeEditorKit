import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - CompletionCellConfigurator

/// A unified cell configuration system that abstracts platform differences
/// for completion UI cells
public enum CompletionCellConfigurator {
    // MARK: - Configuration Data

    /// Configuration data for completion cell presentation
    public struct CellConfiguration {
        let iconText: String
        let titleText: String
        let detailText: String?
        let isDeprecated: Bool

        // Platform-specific styling
        let iconFontSize: CGFloat
        let titleFontSize: CGFloat
        let detailFontSize: CGFloat
        let leadingPadding: CGFloat
        let trailingPadding: CGFloat
        let iconWidth: CGFloat
        let spacing: CGFloat

        /// Creates a cell configuration from a completion item
        /// - Parameters:
        ///   - item: The completion item to configure for
        ///   - platform: Target platform for styling (defaults to current platform)
        public init(from item: CompletionItemModel, platform: Platform = .current) {
            self.iconText = item.kind.icon
            self.titleText = item.label
            self.detailText = item.detail
            self.isDeprecated = item.deprecated

            // Apply platform-specific defaults
            switch platform {
            case .macOS:
                self.iconFontSize = 12
                self.titleFontSize = 13
                self.detailFontSize = 11
                self.leadingPadding = 8
                self.trailingPadding = 8
                self.iconWidth = 16
                self.spacing = 8

            case .iOS:
                self.iconFontSize = 16
                self.titleFontSize = 16
                self.detailFontSize = 14
                self.leadingPadding = 16
                self.trailingPadding = 16
                self.iconWidth = 20
                self.spacing = 12
            }
        }
    }

    /// Supported platforms for completion cell styling
    public enum Platform {
        /// macOS platform with Cocoa styling
        case macOS

        /// iOS platform with UIKit styling
        case iOS

        /// Returns the current platform based on available frameworks
        public static var current: Self {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return .macOS
            #else
            return .iOS
            #endif
        }
    }

    // MARK: - Cell Protocol

    /// Protocol for completion cells to conform to
    protocol CompletionCellProtocol {
        func configure(with configuration: CellConfiguration)
    }

    // MARK: - Font Creation

    /// Creates the appropriate font for completion item icons
    /// - Parameter config: Cell configuration containing font size settings
    /// - Returns: Platform-appropriate font for icons
    public static func iconFont(for config: CellConfiguration) -> PlatformFont {
        PlatformFonts.systemFont(ofSize: config.iconFontSize)
    }

    /// Creates the appropriate font for completion item titles
    /// - Parameter config: Cell configuration containing font size and deprecation status
    /// - Returns: Platform-appropriate font for titles (lighter weight if deprecated)
    public static func titleFont(for config: CellConfiguration) -> PlatformFont {
        if config.isDeprecated {
            return PlatformFonts.systemFont(ofSize: config.titleFontSize, weight: .light)
        } else {
            return PlatformFonts.systemFont(ofSize: config.titleFontSize)
        }
    }

    /// Creates the appropriate font for completion item detail text
    /// - Parameter config: Cell configuration containing font size settings
    /// - Returns: Platform-appropriate font for detail text
    public static func detailFont(for config: CellConfiguration) -> PlatformFont {
        PlatformFonts.systemFont(ofSize: config.detailFontSize)
    }

    // MARK: - Color Selection

    /// Returns the appropriate color for completion item titles
    /// - Parameter config: Cell configuration containing deprecation status
    /// - Returns: Platform-appropriate color (dimmed if deprecated)
    public static func titleColor(for config: CellConfiguration) -> PlatformColor {
        if config.isDeprecated {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return PlatformColors.disabledControlText
            #else
            return PlatformColors.tertiaryLabel
            #endif
        } else {
            return PlatformColors.label
        }
    }

    /// Returns the standard color for completion item icons
    /// - Returns: Platform-appropriate secondary label color
    public static func iconColor() -> PlatformColor {
        PlatformColors.secondaryLabel
    }

    /// Returns the standard color for completion item detail text
    /// - Returns: Platform-appropriate secondary label color
    public static func detailColor() -> PlatformColor {
        PlatformColors.secondaryLabel
    }
}

// MARK: - Shared Cell Base View

/// Base class for completion cells that provides common functionality
@MainActor
open class CompletionCellBaseView: PlatformView {
    // MARK: - Properties

    internal var configuration: CompletionCellConfigurator.CellConfiguration?

    // MARK: - Common Setup

    func commonSetup() {
        // Ensure the view is properly configured for its platform
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS specific setup
        wantsLayer = true
        #else
        // iOS specific setup
        backgroundColor = .clear
        #endif
    }

    // MARK: - Configuration

    open func configure(with item: CompletionItemModel) {
        let config = CompletionCellConfigurator.CellConfiguration(from: item)
        self.configuration = config
        applyConfiguration(config)
    }

    /// Override in subclasses to apply the configuration
    open func applyConfiguration(_: CompletionCellConfigurator.CellConfiguration) {
        // To be implemented by subclasses
    }

    deinit {
        // Clean up any resources
    }
}

// MARK: - Layout Constraints Helper

/// Utility for creating Auto Layout constraints for completion cells
public enum CompletionCellConstraints {
    /// Create standard constraints for completion cell subviews
    @MainActor
    public static func createConstraints(
        iconView: PlatformView,
        titleView: PlatformView,
        detailView: PlatformView,
        in containerView: PlatformView,
        config: CompletionCellConfigurator.CellConfiguration
    ) -> [NSLayoutConstraint] {
        [
            // Icon
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: config.leadingPadding),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: config.iconWidth),

            // Title
            titleView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: config.spacing),
            titleView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: Platform.current == .macOS ? -2 : 0),
            titleView.trailingAnchor.constraint(lessThanOrEqualTo: detailView.leadingAnchor, constant: -config.spacing),

            // Detail
            detailView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -config.trailingPadding),
            detailView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: Platform.current == .macOS ? 2 : 0),
            detailView.widthAnchor.constraint(lessThanOrEqualToConstant: 120)
        ]
    }

    private enum Platform {
        case macOS
        case iOS

        static var current: Self {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return .macOS
            #else
            return .iOS
            #endif
        }
    }
}
