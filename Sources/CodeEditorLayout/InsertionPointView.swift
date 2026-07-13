import CodeEditorPlatform
import DesignKitThemes
import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - InsertionPointView

/// View representing the text insertion point (cursor)
@MainActor
public class InsertionPointView: NSView {
    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived caret color. Defaults to the system label until
    /// `apply(theme:)` lands the first theme.
    public private(set) var themedCaretColor: PlatformColor = PlatformColors.label

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
        layer?.backgroundColor = themedCaretColor.cgColor
    }

    /// Apply a theme to the insertion point. Equality-gated: a second call
    /// with the same theme is a no-op.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        themedCaretColor = PlatformColor(tokens: theme.style.players[0].cursor)
        wantsLayer = true
        layer?.backgroundColor = themedCaretColor.cgColor
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    deinit {
        // Cleanup if needed
    }
}

#elseif canImport(UIKit)
import UIKit

// MARK: - InsertionPointView (iOS Stub)

/// Stub implementation for iOS
@MainActor
public class InsertionPointView: UIView {
    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived caret color. Defaults to the system label until
    /// `apply(theme:)` lands the first theme.
    public private(set) var themedCaretColor: PlatformColor = PlatformColors.label

    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = themedCaretColor
    }

    /// Apply a theme to the insertion point. Equality-gated: a second call
    /// with the same theme is a no-op.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        themedCaretColor = PlatformColor(tokens: theme.style.players[0].cursor)
        backgroundColor = themedCaretColor
    }

    deinit {
        // Cleanup if needed
    }
}
#endif
