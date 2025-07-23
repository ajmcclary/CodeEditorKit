import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Completion Cell Component System

/// Unified completion cell configuration that works across platforms
public struct CompletionCellConfiguration {
    /// Icon identifier for the completion item
    public let icon: String
    /// Title text for the completion item
    public let title: String
    /// Optional detail text for the completion item
    public let detail: String?
    /// Whether the completion item is deprecated
    public let isDeprecated: Bool
    /// Theme configuration for the cell
    public let theme: CompletionCellTheme

    /// Initializes a completion cell configuration
    /// - Parameters:
    ///   - icon: Icon identifier for the completion item
    ///   - title: Title text for the completion item
    ///   - detail: Optional detail text for the completion item
    ///   - isDeprecated: Whether the completion item is deprecated
    ///   - theme: Theme configuration for the cell
    public init(icon: String, title: String, detail: String? = nil, isDeprecated: Bool = false, theme: CompletionCellTheme = .default) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.isDeprecated = isDeprecated
        self.theme = theme
    }
}

/// Theming configuration for completion cells
public struct CompletionCellTheme: @unchecked Sendable {
    public let iconFont: PlatformFont
    public let titleFont: PlatformFont
    public let detailFont: PlatformFont
    public let iconColor: PlatformColor
    public let titleColor: PlatformColor
    public let detailColor: PlatformColor
    public let deprecatedColor: PlatformColor
    public let spacing: CGFloat
    public let padding: CGFloat

    public static let `default` = Self(
        iconFont: PlatformFonts.systemFont(ofSize: 14),
        titleFont: PlatformFonts.systemFont(ofSize: 14),
        detailFont: PlatformFonts.systemFont(ofSize: 12),
        iconColor: PlatformColors.secondaryLabel,
        titleColor: PlatformColors.label,
        detailColor: PlatformColors.secondaryLabel,
        deprecatedColor: PlatformColors.tertiaryLabel,
        spacing: 8.0,
        padding: 8.0
    )

    public static let compact = Self(
        iconFont: PlatformFonts.systemFont(ofSize: 12),
        titleFont: PlatformFonts.systemFont(ofSize: 13),
        detailFont: PlatformFonts.systemFont(ofSize: 11),
        iconColor: PlatformColors.secondaryLabel,
        titleColor: PlatformColors.label,
        detailColor: PlatformColors.secondaryLabel,
        deprecatedColor: PlatformColors.tertiaryLabel,
        spacing: 6.0,
        padding: 6.0
    )
}

/// Protocol for platform-agnostic completion cell components
/// Protocol for creating platform-specific completion cell components
@MainActor
public protocol CompletionCellComponentProvider {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Platform-specific label type for NSTextField on AppKit
    associatedtype LabelType = NSTextField
    #elseif canImport(UIKit)
    /// Platform-specific label type for UILabel on UIKit
    associatedtype LabelType = UILabel
    #endif

    /// Creates an icon label with the specified theme
    /// - Parameter theme: Theme configuration for the label
    /// - Returns: Configured label for displaying icons
    static func createIconLabel(theme: CompletionCellTheme) -> LabelType
    /// Creates a title label with the specified theme
    /// - Parameter theme: Theme configuration for the label
    /// - Returns: Configured label for displaying titles
    static func createTitleLabel(theme: CompletionCellTheme) -> LabelType
    /// Creates a detail label with the specified theme
    /// - Parameter theme: Theme configuration for the label
    /// - Returns: Configured label for displaying details
    static func createDetailLabel(theme: CompletionCellTheme) -> LabelType
    /// Configures a label with text and theme
    /// - Parameters:
    ///   - label: The label to configure
    ///   - text: Text to display in the label
    ///   - theme: Theme configuration
    ///   - isDeprecated: Whether to apply deprecated styling
    static func configureLabel(_ label: LabelType, with text: String, theme: CompletionCellTheme, isDeprecated: Bool)
}

/// Shared completion cell layout calculator
public enum CompletionCellLayout {
    /// Calculates optimal cell height for given theme and content
    public static func cellHeight(for theme: CompletionCellTheme, hasDetail: Bool = true) -> CGFloat {
        let baseHeight = max(theme.iconFont.pointSize, theme.titleFont.pointSize)
        let detailHeight = hasDetail ? theme.detailFont.pointSize : 0
        return baseHeight + detailHeight + (theme.padding * 2) + theme.spacing
    }

    /// Creates standard constraint layout for icon, title, and detail labels
    @MainActor
    public static func setupConstraints<T: PlatformView>(
        iconLabel: T,
        titleLabel: T,
        detailLabel: T,
        in containerView: T,
        theme: CompletionCellTheme
    ) {
        // Icon label constraints - fixed width on left
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Icon constraints
            iconLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: theme.padding),
            iconLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 24),

            // Title constraints
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: theme.spacing),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            // Detail constraints
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: theme.spacing),
            detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -theme.padding),
            detailLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            // Title should compress before detail
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -theme.spacing)
        ])

        // Set compression resistance priorities
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        #elseif canImport(UIKit)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        #endif
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Updates the appearance of a label for deprecated items on AppKit
    /// 
    /// This method applies visual styling to indicate deprecated completion items,
    /// such as strikethrough text and dimmed colors.
    /// 
    /// - Parameters:
    ///   - label: The NSTextField to update
    ///   - isDeprecated: Whether to apply deprecated styling
    ///   - theme: Theme configuration
    @MainActor
    public static func updateDeprecatedAppearance(
        label: NSTextField,
        isDeprecated: Bool,
        theme: CompletionCellTheme
    ) {
        if isDeprecated {
            label.textColor = theme.deprecatedColor
            label.attributedStringValue = NSAttributedString(
                string: label.stringValue,
                attributes: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: theme.deprecatedColor
                ]
            )
        }
    }
    #elseif canImport(UIKit)
    /// Updates label appearance for deprecated state (UIKit)
    @MainActor
    public static func updateDeprecatedAppearance(
        label: UILabel,
        isDeprecated: Bool,
        theme: CompletionCellTheme
    ) {
        if isDeprecated {
            label.textColor = theme.deprecatedColor
            label.attributedText = NSAttributedString(
                string: label.text ?? "",
                attributes: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: theme.deprecatedColor
                ]
            )
        }
    }
    #endif
}

// MARK: - Platform-Specific Implementations

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

/// AppKit completion cell component provider
@MainActor
public struct AppKitCompletionCellComponents: CompletionCellComponentProvider {
    public typealias LabelType = NSTextField

    public static func createIconLabel(theme: CompletionCellTheme) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = theme.iconFont
        label.textColor = theme.iconColor
        label.alignment = .center
        label.lineBreakMode = .byClipping
        return label
    }

    public static func createTitleLabel(theme: CompletionCellTheme) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = theme.titleFont
        label.textColor = theme.titleColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    public static func createDetailLabel(theme: CompletionCellTheme) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = theme.detailFont
        label.textColor = theme.detailColor
        label.lineBreakMode = .byTruncatingTail
        label.alignment = .right
        return label
    }

    @MainActor public static func configureLabel(_ label: NSTextField, with text: String, theme: CompletionCellTheme, isDeprecated: Bool) {
        label.stringValue = text
        if isDeprecated {
            CompletionCellLayout.updateDeprecatedAppearance(label: label, isDeprecated: true, theme: theme)
        }
    }
}

/// Unified AppKit completion cell view
public final class UnifiedCompletionCellView: NSTableCellView {
    private let iconLabel: NSTextField
    private let titleLabel: NSTextField
    private let detailLabel: NSTextField
    private let theme: CompletionCellTheme

    public init(theme: CompletionCellTheme = .default) {
        self.theme = theme
        self.iconLabel = AppKitCompletionCellComponents.createIconLabel(theme: theme)
        self.titleLabel = AppKitCompletionCellComponents.createTitleLabel(theme: theme)
        self.detailLabel = AppKitCompletionCellComponents.createDetailLabel(theme: theme)

        super.init(frame: .zero)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(iconLabel)
        addSubview(titleLabel)
        addSubview(detailLabel)

        CompletionCellLayout.setupConstraints(
            iconLabel: iconLabel,
            titleLabel: titleLabel,
            detailLabel: detailLabel,
            in: self,
            theme: theme
        )
    }

    public func configure(with configuration: CompletionCellConfiguration) {
        AppKitCompletionCellComponents.configureLabel(iconLabel, with: configuration.icon, theme: theme, isDeprecated: configuration.isDeprecated)
        AppKitCompletionCellComponents.configureLabel(titleLabel, with: configuration.title, theme: theme, isDeprecated: configuration.isDeprecated)

        if let detail = configuration.detail {
            AppKitCompletionCellComponents.configureLabel(detailLabel, with: detail, theme: theme, isDeprecated: configuration.isDeprecated)
            detailLabel.isHidden = false
        } else {
            detailLabel.isHidden = true
        }
    }
}

#elseif canImport(UIKit)

/// UIKit completion cell component provider
@MainActor
public struct UIKitCompletionCellComponents: CompletionCellComponentProvider {
    public typealias LabelType = UILabel

    public static func createIconLabel(theme: CompletionCellTheme) -> UILabel {
        let label = UILabel()
        label.font = theme.iconFont
        label.textColor = theme.iconColor
        label.textAlignment = .center
        label.lineBreakMode = .byClipping
        return label
    }

    public static func createTitleLabel(theme: CompletionCellTheme) -> UILabel {
        let label = UILabel()
        label.font = theme.titleFont
        label.textColor = theme.titleColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    public static func createDetailLabel(theme: CompletionCellTheme) -> UILabel {
        let label = UILabel()
        label.font = theme.detailFont
        label.textColor = theme.detailColor
        label.lineBreakMode = .byTruncatingTail
        label.textAlignment = .right
        return label
    }

    @MainActor public static func configureLabel(_ label: UILabel, with text: String, theme: CompletionCellTheme, isDeprecated: Bool) {
        label.text = text
        if isDeprecated {
            CompletionCellLayout.updateDeprecatedAppearance(label: label, isDeprecated: true, theme: theme)
        }
    }
}

/// Unified UIKit completion cell view
public final class UnifiedCompletionTableViewCell: UITableViewCell {
    private let iconLabel: UILabel
    private let titleLabel: UILabel
    private let detailLabel: UILabel
    private let theme: CompletionCellTheme

    public init(reuseIdentifier: String?, theme: CompletionCellTheme = .default) {
        self.theme = theme
        self.iconLabel = UIKitCompletionCellComponents.createIconLabel(theme: theme)
        self.titleLabel = UIKitCompletionCellComponents.createTitleLabel(theme: theme)
        self.detailLabel = UIKitCompletionCellComponents.createDetailLabel(theme: theme)

        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(iconLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        CompletionCellLayout.setupConstraints(
            iconLabel: iconLabel,
            titleLabel: titleLabel,
            detailLabel: detailLabel,
            in: contentView,
            theme: theme
        )
    }

    public func configure(with configuration: CompletionCellConfiguration) {
        UIKitCompletionCellComponents.configureLabel(iconLabel, with: configuration.icon, theme: theme, isDeprecated: configuration.isDeprecated)
        UIKitCompletionCellComponents.configureLabel(titleLabel, with: configuration.title, theme: theme, isDeprecated: configuration.isDeprecated)

        if let detail = configuration.detail {
            UIKitCompletionCellComponents.configureLabel(detailLabel, with: detail, theme: theme, isDeprecated: configuration.isDeprecated)
            detailLabel.isHidden = false
        } else {
            detailLabel.isHidden = true
        }
    }
}

#endif

// MARK: - Completion Cell Factory

/// Factory for creating completion cells across platforms
public enum CompletionCellFactory {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Creates a completion cell view for AppKit
    /// - Parameter theme: Theme configuration for the cell
    /// - Returns: Configured completion cell view
    @MainActor public static func createCellView(theme: CompletionCellTheme = .default) -> UnifiedCompletionCellView {
        UnifiedCompletionCellView(theme: theme)
    }
    #elseif canImport(UIKit)
    /// Creates a completion table view cell for UIKit
    /// - Parameters:
    ///   - reuseIdentifier: Reuse identifier for the cell
    ///   - theme: Theme configuration for the cell
    /// - Returns: Configured completion table view cell
    @MainActor public static func createTableViewCell(reuseIdentifier: String?, theme: CompletionCellTheme = .default) -> UnifiedCompletionTableViewCell {
        UnifiedCompletionTableViewCell(reuseIdentifier: reuseIdentifier, theme: theme)
    }
    #endif

    /// Calculates standard cell height for theme
    public static func standardCellHeight(theme: CompletionCellTheme = .default) -> CGFloat {
        CompletionCellLayout.cellHeight(for: theme, hasDetail: true)
    }
}
