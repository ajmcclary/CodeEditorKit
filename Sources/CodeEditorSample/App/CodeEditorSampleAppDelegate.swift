#if canImport(AppKit)
import AppKit
import CodeEditorSwiftUI

/// Promotes the SwiftPM-launched binary to a regular macOS application:
/// it gets a Dock entry, a menu bar (so cmd-, opens Settings, cmd-Q quits,
/// the Window menu works), and stops behaving like a faceless background
/// agent. Without this, `swift run CodeEditorSample` produces a window
/// with no menu bar and no Dock icon.
final class CodeEditorSampleAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
#endif
