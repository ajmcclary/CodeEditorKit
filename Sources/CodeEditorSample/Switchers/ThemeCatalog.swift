import CodeEditorPlugin
import Foundation

/// Bundled-theme catalog for the sample app's theme picker. Reads the
/// 20 `zed-trek` variants once at first access; lookup is O(1) by name.
enum ThemeCatalog {
    static let all: [Theme] = {
        guard let family = ThemeFamily.bundled("zed-trek") else { return [] }
        return family.themes
    }()

    /// Default on launch — `LCARS Dark` from the bundled `zed-trek`
    /// family (same `Theme` value as `Theme.lcarsDark`).
    static let `default`: Theme = .lcarsDark

    /// Look up a theme by display name; returns `default` on miss.
    static func theme(named name: String) -> Theme {
        all.first { $0.name == name } ?? `default`
    }
}
