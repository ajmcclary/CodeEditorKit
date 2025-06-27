import CodeEditorPlugin
import SwiftUI

// MARK: - SwiftUI Integration Demo

@available(macOS 12.0, iOS 16.0, *)
struct SwiftUIDemoView: View {
    @State private var sampleCode = SwiftSamples.swiftSample
    
    @StateObject private var appState = AppState()
    @State private var selectedLanguage: Language = .swift
    @State private var selectedTheme: CodeEditorSwiftUITheme = .default
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Controls
                controlsSection
                
                Divider()
                
                // Editor - Use consistent implementation across platforms
                SampleCodeEditorView(
                    configuration: appState.currentConfiguration,
                    text: $sampleCode,
                    language: selectedLanguage.name.lowercased()
                )
            }
        }
        .navigationTitle("SwiftUI Demo")
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    @ViewBuilder
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Language selection
            HStack {
                Text("Language:")
                    .font(.headline)
                Spacer()
                Picker("Language", selection: $selectedLanguage) {
                    Text("Swift").tag(Language.swift)
                    Text("Python").tag(Language.python)
                    Text("JavaScript").tag(Language.javascript)
                    Text("JSON").tag(Language.json)
                }
                .pickerStyle(.segmented)
            }
            
            // Theme selection
            HStack {
                Text("Theme:")
                    .font(.headline)
                Spacer()
                Picker("Theme", selection: $selectedTheme) {
                    Text("Default").tag(CodeEditorSwiftUITheme.default)
                    Text("Dark").tag(CodeEditorSwiftUITheme.dark)
                }
                .pickerStyle(.segmented)
            }
            
            // Configuration toggles
            VStack(spacing: 8) {
                Toggle("Show Line Numbers", isOn: $appState.currentConfiguration.display.showLineNumbers)
                Toggle("Highlight Selected Line", isOn: $appState.currentConfiguration.display.highlightSelectedLine)
                Toggle("Editable", isOn: $appState.currentConfiguration.behavior.isEditable)
            }
            
            // Sample code buttons
            VStack(spacing: 8) {
                HStack {
                    Button("Swift Sample") {
                        selectedLanguage = .swift
                        sampleCode = SwiftSamples.swiftSample
                    }
                    
                    Button("Python Sample") {
                        selectedLanguage = .python
                        sampleCode = PythonSamples.pythonSample
                    }
                }
                
                HStack {
                    Button("JavaScript Sample") {
                        selectedLanguage = .javascript
                        sampleCode = WebSamples.javascriptSample
                    }
                    
                    Button("JSON Sample") {
                        selectedLanguage = .json
                        sampleCode = jsonSample
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        #if canImport(AppKit)
        .background(Color(PlatformColors.controlBackground))
        #else
        .background(Color(.systemGray6))
        #endif
    }
}

// MARK: - Sample Code

@available(macOS 12.0, iOS 16.0, *)
extension SwiftUIDemoView {
    private var jsonSample: String {
        """
        {
          "name": "CodeEditor SwiftUI Demo",
          "version": "1.0.0",
          "description": "A demonstration of SwiftUI integration with CodeEditor",
          "features": [
            "Cross-platform support",
            "Multiple language syntax highlighting",
            "Customizable themes",
            "Real-time text binding",
            "Line numbers and selection highlighting"
          ],
          "platforms": {
            "macOS": "12.0+",
            "iOS": "16.0+",
            "iPadOS": "16.0+",
            "macCatalyst": "16.0+"
          },
          "configuration": {
            "showLineNumbers": true,
            "highlightSelectedLine": true,
            "isEditable": true,
            "theme": "default"
          }
        }
        """
    }
}

// MARK: - Preview

@available(macOS 12.0, iOS 16.0, *)
struct SwiftUIDemoView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIDemoView()
    }
}
