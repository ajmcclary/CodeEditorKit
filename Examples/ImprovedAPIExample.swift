import Foundation
import CodeEditorPlugin
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Example: Using the Improved CodeEditor API

/// Example showing the simplified and improved API
class ImprovedAPIExample {
    
    // MARK: - Configuration-Driven Setup
    
    func setupWithConfiguration() {
        #if canImport(AppKit)
        let editor = CodeEditorView(frame: .zero)
        
        // Use predefined configurations
        editor.configuration = .default
        
        // Or customize configuration
        editor.configuration = EditorConfiguration(
            layout: .init(gutterWidth: 50),
            display: .init(
                showLineNumbers: true,
                highlightSelectedLine: true,
                enableAnnotations: true
            ),
            behavior: .init(
                isEditable: true,
                tabWidth: 2
            ),
            performance: .init(
                maxSyntaxHighlightingLength: 200_000
            )
        )
        
        // Or use builder pattern
        editor.configuration = EditorConfiguration.default
            .with(display: .init(showLineNumbers: false))
            .with(behavior: .readOnly)
        #endif
    }
    
    // MARK: - Event-Based Communication
    
    func setupEventHandling() {
        #if canImport(AppKit)
        let editor = CodeEditorView(frame: .zero)
        
        // Subscribe to events with closure
        let handler = ClosureEventHandler { event in
            switch event {
            case .textChanged(let newText, let range):
                print("Text changed in range \(range)")
                
            case .selectionChanged(let newSelection):
                print("Selection changed to \(newSelection)")
                
            case .languageChanged(let from, let to):
                print("Language changed from \(from.name) to \(to.name)")
                
            case .errorOccurred(let error):
                print("Error: \(error.localizedDescription)")
                
            case .lineCountChanged(let oldCount, let newCount):
                print("Line count: \(oldCount) → \(newCount)")
                
            default:
                break
            }
        }
        
        editor.eventPublisher.subscribe(handler)
        #endif
    }
    
    // MARK: - Language Registry
    
    func useLanguageRegistry() {
        #if canImport(AppKit)
        let editor = CodeEditorView(frame: .zero)
        
        // Register custom language
        let customLanguage = CustomLanguageProvider()
        LanguageRegistry.shared.register(customLanguage)
        
        // Auto-detect language from file extension
        if let provider = LanguageRegistry.shared.provider(forFileExtension: "py") {
            editor.language = .python  // Using built-in convenience
        }
        
        // List all available languages
        let languages = LanguageRegistry.shared.allLanguages
        print("Available languages: \(languages.map { $0.displayName })")
        #endif
    }
    
    // MARK: - Performance Monitoring
    
    func monitorPerformance() {
        #if canImport(AppKit)
        let editor = CodeEditorView(frame: .zero)
        
        // Performance is automatically monitored
        editor.eventPublisher.subscribe(ClosureEventHandler { event in
            if case .syntaxHighlightingCompleted(let tokensCount) = event {
                print("Highlighted \(tokensCount) tokens")
            }
        })
        
        // Get performance report
        let report = PerformanceMonitor.shared.generateReport()
        print(report.summary)
        #endif
    }
}

// MARK: - SwiftUI Example

#if canImport(SwiftUI) && canImport(AppKit)
@available(macOS 12.0, iOS 16.0, *)
struct ImprovedSwiftUIExample: View {
    @State private var code = """
    func hello() {
        print("Hello, World!")
    }
    """
    
    @State private var configuration = EditorConfiguration.default
    @State private var events: [String] = []
    
    var body: some View {
        VStack {
            // Simplified SwiftUI API
            CodeEditorSwiftUIView(
                text: $code,
                language: .swift,
                showLineNumbers: true,
                highlightSelectedLine: true,
                isEditable: true
            )
            .onTextChange { newText in
                events.append("Text changed: \(newText.count) characters")
            }
            .onSelectionChange { range in
                events.append("Selection: \(range)")
            }
            
            // Configuration presets
            HStack {
                Button("Default") {
                    configuration = .default
                }
                Button("Minimal") {
                    configuration = .minimal
                }
                Button("Performance") {
                    configuration = .performance
                }
                Button("Code Review") {
                    configuration = .codeReview
                }
            }
            .padding()
        }
    }
}
#endif

// MARK: - Custom Language Provider Example

struct CustomLanguageProvider: LanguageProvider {
    let identifier = "custom"
    let displayName = "Custom Language"
    let fileExtensions = ["custom", "cst"]
    
    @MainActor
    func createHighlighter() -> any SyntaxHighlighter {
        // Return custom highlighter implementation
        PlainTextHighlighter() // Simplified for example
    }
    
    func completionKeywords() -> [String] {
        ["BEGIN", "END", "IF", "THEN", "ELSE"]
    }
}

// MARK: - Benefits of the Improved Architecture

/*
 1. **Unified Configuration System**
    - No more magic numbers scattered throughout code
    - Centralized settings with sensible defaults
    - Easy to create and share configurations
 
 2. **Event-Based Communication**
    - Replace complex delegate pattern with simple events
    - Easy to subscribe/unsubscribe
    - Better for SwiftUI integration
 
 3. **Extensible Language System**
    - Register custom languages at runtime
    - Automatic language detection
    - Better separation of concerns
 
 4. **Performance Monitoring**
    - Built-in performance tracking
    - Identify bottlenecks easily
    - Configurable performance limits
 
 5. **Layout Coordination**
    - Prevents recursive layout cycles
    - Smooth animations
    - Better performance
 
 6. **Consistent API**
    - Same properties across platforms
    - Predictable behavior
    - Better documentation
 */