import AppKit
import CodeEditorPlugin

@main
struct EditableTest {
    static func main() async {
        print("=== Testing STTextView Editable Issue ===")
        
        await MainActor.run {
            // Create STTextView
            let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            textView.text = "Initial text"
            
            // Test 1: Check default editability
            print("1. Default isEditable: \(textView.isEditable)")
            print("   Default isSelectable: \(textView.isSelectable)")
            
            // Test 2: Check if it accepts first responder
            print("\n2. acceptsFirstResponder: \(textView.acceptsFirstResponder)")
            
            // Test 3: Create a window and test responder chain
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                                styleMask: [.titled],
                                backing: .buffered,
                                defer: false)
            window.contentView?.addSubview(textView)
            window.makeKeyAndOrderFront(nil)
            
            let canBecomeFirstResponder = window.makeFirstResponder(textView)
            print("\n3. Can become first responder: \(canBecomeFirstResponder)")
            print("   Is first responder: \(window.firstResponder === textView)")
            
            // Test 4: Check if text input is possible
            print("\n4. Testing text input capability...")
            let originalText = textView.text
            
            // Try to insert text programmatically
            textView.insertText("Test", replacementRange: NSRange(location: NSNotFound, length: 0))
            let textChanged = textView.text != originalText
            print("   Text changed after insertText: \(textChanged)")
            if textChanged {
                print("   New text: '\(textView.text ?? "")'")
            }
            
            // Test 5: Check text view properties
            print("\n5. Checking text view properties...")
            print("   font: \(textView.font.displayName ?? "unknown")")
            print("   textColor: \(textView.textColor)")
            print("   backgroundColor: \(textView.backgroundColor)")
            
            print("\n=== Summary ===")
            if !textView.isEditable {
                print("❌ FAIL: Text view is not editable by default")
            } else if !canBecomeFirstResponder {
                print("❌ FAIL: Text view cannot become first responder")
            } else if !textChanged {
                print("❌ FAIL: Text view does not accept text input")
            } else {
                print("✅ PASS: Text view is editable and accepts input")
            }
        }
    }
}