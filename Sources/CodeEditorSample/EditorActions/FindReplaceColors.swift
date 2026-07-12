import CodeEditorPlatform
import CodeEditorPlugin
import CodeEditorSwiftUI

#if canImport(AppKit)
import AppKit

extension PlatformColor {
    /// Yellow @ 30 % alpha — matches the framework's legacy
    /// `SearchOptions.highlightColor` default.
    static var findHighlight: PlatformColor {
        Self.yellow.withAlphaComponent(0.3)
    }

    /// Selection blue for the *active* match. Pairs find navigation
    /// with the natural "I just selected this" affordance.
    static var findActiveMatch: PlatformColor {
        Self.selectedTextBackgroundColor
    }
}
#else
import UIKit

extension PlatformColor {
    static var findHighlight: PlatformColor {
        Self.systemYellow.withAlphaComponent(0.3)
    }

    static var findActiveMatch: PlatformColor {
        Self.systemBlue.withAlphaComponent(0.45)
    }
}
#endif
