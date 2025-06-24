import AppKit
import CodeEditorPlugin

@main
@MainActor
struct EditableTest {
    static func main() async {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Editable Test"
        window.center()
        
        // Create STTextView
        let textView = STTextView(frame: window.contentView!.bounds)
        textView.text = "Type here to test editing..."
        textView.isEditable = true
        textView.isSelectable = true
        textView.showsLineNumbers = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        
        // Add autoresizing mask
        textView.autoresizingMask = [.width, .height]
        
        // Add to window
        window.contentView?.addSubview(textView)
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        
        // Make the text view first responder
        window.makeFirstResponder(textView)
        
        print("Text view acceptsFirstResponder: \(textView.acceptsFirstResponder)")
        print("Text view isFirstResponder: \(textView.window?.firstResponder == textView)")
        print("Text view isEditable: \(textView.isEditable)")
        print("Text view text: '\(textView.text ?? "")'")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}