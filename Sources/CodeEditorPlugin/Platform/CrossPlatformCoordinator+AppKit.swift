#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import Foundation
import os.log

// MARK: - MacOS Specific Implementation

extension CrossPlatformCoordinator {
    func optimizeForMacOS(_ textView: CodeEditorView) {
        // Enable platform-specific features
        // Note: CodeEditorView doesn't currently support multiple selection
        
        // Set up rulers and guides
        if let scrollView = textView.enclosingScrollView {
            scrollView.rulersVisible = false // Can be toggled by user
        }
    }
    
    func setupMacOSNotifications() {
        // Workspace notifications
        let workspaceObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.debug("Application activated")
        }
        notificationObservers.append(workspaceObserver)
    }
    
    func handleMacOSKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        // Full keyboard shortcut support
        if modifiers.contains(.command) {
            switch key {
            case "d": selectNextOccurrence(in: textView); return true
            case "l": selectLine(in: textView); return true
            case "/": toggleComment(); return true
            default: break
            }
        }
        
        if modifiers.contains(.option) {
            switch key {
            case "↑": logger.debug("Move line up"); return true
            case "↓": logger.debug("Move line down"); return true
            default: break
            }
        }
        
        return false
    }
    
    func handleMacOSMouseInput(location: CGPoint, type: PlatformMouseEventType, in textView: CodeEditorView) -> Bool {
        switch type {
        case .rightClick:
            showContextMenu(at: location, in: textView)
            return true

        case .hover:
            // Show hover information
            logger.debug("Hover detected")
            return true

        default:
            return false
        }
    }
    
    // MARK: - MacOS Context Menu
    
    func createMacOSContextMenu(for _: CodeEditorView, at _: CGPoint) -> NSMenu {
        let menu = NSMenu()
        
        // Standard editing
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem.separator())
        
        // Code-specific actions
        let codeMenu = NSMenuItem(title: "Code", action: nil, keyEquivalent: "")
        let codeSubmenu = NSMenu()
        codeSubmenu.addItem(NSMenuItem(title: "Toggle Comment", action: #selector(toggleComment), keyEquivalent: "/"))
        codeSubmenu.addItem(NSMenuItem(title: "Format Selection", action: #selector(formatSelection), keyEquivalent: ""))
        codeSubmenu.addItem(NSMenuItem.separator())
        codeSubmenu.addItem(NSMenuItem(title: "Go to Definition", action: #selector(goToDefinition), keyEquivalent: ""))
        codeSubmenu.addItem(NSMenuItem(title: "Find References", action: #selector(findReferences), keyEquivalent: ""))
        codeMenu.submenu = codeSubmenu
        menu.addItem(codeMenu)
        
        return menu
    }
    
    // MARK: - MacOS Specific Actions
    
    @objc private func formatSelection() {
        logger.debug("Format selection requested")
        // Implementation would format selected code
    }
    
    @objc private func goToDefinition() {
        logger.debug("Go to definition requested")
        // Implementation would navigate to symbol definition
    }
    
    @objc private func findReferences() {
        logger.debug("Find references requested")
        // Implementation would find all references to symbol
    }
}
#endif
