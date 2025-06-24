import Foundation
import AppKit

// Test file to verify STTextView text storage fix
// This test demonstrates that text updates now properly sync with NSTextContentStorage

func testSTTextViewTextStorageFix() {
    print("Testing STTextView text storage fix...")
    
    // Create a test instance
    let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    
    // Test 1: Setting initial text
    print("\nTest 1: Setting initial text")
    textView.text = "Hello, World!"
    
    if let storage = (textView.textContentManager as? NSTextContentStorage)?.textStorage {
        print("Text storage content: '\(storage.string)'")
        print("Expected: 'Hello, World!'")
        print("Success: \(storage.string == "Hello, World!")")
    }
    
    // Test 2: Replacing text
    print("\nTest 2: Replacing text")
    textView.text = "New text content"
    
    if let storage = (textView.textContentManager as? NSTextContentStorage)?.textStorage {
        print("Text storage content: '\(storage.string)'")
        print("Expected: 'New text content'")
        print("Success: \(storage.string == "New text content")")
    }
    
    // Test 3: Inserting text
    print("\nTest 3: Inserting text at position")
    if let range = NSTextRange(location: textView.textLayoutManager.documentRange.location) {
        textView.replaceCharacters(in: range, with: "Inserted: ")
        
        if let storage = (textView.textContentManager as? NSTextContentStorage)?.textStorage {
            print("Text storage content: '\(storage.string)'")
            print("Expected: 'Inserted: New text content'")
            print("Success: \(storage.string == "Inserted: New text content")")
        }
    }
    
    // Test 4: Empty text
    print("\nTest 4: Setting empty text")
    textView.text = ""
    
    if let storage = (textView.textContentManager as? NSTextContentStorage)?.textStorage {
        print("Text storage content: '\(storage.string)'")
        print("Expected: ''")
        print("Success: \(storage.string == "")")
    }
    
    print("\nAll tests completed!")
}

// Run the test
testSTTextViewTextStorageFix()