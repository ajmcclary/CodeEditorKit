import SwiftUI
import AppKit

@main
struct CodeEditorSampleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.automatic)
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About CodeEditor Sample") {
                    showAboutWindow()
                }
            }
            
            CommandMenu("View") {
                Button("Toggle Line Numbers") {
                    NotificationCenter.default.post(name: .toggleLineNumbers, object: nil)
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
                
                Button("Toggle Invisible Characters") {
                    NotificationCenter.default.post(name: .toggleInvisibleCharacters, object: nil)
                }
                .keyboardShortcut("I", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Reset to Default Layout") {
                    NotificationCenter.default.post(name: .resetLayout, object: nil)
                }
            }
        }
    }
    
    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "CodeEditor Sample"
        alert.informativeText = "A comprehensive demonstration of the CodeEditorPlugin capabilities.\n\nVersion 1.0\n\nShowcasing syntax highlighting, line numbers, themes, and more."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app appears in the dock and can receive focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set app name in menu bar
        if let mainMenu = NSApp.mainMenu {
            if let appMenuItem = mainMenu.items.first {
                appMenuItem.title = "CodeEditor Sample"
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleLineNumbers = Notification.Name("toggleLineNumbers")
    static let toggleInvisibleCharacters = Notification.Name("toggleInvisibleCharacters")
    static let resetLayout = Notification.Name("resetLayout")
}