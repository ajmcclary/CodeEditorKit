#!/usr/bin/env swift

import Foundation
import CodeEditorPlugin

// Minimal debug script to test syntax highlighting
@MainActor
func debugSyntaxHighlighting() {
    print("=== Debugging Syntax Highlighting ===")
    
    // Test 1: Create a CodeEditorView
    let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    print("✅ Created CodeEditorView")
    
    // Test 2: Set some Swift code
    let swiftCode = """
    import Foundation
    
    func hello() {
        print("Hello, World!")
    }
    
    // TODO: Add more functionality
    let number = 42
    """
    textView.text = swiftCode
    print("✅ Set text content")
    print("Text length: \(textView.text?.count ?? 0)")
    
    // Test 3: Check configuration
    print("Syntax highlighting enabled: \(textView.configuration.display.enableSyntaxHighlighting)")
    print("Is syntax highlighting enabled property: \(textView.isSyntaxHighlightingEnabled)")
    
    // Test 4: Set language
    print("Setting language to Swift...")
    textView.setLanguage(fileExtension: "swift")
    print("Current language: \(textView.language)")
    
    // Test 5: Check if syntax highlighter is working
    let coordinator = SyntaxHighlightingCoordinator()
    let language = coordinator.detectLanguage(from: "swift")
    print("Detected language: \(language)")
    
    let tokens = coordinator.highlight(source: swiftCode, language: language)
    print("Generated \(tokens.count) tokens")
    
    // Test 6: Check each token
    for (index, token) in tokens.prefix(10).enumerated() {
        print("Token \(index): \(token.type) at \(token.range) - '\(token.text)'")
    }
    
    // Test 7: Check if AsyncSyntaxHighlighter is called
    print("=== Testing Async Highlighter ===")
    
    // Force immediate highlighting
    Task {
        let asyncHighlighter = AsyncSyntaxHighlighter()
        await asyncHighlighter.highlightImmediately(for: textView, language: language)
        print("✅ Async highlighting completed")
        
        // Check text storage for highlighting
        if let textStorage = textView.textStorage {
            let range = NSRange(location: 0, length: min(20, textStorage.length))
            let attributes = textStorage.attributes(at: 0, effectiveRange: nil)
            print("Text storage attributes at start: \(attributes)")
            
            // Check for foreground color attribute
            if let color = attributes[.foregroundColor] {
                print("✅ Found foreground color: \(color)")
            } else {
                print("❌ No foreground color found")
            }
        }
    }
}

// Run the debug
Task { @MainActor in
    await debugSyntaxHighlighting()
}

// Keep the script running for async operations
RunLoop.main.run(until: Date().addingTimeInterval(2))