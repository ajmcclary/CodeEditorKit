#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
import SwiftUI

// MARK: - CodeEditorSampleApp

@main
struct CodeEditorSampleApp: App {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                .frame(minWidth: 1200, minHeight: 800)
                #endif
        }
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #endif
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "CodeEditor Sample"
        alert.informativeText = [
            "A comprehensive demonstration of the CodeEditorPlugin capabilities.",
            "",
            "Version 1.0",
            "",
            "Showcasing syntax highlighting, line numbers, themes, and more."
        ].joined(separator: "\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    #endif
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
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

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
#endif

// MARK: - Notification Names

extension Notification.Name {
    static let toggleLineNumbers = Notification.Name("toggleLineNumbers")
    static let toggleInvisibleCharacters = Notification.Name("toggleInvisibleCharacters")
    static let resetLayout = Notification.Name("resetLayout")
}
