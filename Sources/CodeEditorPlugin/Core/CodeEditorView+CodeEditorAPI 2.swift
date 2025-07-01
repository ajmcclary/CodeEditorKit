import SwiftUI

#if canImport(UIKit)
import UIKit

struct ContentView: View {
    @State private var text = ""
    var body: some View {
        TextEditor(text: $text)
            .background(TextViewWrapper(text: $text))
    }
}

struct TextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextViewWrapper
        
        init(_ parent: TextViewWrapper) {
            self.parent = parent
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.insertText(text, replacementRange: range)
            #else
            // On iOS, UITextView does not support replacementRange
            textView.insertText(text)
            #endif
            return false
        }
        
        func someOtherMethod(textView: UITextView) {
            let text = "Hello"
            let range = NSRange(location: 0, length: 0)
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.insertText(text, replacementRange: range)
            #else
            textView.insertText(text)
            #endif
        }
    }
}
#endif

#if !canImport(UIKit)
struct FallbackContentView: View {
    var body: some View {
        Text("Not available on this platform")
    }
}
#endif

