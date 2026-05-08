import CodeEditorDesignTokens
import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit

/// Internal frosted-glass wrapper. Composes an `NSVisualEffectView` with
/// a colored tint sublayer above it. The public `PlatformGlassSurface`
/// SwiftUI modifier in CodeEditorUI is the supported chrome surface;
/// this internal type backs the AppKit completion popover so the
/// completion path doesn't have to take a dependency on CodeEditorUI.
@MainActor
public final class _GlassSurface: NSView {
    private let effect = NSVisualEffectView()
    private let tintLayer = CALayer()

    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived tint color (combines `glass.tint` and `glass.opacity`).
    public private(set) var themedTintColor: NSColor = .clear

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSubviews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSubviews()
    }

    private func configureSubviews() {
        wantsLayer = true
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layer?.addSublayer(tintLayer)
    }

    override public func layout() {
        super.layout()
        tintLayer.frame = bounds
    }

    /// Apply a theme to the glass surface. Equality-gated; refreshes the
    /// tint sublayer's background.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        let tint = NSColor(tokens: theme.platform.glass.tint)
            .withAlphaComponent(CGFloat(theme.platform.glass.opacity))
        themedTintColor = tint
        tintLayer.backgroundColor = tint.cgColor
    }
}
#endif

#if canImport(UIKit)
import UIKit

/// Internal frosted-glass wrapper. Composes a `UIVisualEffectView` with a
/// tinted subview inside its `contentView` per UIKit convention.
@MainActor
public final class _GlassSurface: UIView {
    private let effect = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let tintView = UIView()

    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived tint color (combines `glass.tint` and `glass.opacity`).
    public private(set) var themedTintColor: UIColor = .clear

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSubviews()
    }

    private func configureSubviews() {
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        tintView.translatesAutoresizingMaskIntoConstraints = false
        effect.contentView.addSubview(tintView)
        NSLayoutConstraint.activate([
            tintView.leadingAnchor.constraint(equalTo: effect.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: effect.contentView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: effect.contentView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: effect.contentView.bottomAnchor)
        ])
    }

    /// Apply a theme to the glass surface. Equality-gated; refreshes the
    /// tinted subview's background.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        let tint = UIColor(tokens: theme.platform.glass.tint)
            .withAlphaComponent(CGFloat(theme.platform.glass.opacity))
        themedTintColor = tint
        tintView.backgroundColor = tint
    }
}
#endif
