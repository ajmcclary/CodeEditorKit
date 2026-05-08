import Foundation

#if canImport(UIKit)
import UIKit

// MARK: - UIKit Service Implementations

@MainActor
class UIKitMenuService: PlatformMenuService {
    func createContextMenu(from descriptor: MenuDescriptor) -> PlatformServiceMenu? {
        let actions = descriptor.items.map { item in
            UIAction(title: item.title) { _ in
                item.action()
            }
        }

        return UIMenu(title: "", children: actions)
    }

    func showContextMenu(_: PlatformServiceMenu, at _: CGPoint, in _: PlatformServiceView) {
        // UIKit handles context menus through UIContextMenuInteraction
        // This would typically be set up during view configuration
    }
}

@MainActor
class UIKitInputService: PlatformInputService {
    private var registeredShortcuts: [PlatformKeyboardShortcut: () -> Void] = [:]

    func handleKeyInput(key: String, modifiers: ModifierFlags, in _: PlatformServiceView) -> Bool {
        let shortcut = PlatformKeyboardShortcut(key: key, modifiers: modifiers)

        if let action = registeredShortcuts[shortcut] {
            action()
            return true
        }

        return false
    }

    func registerPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut, action: @escaping () -> Void) {
        registeredShortcuts[shortcut] = action
    }

    func unregisterPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut) {
        registeredShortcuts.removeValue(forKey: shortcut)
    }
}

@MainActor
class UIKitLayoutService: PlatformLayoutService {
    func calculatePreferredSize(for view: PlatformServiceView, fitting size: CGSize) -> CGSize {
        view.sizeThatFits(size)
    }

    func layoutSubviews(in container: PlatformServiceView) {
        container.layoutIfNeeded()
    }

    func animateLayoutChanges(duration: TimeInterval, animations: @escaping () -> Void, completion: (@Sendable (Bool) -> Void)?) {
        UIView.animate(withDuration: duration, animations: animations, completion: completion)
    }
}

#endif

#if canImport(AppKit)
import AppKit

// MARK: - AppKit Service Implementations

@MainActor
class AppKitMenuService: PlatformMenuService {
    func createContextMenu(from descriptor: MenuDescriptor) -> PlatformServiceMenu? {
        let menu = NSMenu()

        for item in descriptor.items {
            let menuItem = NSMenuItem(title: item.title, action: #selector(menuItemAction(_:)), keyEquivalent: "")
            menuItem.isEnabled = item.isEnabled
            menuItem.representedObject = item

            if let shortcut = item.shortcut {
                menuItem.keyEquivalent = shortcut.key
                menuItem.keyEquivalentModifierMask = convertModifierFlags(shortcut.modifiers)
            }

            menu.addItem(menuItem)
        }

        return menu
    }

    func showContextMenu(_ menu: PlatformServiceMenu, at _: CGPoint, in view: PlatformServiceView) {
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent ?? NSEvent(), for: view)
    }

    @objc private func menuItemAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuItem else { return }
        item.action()
    }

    private func convertModifierFlags(_ flags: ModifierFlags) -> NSEvent.ModifierFlags {
        var nsFlags: NSEvent.ModifierFlags = []

        if flags.contains(.command) {
            nsFlags.insert(.command)
        }
        if flags.contains(.option) {
            nsFlags.insert(.option)
        }
        if flags.contains(.control) {
            nsFlags.insert(.control)
        }
        if flags.contains(.shift) {
            nsFlags.insert(.shift)
        }

        return nsFlags
    }
}

@MainActor
class AppKitInputService: PlatformInputService {
    private var registeredShortcuts: [PlatformKeyboardShortcut: () -> Void] = [:]

    func handleKeyInput(key: String, modifiers: ModifierFlags, in _: PlatformServiceView) -> Bool {
        let shortcut = PlatformKeyboardShortcut(key: key, modifiers: modifiers)

        if let action = registeredShortcuts[shortcut] {
            action()
            return true
        }

        return false
    }

    func registerPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut, action: @escaping () -> Void) {
        registeredShortcuts[shortcut] = action
    }

    func unregisterPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut) {
        registeredShortcuts.removeValue(forKey: shortcut)
    }
}

@MainActor
class AppKitLayoutService: PlatformLayoutService {
    func calculatePreferredSize(for view: PlatformServiceView, fitting _: CGSize) -> CGSize {
        view.fittingSize
    }

    func layoutSubviews(in container: PlatformServiceView) {
        container.needsLayout = true
        container.layoutSubtreeIfNeeded()
    }

    func animateLayoutChanges(duration: TimeInterval, animations: @escaping () -> Void, completion: (@Sendable (Bool) -> Void)?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.allowsImplicitAnimation = true
            animations()
        } completionHandler: {
            completion?(true)
        }
    }
}

#endif

// MARK: - Mock Service Implementations (for platforms without UIKit/AppKit)

@MainActor
class MockMenuService: PlatformMenuService {
    func createContextMenu(from _: MenuDescriptor) -> PlatformServiceMenu? {
        nil
    }

    func showContextMenu(_: PlatformServiceMenu, at _: CGPoint, in _: PlatformServiceView) {
        // No-op for unsupported platforms
    }
}

@MainActor
class MockInputService: PlatformInputService {
    func handleKeyInput(key _: String, modifiers _: ModifierFlags, in _: PlatformServiceView) -> Bool {
        false
    }

    func registerPlatformKeyboardShortcut(_: PlatformKeyboardShortcut, action _: @escaping () -> Void) {
        // No-op for unsupported platforms
    }

    func unregisterPlatformKeyboardShortcut(_: PlatformKeyboardShortcut) {
        // No-op for unsupported platforms
    }
}

@MainActor
class MockLayoutService: PlatformLayoutService {
    func calculatePreferredSize(for _: PlatformServiceView, fitting size: CGSize) -> CGSize {
        size
    }

    func layoutSubviews(in _: PlatformServiceView) {
        // No-op for unsupported platforms
    }

    func animateLayoutChanges(duration _: TimeInterval, animations: @escaping () -> Void, completion: (@Sendable (Bool) -> Void)?) {
        animations()
        completion?(true)
    }
}

// MARK: - Extension for PlatformKeyboardShortcut Conformances

extension PlatformKeyboardShortcut: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(modifiers.rawValue)
    }

    public static func == (lhs: PlatformKeyboardShortcut, rhs: PlatformKeyboardShortcut) -> Bool {
        lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
    }
}
