import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var selectedLanguage: CodeLanguage = .javascript
    @State private var code = """
    // Paste your code here
    // The syntax highlighting will update based on the selected language
    """
    
    let languages: [(String, CodeLanguage)] = [
        ("JavaScript", .javascript),
        ("Swift", .swift),
        ("Python", .python),
        ("TypeScript", .typescript),
        ("Rust", .rust),
        ("Go", .go),
        ("Ruby", .ruby),
        ("Java", .java),
        ("C++", .cpp),
        ("HTML", .html),
        ("CSS", .css),
        ("JSON", .json)
    ]
    
    var body: some View {
        VStack {
            Text("Dynamic Language Switching")
                .font(.headline)
                .padding()
            
            // Language picker
            Picker("Language", selection: $selectedLanguage) {
                ForEach(languages, id: \.1) { name, language in
                    Text(name).tag(language)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            CodeEditor(text: $code)
                // Dynamically change the language
                .codeLanguage(selectedLanguage)
                .frame(minHeight: 400)
                .padding()
            
            // Sample code buttons
            HStack {
                Button("Load Swift Sample") {
                    selectedLanguage = .swift
                    code = """
                    struct ContentView: View {
                        @State private var count = 0
                        
                        var body: some View {
                            Button("Count: \\(count)") {
                                count += 1
                            }
                        }
                    }
                    """
                }
                
                Button("Load JS Sample") {
                    selectedLanguage = .javascript
                    code = """
                    const users = [
                        { name: 'Alice', age: 30 },
                        { name: 'Bob', age: 25 }
                    ];
                    
                    const adults = users.filter(u => u.age >= 18);
                    console.log(adults);
                    """
                }
                
                Button("Load Python Sample") {
                    selectedLanguage = .python
                    code = """
                    class DataProcessor:
                        def __init__(self):
                            self.data = []
                        
                        def process(self, items):
                            return [item * 2 for item in items if item > 0]
                    
                    processor = DataProcessor()
                    result = processor.process([1, -2, 3, 4])
                    """
                }
            }
            .padding()
        }
    }
}
