import CodeEditorPlugin
import CodeEditorSwiftUI
import DesignKitThemes
import Foundation

/// Theme catalog for the sample app's theme picker, backed by DesignKit's
/// compile-time catalog (12 families × light/dark).
enum ThemeCatalog {
    static let all: [Theme] = Theme.all

    /// Default on launch — `Theme.default` (LCARS Dark).
    static let `default`: Theme = .default

    /// Look up a theme by display name; returns `default` on miss.
    static func theme(named name: String) -> Theme {
        all.first { $0.name == name } ?? `default`
    }
}
