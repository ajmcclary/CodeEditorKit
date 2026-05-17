import CodeEditorPlatform
import Foundation
#if canImport(UIKit)
import UIKit

// MARK: - LineHighlightView

/// Implementation for iOS and iOS
@MainActor
public class LineHighlightView: UIView {
    public var highlightColor: PlatformColor = PlatformColors.tintColor.withAlphaComponent(0.1) {
        didSet {
            backgroundColor = highlightColor
        }
    }

    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived active-line fill color. Defaults to `.clear` until
    /// `apply(theme:)` lands the first theme.
    public private(set) var themedFillColor: PlatformColor = .clear

    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = highlightColor
    }

    /// Apply a theme to the line highlight view. Equality-gated: a second
    /// call with the same theme is a no-op.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        themedFillColor = PlatformColor(tokens: theme.style.editor.activeLineBackground)
        highlightColor = themedFillColor
    }

    deinit {
        // Cleanup if needed
    }
}

#elseif canImport(AppKit)
import AppKit

// MARK: - LineHighlightView

/// View for highlighting the current line on macOS
@MainActor
public class LineHighlightView: NSView {
    public var highlightColor: PlatformColor = PlatformColors.controlAccentColor.withAlphaComponent(0.1) {
        didSet {
            wantsLayer = true
            layer?.backgroundColor = highlightColor.cgColor
        }
    }

    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived active-line fill color. Defaults to `.clear` until
    /// `apply(theme:)` lands the first theme.
    public private(set) var themedFillColor: PlatformColor = .clear

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = highlightColor.cgColor
    }

    /// Apply a theme to the line highlight view. Equality-gated: a second
    /// call with the same theme is a no-op.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        themedFillColor = PlatformColor(tokens: theme.style.editor.activeLineBackground)
        highlightColor = themedFillColor
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    deinit {
        // Cleanup if needed
    }
}

#endif
