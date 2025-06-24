import AppKit
import CodeEditorPlugin

@main
struct IsFlippedTest {
    static func main() async {
        print("=== Testing STTextView isFlipped Issue ===")
        
        await MainActor.run {
            // Create STTextView
            let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            
            // Test 1: Check if STTextView itself is flipped
            print("1. STTextView isFlipped: \(textView.isFlipped)")
            if !textView.isFlipped {
                print("   ❌ FAIL: STTextView MUST be flipped for correct text rendering!")
            } else {
                print("   ✅ PASS: STTextView is correctly flipped")
            }
            
            // Test 2: Check if embedded in scroll view
            if let scrollView = textView.enclosingScrollView {
                let contentView = scrollView.contentView
                print("\n2. ContentView isFlipped: \(contentView.isFlipped)")
                if !contentView.isFlipped {
                    print("   ❌ FAIL: ContentView MUST be flipped!")
                } else {
                    print("   ✅ PASS: ContentView is correctly flipped")
                }
            } else {
                print("\n2. No enclosing scroll view found - this is expected for NSTextView-based implementation")
            }
            
            // Test 3: Check if NSScrollView itself needs isFlipped
            print("\n3. Checking NSScrollView superclass...")
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            print("   Default NSScrollView isFlipped: \(scrollView.isFlipped)")
            
            // Test 4: Enable line numbers and check gutter view
            print("\n4. Testing with line numbers enabled...")
            textView.showsLineNumbers = true
            textView.text = "Line 1\nLine 2\nLine 3"
            textView.layoutSubtreeIfNeeded()
            
            var foundGutter = false
            for subview in textView.subviews {
                if subview is STGutterView {
                    print("   Found GutterView, isFlipped: \(subview.isFlipped)")
                    foundGutter = true
                    if !subview.isFlipped {
                        print("   ❌ FAIL: GutterView MUST be flipped!")
                    } else {
                        print("   ✅ PASS: GutterView is correctly flipped")
                    }
                }
            }
            
            if !foundGutter {
                print("   ❌ FAIL: GutterView not found when line numbers are enabled!")
            }
            
            // Test 5: Check text rendering direction
            print("\n5. Testing text layout direction...")
            if let layoutManager = textView.layoutManager {
                let textStorage = textView.textStorage!
                let textLength = textStorage.length
                
                if textLength > 0 {
                    // Get line rectangles
                    let lineRange1 = (textView.string as NSString).lineRange(for: NSRange(location: 0, length: 0))
                    let lineRange2 = (textView.string as NSString).lineRange(for: NSRange(location: min(lineRange1.length + 1, textLength - 1), length: 0))
                    
                    if lineRange2.location < textLength {
                        let glyphRange1 = layoutManager.glyphRange(forCharacterRange: lineRange1, actualCharacterRange: nil)
                        let glyphRange2 = layoutManager.glyphRange(forCharacterRange: lineRange2, actualCharacterRange: nil)
                        
                        let rect1 = layoutManager.boundingRect(forGlyphRange: glyphRange1, in: textView.textContainer!)
                        let rect2 = layoutManager.boundingRect(forGlyphRange: glyphRange2, in: textView.textContainer!)
                        
                        print("   First line Y: \(rect1.origin.y)")
                        print("   Second line Y: \(rect2.origin.y)")
                        
                        if rect1.origin.y < rect2.origin.y {
                            print("   ✅ PASS: Text is laid out top-to-bottom (correct for flipped coordinates)")
                        } else {
                            print("   ❌ FAIL: Text is laid out bottom-to-top (WRONG - indicates coordinate system issue)")
                        }
                    } else {
                        print("   Not enough text to test layout direction")
                    }
                } else {
                    print("   No text to test layout direction")
                }
            } else {
                print("   No layout manager available")
            }
            
            print("\n=== Summary ===")
            print("If any tests failed above, STTextView needs to override isFlipped to return true.")
        }
    }
}

