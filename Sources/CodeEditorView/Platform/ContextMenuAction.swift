//
//  ContextMenuAction.swift
//  CodeEditorKit
//
//  Created on 2025-06-27.
//

import CodeEditorPlatform
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// A cross-platform abstraction for context menu actions
public struct ContextMenuAction: Sendable {
    /// The title displayed in the menu
    public let title: String

    /// Optional keyboard shortcut
    public let keyEquivalent: String?

    /// Optional modifier flags for keyboard shortcut
    public let modifiers: PlatformModifierFlags

    /// The action to perform when selected
    public let handler: @MainActor @Sendable () -> Void

    /// Whether the action is currently enabled
    public let isEnabled: Bool

    /// Whether this is a separator item
    public let isSeparator: Bool

    /// Create a regular menu action
    public init(
        title: String,
        keyEquivalent: String? = nil,
        modifiers: PlatformModifierFlags = [],
        isEnabled: Bool = true,
        handler: @escaping @MainActor @Sendable () -> Void
    ) {
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.isEnabled = isEnabled
        self.handler = handler
        self.isSeparator = false
    }

    /// Create a separator item
    public static var separator: Self {
        Self(
            title: "",
            keyEquivalent: nil,
            isEnabled: false
        ) {}.withSeparator()
    }

    private func withSeparator() -> Self {
        var action = self
        action = Self(
            title: title,
            keyEquivalent: keyEquivalent,
            isEnabled: isEnabled,
            handler: handler,
            isSeparator: true,
            modifiers: modifiers
        )
        return action
    }

    private init(
        title: String,
        keyEquivalent: String?,
        isEnabled: Bool,
        handler: @escaping @MainActor @Sendable () -> Void,
        isSeparator: Bool,
        modifiers: PlatformModifierFlags = []
    ) {
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.isEnabled = isEnabled
        self.handler = handler
        self.isSeparator = isSeparator
    }
}

/// A builder for creating context menus with modern action-based API
public struct ContextMenuBuilder: Sendable {
    internal var actions: [ContextMenuAction] = []

    public init() {}

    /// Add an action to the menu
    public mutating func addAction(_ action: ContextMenuAction) {
        actions.append(action)
    }

    /// Add a separator to the menu
    public mutating func addSeparator() {
        actions.append(.separator)
    }

    /// Build the platform-specific menu
    @MainActor
    public func build() -> PlatformContextMenu {
        #if canImport(AppKit)
        return buildAppKitMenu()
        #else
        return buildUIKitMenu()
        #endif
    }

    #if canImport(AppKit)
    @MainActor
    private func buildAppKitMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for action in actions {
            if action.isSeparator {
                menu.addItem(NSMenuItem.separator())
            } else {
                let item = NSMenuItem(
                    title: action.title,
                    action: #selector(ContextMenuActionTarget.performAction(_:)),
                    keyEquivalent: action.keyEquivalent ?? ""
                )

                // Create a target to handle the action
                let target = ContextMenuActionTarget(action: action)
                item.target = target
                item.isEnabled = action.isEnabled

                // Store the target to keep it alive
                item.representedObject = target

                menu.addItem(item)
            }
        }

        return menu
    }
    #endif

    #if canImport(UIKit)
    @MainActor
    private func buildUIKitMenu() -> UIMenu {
        let children = actions.compactMap { action -> UIMenuElement? in
            if action.isSeparator {
                return UIMenu(title: "", options: .displayInline, children: [])
            } else {
                return UIAction(
                    title: action.title,
                    attributes: action.isEnabled ? [] : .disabled
                ) { _ in
                    Task { @MainActor in
                        action.handler()
                    }
                }
            }
        }

        return UIMenu(children: children)
    }
    #endif
}

#if canImport(AppKit)
/// Target object for handling NSMenuItem actions
@MainActor
private class ContextMenuActionTarget: NSObject {
    private let action: ContextMenuAction

    init(action: ContextMenuAction) {
        self.action = action
        super.init()
    }

    @objc func performAction(_: Any?) {
        action.handler()
    }

    deinit {
        // Cleanup
    }
}
#endif

/// Protocol for types that can provide context menus
internal protocol ContextMenuProvider: Sendable {
    /// Create a context menu for the given context
    func createContextMenu(for range: NSRange, in textView: CodeEditorView) -> ContextMenuBuilder
}
