import CodeEditorPlatform
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Shared context menu structure for cross-platform consistency
struct ContextMenuDescriptor {
    package let items: [ContextMenuItem]
}

enum ContextMenuItem {
    case action(title: String, icon: String?, keyEquivalent: String?, action: () -> Void)
    case separator
    case submenu(title: String, icon: String?, items: [Self])
}

/// Cross-platform context menu builder
@MainActor
enum SharedContextMenuBuilder {
    /// Create a standardized context menu for code editors
    static func createStandardCodeEditorMenu(
        for textView: CodeEditorView,
        coordinator: CrossPlatformCoordinator
    ) -> ContextMenuDescriptor {
        var items: [ContextMenuItem] = []

        // Standard editing actions
        items.append(.action(
            title: "Cut",
            icon: "scissors",
            keyEquivalent: "x"
        ) {
            textView.cut(nil)
        })

        items.append(.action(
            title: "Copy",
            icon: "doc.on.doc",
            keyEquivalent: "c"
        ) {
            textView.copy(nil)
        })

        items.append(.action(
            title: "Paste",
            icon: "doc.on.clipboard",
            keyEquivalent: "v"
        ) {
            textView.paste(nil)
        })

        items.append(.separator)

        // Code-specific actions submenu
        let codeMenuItems: [ContextMenuItem] = [
            .action(
                title: "Toggle Comment",
                icon: "text.bubble",
                keyEquivalent: "/"
            ) {
                coordinator.toggleComment(in: textView)
            },
            .action(
                title: "Format Selection",
                icon: "text.alignleft",
                keyEquivalent: nil
            ) {
                coordinator.logger.debug("Format selection requested")
                // Implementation tracked in GitHub issue #4
            },
            .separator,
            .action(
                title: "Go to Definition",
                icon: "arrow.right.circle",
                keyEquivalent: nil
            ) {
                coordinator.logger.debug("Go to definition requested")
                // Implementation will be added in future updates
            },
            .action(
                title: "Find References",
                icon: "magnifyingglass.circle",
                keyEquivalent: nil
            ) {
                coordinator.logger.debug("Find references requested")
                // Implementation will be added in future updates
            }
        ]

        items.append(.submenu(
            title: "Code",
            icon: "chevron.left.forwardslash.chevron.right",
            items: codeMenuItems
        ))

        return ContextMenuDescriptor(items: items)
    }
}

// MARK: - Platform-specific builders

extension SharedContextMenuBuilder {
    #if canImport(AppKit)
    /// Convert shared menu descriptor to macOS NSMenu
    static func buildNSMenu(from descriptor: ContextMenuDescriptor, target: CrossPlatformCoordinator) -> NSMenu {
        let menu = NSMenu()

        for item in descriptor.items {
            switch item {
            case let .action(title, _, keyEquivalent, action):
                let menuItem = NSMenuItem(
                    title: title,
                    action: #selector(CrossPlatformCoordinator.handleSharedMenuAction(_:)),
                    keyEquivalent: keyEquivalent ?? ""
                )
                menuItem.target = target
                menuItem.representedObject = action
                menu.addItem(menuItem)

            case .separator:
                menu.addItem(NSMenuItem.separator())

            case let .submenu(title, _, subItems):
                let submenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                for subItem in subItems {
                    switch subItem {
                    case let .action(subTitle, _, subKeyEquivalent, subAction):
                        let subMenuItem = NSMenuItem(
                            title: subTitle,
                            action: #selector(CrossPlatformCoordinator.handleSharedMenuAction(_:)),
                            keyEquivalent: subKeyEquivalent ?? ""
                        )
                        subMenuItem.target = target
                        subMenuItem.representedObject = subAction
                        submenu.addItem(subMenuItem)

                    case .separator:
                        submenu.addItem(NSMenuItem.separator())

                    case .submenu:
                        // Nested submenus not implemented for simplicity
                        break
                    }
                }

                submenuItem.submenu = submenu
                menu.addItem(submenuItem)
            }
        }

        return menu
    }
    #endif

    #if canImport(UIKit)
    /// Convert shared menu descriptor to iOS UIMenu
    static func buildUIMenu(from descriptor: ContextMenuDescriptor) -> UIMenu {
        var elements: [UIMenuElement] = []

        for item in descriptor.items {
            switch item {
            case let .action(title, icon, _, action):
                let uiAction = UIAction(
                    title: title,
                    image: icon.flatMap { UIImage(systemName: $0) }
                ) { _ in
                    action()
                }
                elements.append(uiAction)

            case .separator:
                // UIMenu doesn't support explicit separators, but groups provide visual separation
                continue

            case let .submenu(title, icon, subItems):
                var subElements: [UIMenuElement] = []

                for subItem in subItems {
                    switch subItem {
                    case let .action(subTitle, subIcon, _, subAction):
                        let subUIAction = UIAction(
                            title: subTitle,
                            image: subIcon.flatMap { UIImage(systemName: $0) }
                        ) { _ in
                            subAction()
                        }
                        subElements.append(subUIAction)

                    case .separator, .submenu:
                        // Skip separators and nested submenus in UIKit
                        continue
                    }
                }

                let submenu = UIMenu(
                    title: title,
                    image: icon.flatMap { UIImage(systemName: $0) },
                    children: subElements
                )
                elements.append(submenu)
            }
        }

        return UIMenu(children: elements)
    }
    #endif
}
