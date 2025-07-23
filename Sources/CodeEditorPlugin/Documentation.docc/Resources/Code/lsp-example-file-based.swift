import SwiftUI
import CodeEditorPlugin

/// Example demonstrating LSP integration with file-based editing
struct LSPFileExampleView: View {
    @State private var code = ""
    @State private var fileURL: URL?
    @State private var configuration = EditorConfiguration()
    @State private var showFileImporter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Open File") {
                    showFileImporter = true
                }
                
                if let fileURL = fileURL {
                    Text(fileURL.lastPathComponent)
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(fileURL.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if configuration.workspaceRoot != nil {
                    Label("LSP Active", systemImage: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(white: 0.95))
            
            // Editor
            CodeEditor(text: $code)
                .environment(\.codeEditorConfiguration, configuration)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.sourceCode, .swiftSource, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadFile(url: url)
                }
            case .failure(let error):
                print("Error selecting file: \(error)")
            }
        }
    }
    
    private func loadFile(url: URL) {
        do {
            // Load file content
            let content = try String(contentsOf: url, encoding: .utf8)
            self.code = content
            self.fileURL = url
            
            // Update configuration with workspace root
            let workspaceRoot = findWorkspaceRoot(for: url)
            configuration.workspaceRoot = workspaceRoot
            
            // Update language based on file extension
            if let language = detectLanguage(for: url) {
                configuration.display.language = language
            }
            
            // Enable LSP features
            configuration.behavior.autoCompletion = true
            configuration.behavior.showCompletionOnTyping = true
            
            print("Loaded file: \(url.path)")
            print("Workspace root: \(workspaceRoot?.path ?? "None")")
            print("Language: \(configuration.display.language)")
            
        } catch {
            print("Error loading file: \(error)")
        }
    }
    
    private func findWorkspaceRoot(for fileURL: URL) -> URL? {
        var currentURL = fileURL.deletingLastPathComponent()
        
        // Look for common project indicators
        let projectIndicators = [
            ".git",
            "Package.swift",
            ".xcodeproj",
            ".xcworkspace",
            "Cargo.toml",
            "package.json",
            "pyproject.toml",
            "go.mod"
        ]
        
        while currentURL.path != "/" {
            for indicator in projectIndicators {
                let indicatorURL = currentURL.appendingPathComponent(indicator)
                if FileManager.default.fileExists(atPath: indicatorURL.path) {
                    return currentURL
                }
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        // If no project root found, use the file's directory
        return fileURL.deletingLastPathComponent()
    }
    
    private func detectLanguage(for url: URL) -> Language? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return .swift
        case "py": return .python
        case "js": return .javascript
        case "ts", "tsx": return .typescript
        case "go": return .go
        case "rs": return .rust
        case "c": return .c
        case "cpp", "cc", "cxx": return .cpp
        case "java": return .java
        case "rb": return .ruby
        case "php": return .php
        case "html", "htm": return .html
        case "css": return .css
        case "json": return .json
        case "yaml", "yml": return .yaml
        case "xml": return .xml
        case "md", "markdown": return .markdown
        case "sql": return .sql
        case "sh", "bash": return .shell
        default: return .plainText
        }
    }
}

// MARK: - Usage Example

struct LSPFileExampleApp: App {
    var body: some Scene {
        WindowGroup {
            LSPFileExampleView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}