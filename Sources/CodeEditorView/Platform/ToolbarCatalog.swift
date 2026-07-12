import CodeEditorPlatform

package enum ToolbarPlatformKind: Sendable {
    case macOS
    case iPad
    case iPhone
}

/// Canonical toolbar command descriptors and platform selections.
package enum ToolbarCatalog {
    package static let find = ToolbarItem(
        title: "Find",
        icon: "magnifyingglass",
        action: .find,
        id: "find"
    )

    package static let editing = [
        ToolbarItem(
            title: "Replace",
            icon: "arrow.left.arrow.right",
            action: .replace,
            id: "replace"
        ),
        ToolbarItem(
            title: "Symbols",
            icon: "list.bullet.indent",
            action: .showSymbols,
            id: "symbol"
        ),
        ToolbarItem(
            title: "Format",
            icon: "text.alignleft",
            action: .format,
            id: "format"
        )
    ]

    package static let macOnly = [
        ToolbarItem(
            title: "Minimap",
            icon: "map",
            action: .custom(id: "minimap"),
            id: "minimap"
        ),
        ToolbarItem(
            title: "Navigator",
            icon: "sidebar.left",
            action: .custom(id: "navigator"),
            id: "navigator"
        )
    ]

    package static let phoneOnly = [
        ToolbarItem(
            title: "Share",
            icon: "square.and.arrow.up",
            action: .custom(id: "share"),
            id: "share"
        )
    ]

    package static func items(for platform: ToolbarPlatformKind) -> [ToolbarItem] {
        switch platform {
        case .macOS:
            [find] + editing + macOnly

        case .iPad:
            [find] + editing

        case .iPhone:
            [find] + phoneOnly
        }
    }
}
