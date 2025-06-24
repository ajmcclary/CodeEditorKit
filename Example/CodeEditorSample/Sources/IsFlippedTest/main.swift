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
            
            // Test 2: Check NSScrollView's contentView
            let contentView = textView.contentView
            print("\n2. ContentView isFlipped: \(contentView.isFlipped)")
            if !contentView.isFlipped {
                print("   ❌ FAIL: ContentView MUST be flipped!")
            } else {
                print("   ✅ PASS: ContentView is correctly flipped")
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
            let layoutManager = textView.textLayoutManager
            var fragments: [(y: CGFloat, text: String)] = []
            
            layoutManager.enumerateTextLayoutFragments(
                from: layoutManager.documentRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                let y = fragment.layoutFragmentFrame.origin.y
                // For simplicity, just track Y positions
                fragments.append((y: y, text: "Line at Y: \(y)"))
                return true
            }
            
            if fragments.count >= 2 {
                print("   First line Y: \(fragments[0].y), text: '\(fragments[0].text)'")
                print("   Second line Y: \(fragments[1].y), text: '\(fragments[1].text)'")
                
                if fragments[0].y < fragments[1].y {
                    print("   ✅ PASS: Text is laid out top-to-bottom (correct for flipped coordinates)")
                } else {
                    print("   ❌ FAIL: Text is laid out bottom-to-top (WRONG - indicates coordinate system issue)")
                }
            }
            
            print("\n=== Summary ===")
            print("If any tests failed above, STTextView needs to override isFlipped to return true.")
        }
    }
}

