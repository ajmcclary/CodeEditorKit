#if os(iOS) || os(visionOS)
import CodeEditorPlugin
import SwiftUI

// MARK: - iOS/iPadOS Specific Content View

@available(iOS 16.0, *)
struct IOSContentView: View {
    @StateObject private var appState = AppState()
    @State private var showingSampleCodePicker = false
    @State private var showingSettingsSheet = false
    @State private var selectedCodeSample: String = SwiftSamples.swiftSample
    @State private var currentLanguage: Language = .swift
    
    var body: some View {
        NavigationSplitView {
            // Sidebar for iPad, bottom bar for iPhone
            sidebarContent
        } detail: {
            editorContent
        }
        .sheet(isPresented: $showingSampleCodePicker) {
            SampleCodePickerView(
                selectedSample: $selectedCodeSample,
                selectedLanguage: $currentLanguage
            )
        }
        .sheet(isPresented: $showingSettingsSheet) {
            EditorSettingsView(appState: appState)
        }
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        List {
            Section("Quick Actions") {
                NavigationLink("Swift Examples") {
                    LanguageExamplesView(language: .swift, samples: SwiftSamples.allSamples)
                }
                
                NavigationLink("Python Examples") {
                    LanguageExamplesView(language: .python, samples: PythonSamples.allSamples)
                }
                
                NavigationLink("JavaScript Examples") {
                    LanguageExamplesView(language: .javascript, samples: WebSamples.allSamples)
                }
                
                NavigationLink("Configuration") {
                    ConfigurationView()
                }
            }
            
            Section("Features") {
                NavigationLink("SwiftUI Integration") {
                    SwiftUIDemoView()
                }
                
                NavigationLink("TextKit 2 Demo") {
                    TextKit2DemoView()
                }
                
                NavigationLink("Performance Test") {
                    PerformanceTestView()
                }
                
                NavigationLink("Annotation System") {
                    AnnotationDemoView()
                }
            }
        }
        .navigationTitle("CodeEditor")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings") {
                    showingSettingsSheet = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var editorContent: some View {
        VStack(spacing: 0) {
            // Toolbar for iPhone/compact layouts
            if UIDevice.current.userInterfaceIdiom == .phone {
                toolbarContent
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
            }
            
            // Main editor
            CodeEditorSwiftUIView(
                text: $selectedCodeSample,
                language: currentLanguage,
                showLineNumbers: appState.currentConfiguration.showLineNumbers,
                highlightSelectedLine: appState.currentConfiguration.highlightSelectedLine
            )
            .ignoresSafeArea(.keyboard)
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if UIDevice.current.userInterfaceIdiom == .pad {
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarContent
                }
            }
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        Button("Samples") {
            showingSampleCodePicker = true
        }
        .foregroundColor(.accentColor)
        
        Picker("Language", selection: $currentLanguage) {
            ForEach([Language.swift, .python, .javascript, .plainText], id: \.self) { language in
                Text(language.displayName).tag(language)
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: - Language Examples View

@available(iOS 16.0, *)
struct LanguageExamplesView: View {
    let language: Language
    let samples: [String: String]
    @StateObject private var appState = AppState()
    @State private var selectedSample: String = ""
    
    var body: some View {
        List {
            ForEach(Array(samples.keys.sorted()), id: \.self) { key in
                NavigationLink(key) {
                    CodeEditorSwiftUIView(
                        text: .constant(samples[key] ?? ""),
                        language: language,
                        configuration: appState.currentConfiguration
                    )
                    .navigationTitle(key)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .navigationTitle("\(language.displayName) Examples")
    }
}

// MARK: - Sample Code Picker

@available(iOS 16.0, *)
struct SampleCodePickerView: View {
    @Binding var selectedSample: String
    @Binding var selectedLanguage: Language
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Swift") {
                    ForEach(Array(SwiftSamples.allSamples.keys.sorted()), id: \.self) { key in
                        Button(key) {
                            selectedSample = SwiftSamples.allSamples[key] ?? ""
                            selectedLanguage = .swift
                            dismiss()
                        }
                    }
                }
                
                Section("Python") {
                    ForEach(Array(PythonSamples.allSamples.keys.sorted()), id: \.self) { key in
                        Button(key) {
                            selectedSample = PythonSamples.allSamples[key] ?? ""
                            selectedLanguage = .python
                            dismiss()
                        }
                    }
                }
                
                Section("JavaScript") {
                    ForEach(Array(WebSamples.allSamples.keys.sorted()), id: \.self) { key in
                        Button(key) {
                            selectedSample = WebSamples.allSamples[key] ?? ""
                            selectedLanguage = .javascript
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Sample Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - TextKit 2 Demo View

@available(iOS 16.0, *)
struct TextKit2DemoView: View {
    @State private var demoText = """
    // TextKit 2 Features Demo
    
    This demonstrates enhanced TextKit 2 capabilities:
    
    1. Viewport-based rendering optimization
    2. Advanced line fragment enumeration  
    3. Cross-platform rendering attributes
    4. Improved range conversion utilities
    
    // Test syntax highlighting
    func exampleFunction() {
        let message = "Hello, TextKit 2!"
        print(message)
    }
    """
    @StateObject private var appState = AppState()
    
    var body: some View {
        VStack {
            Text("TextKit 2 Enhanced Features")
                .font(.headline)
                .padding()
            
            CodeEditorSwiftUIView(
                text: $demoText,
                language: .swift,
                configuration: appState.currentConfiguration
            )
        }
        .navigationTitle("TextKit 2 Demo")
    }
}

// MARK: - Performance Test View

@available(iOS 16.0, *)
struct PerformanceTestView: View {
    @State private var largeText = ""
    @State private var isGenerating = false
    @StateObject private var appState = AppState()
    
    var body: some View {
        VStack {
            if isGenerating {
                ProgressView("Generating large text...")
                    .padding()
            } else {
                Button("Generate Large Text File") {
                    generateLargeText()
                }
                .padding()
            }
            
            CodeEditorSwiftUIView(
                text: $largeText,
                language: .swift,
                configuration: appState.currentConfiguration
            )
        }
        .navigationTitle("Performance Test")
    }
    
    private func generateLargeText() {
        isGenerating = true
        
        Task {
            var text = ""
            for index in 1...1000 {
                text += """
                // Line \(index)
                func function\(index)() {
                    let value = \(index)
                    print("Processing item \\(value)")
                    return value * 2
                }
                
                """
            }
            
            await MainActor.run {
                largeText = text
                isGenerating = false
            }
        }
    }
}

// MARK: - Annotation Demo View

@available(iOS 16.0, *)
struct AnnotationDemoView: View {
    @State private var annotatedCode = """
    // Annotation System Demo
    
    // TODO: Implement user authentication
    func loginUser() {
        // FIXME: This should use secure storage
        let password = "123456"
        
        // NOTE: Remember to validate input
        if password.isEmpty {
            // WARNING: Weak password validation
            return
        }
        
        // ERROR: This will cause a crash
        fatalError("Not implemented")
    }
    """
    @StateObject private var appState = AppState()
    
    var body: some View {
        VStack {
            Text("Annotation System")
                .font(.headline)
                .padding()
            
            Text("This demo shows TODO, FIXME, NOTE, WARNING, and ERROR annotations")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            CodeEditorSwiftUIView(
                text: $annotatedCode,
                language: .swift,
                configuration: appState.currentConfiguration
            )
        }
        .navigationTitle("Annotations")
    }
}

// MARK: - Editor Settings View

@available(iOS 16.0, *)
struct EditorSettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Display") {
                    Toggle("Show Line Numbers", isOn: $appState.currentConfiguration.showLineNumbers)
                    Toggle("Highlight Selected Line", isOn: $appState.currentConfiguration.highlightSelectedLine)
                }
                
                Section("Editor") {
                    // TODO: Add syntax highlighting toggle when available
                    Toggle("Show Invisible Characters", isOn: $appState.currentConfiguration.showInvisibleCharacters)
                }
                
                Section("Performance") {
                    Toggle("Hardware Acceleration", isOn: $appState.currentConfiguration.useHardwareAcceleration)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Configuration View

@available(iOS 16.0, *)
struct ConfigurationView: View {
    @State private var configText = ConfigSamples.jsonSample
    @StateObject private var appState = AppState()
    
    var body: some View {
        CodeEditorSwiftUIView(
            text: $configText,
            language: .json,
            configuration: appState.currentConfiguration
        )
        .navigationTitle("Configuration")
    }
}

// MARK: - Language Extension

private extension Language {
    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .json: return "JSON"
        case .plainText: return "Plain Text"
        default: return "Unknown"
        }
    }
}

// MARK: - CodeEditorSwiftUIView Configuration Extension

@available(iOS 16.0, *)
extension CodeEditorSwiftUIView {
    /// Convenience initializer that takes EditorConfiguration
    init(
        text: Binding<String>,
        language: Language = .plainText,
        configuration: EditorConfiguration,
        theme: CodeEditorSwiftUITheme = .default,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self.init(
            text: text,
            language: language,
            showLineNumbers: configuration.showLineNumbers,
            highlightSelectedLine: configuration.highlightSelectedLine,
            isEditable: configuration.isEditable,
            theme: theme,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
    }
}

#endif
