#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
import SwiftUI

// MARK: - CodeEditorSampleApp

/// The main entry point for the CodeEditor Sample application.
///
/// This SwiftUI app demonstrates the capabilities of the CodeEditorPlugin
/// across multiple platforms (macOS, iOS, and Mac Catalyst) with a unified
/// interface that adapts to each platform's conventions.
///
/// ## Overview
///
/// The CodeEditor Sample application showcases:
/// - Syntax highlighting for 17+ programming languages
/// - Interactive configuration of editor settings
/// - Live preview of themes and customization options
/// - Advanced features like annotations and performance monitoring
/// - Cross-platform compatibility demonstrations
///
/// ## Platform Support
///
/// - **macOS**: Full-featured implementation with native menus and window management
/// - **iOS**: Touch-optimized interface with gesture support
/// - **Mac Catalyst**: Hybrid experience combining Mac and iOS elements
///
/// ## Key Features
///
/// The sample app includes:
/// - Live syntax highlighting demos for multiple languages
/// - Interactive configuration panel for all editor settings
/// - Sample code library with real-world examples
/// - Performance monitoring and metrics display
/// - Theme customization and preview
/// - Advanced annotation system demonstration
///
/// ## Usage
///
/// Run the app to explore CodeEditorPlugin features interactively:
/// ```swift
/// // The app automatically launches with the main content view
/// // Navigate through different sections to explore features
/// ```
///
/// - Note: On macOS, the app includes custom menu commands for common operations
///   like toggling line numbers and invisible characters.
///
/// - SeeAlso: ``UnifiedContentView`` for the main interface
/// - SeeAlso: ``AppDelegate`` for macOS-specific app lifecycle management
@main
struct CodeEditorSampleApp: App {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if #available(macOS 13.0, *) {
                UnifiedContentView()
                    .frame(minWidth: 1200, minHeight: 800)
            } else {
                Text("CodeEditor Sample requires macOS 13.0 or newer.")
                    .frame(width: 400, height: 100)
                    .padding()
            }
            #else
            UnifiedContentView()
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

/// Application delegate for macOS-specific functionality.
///
/// Handles macOS app lifecycle events and configures platform-specific
/// behaviors like dock appearance and menu bar setup.
///
/// ## Responsibilities
///
/// - Ensures the app appears in the dock and can receive focus
/// - Configures the app name in the menu bar
/// - Handles app termination behavior
///
/// ## Example
///
/// The delegate is automatically configured via `@NSApplicationDelegateAdaptor`:
/// ```swift
/// @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
/// ```
///
/// - Note: This delegate is only used on macOS, not on iOS or Mac Catalyst.
///
/// - SeeAlso: ``CodeEditorSampleApp`` for the main app structure
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

/// Custom notification names for app-wide communication.
///
/// These notifications enable communication between the menu system
/// and the editor views without tight coupling.
///
/// ## Available Notifications
///
/// - ``toggleLineNumbers``: Toggles line number display
/// - ``toggleInvisibleCharacters``: Toggles invisible character display
/// - ``resetLayout``: Resets the interface to default layout
///
/// ## Usage
///
/// Send notifications from menu actions:
/// ```swift
/// NotificationCenter.default.post(name: .toggleLineNumbers, object: nil)
/// ```
///
/// Listen for notifications in views:
/// ```swift
/// .onReceive(NotificationCenter.default.publisher(for: .toggleLineNumbers)) { _ in
///     // Handle line number toggle
/// }
/// ```
extension Notification.Name {
    /// Notification to toggle line number display in the editor.
    static let toggleLineNumbers = Notification.Name("toggleLineNumbers")
    
    /// Notification to toggle invisible character display in the editor.
    static let toggleInvisibleCharacters = Notification.Name("toggleInvisibleCharacters")
    
    /// Notification to reset the interface layout to defaults.
    static let resetLayout = Notification.Name("resetLayout")
}
