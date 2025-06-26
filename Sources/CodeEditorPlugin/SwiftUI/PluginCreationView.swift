import os.log
import SwiftUI

/// SwiftUI view for creating new plugins
@MainActor
public struct PluginCreationView: View {
    // MARK: - Properties
    
    @ObservedObject private var pluginManager: PluginManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var pluginName = ""
    @State private var pluginIdentifier = ""
    @State private var pluginDescription = ""
    @State private var pluginAuthor = ""
    @State private var pluginVersion = "1.0.0"
    @State private var selectedLanguages: Set<String> = []
    @State private var selectedTemplate: PluginTemplate = .basic
    @State private var outputPath = ""
    @State private var isCreating = false
    @State private var creationProgress: Double = 0.0
    @State private var creationStatus = ""
    @State private var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "PluginCreationView")
    
    // MARK: - Types
    
    enum PluginTemplate: String, CaseIterable {
        case basic = "Basic Plugin"
        case syntaxHighlighter = "Syntax Highlighter"
        case completionProvider = "Completion Provider"
        case formatter = "Code Formatter"
        case linter = "Code Linter"
        case lspClient = "LSP Client"
        case fullFeatured = "Full Featured"
        
        var description: String {
            switch self {
            case .basic:
                return "A minimal plugin with basic structure"

            case .syntaxHighlighter:
                return "Plugin focused on syntax highlighting"

            case .completionProvider:
                return "Plugin providing code completion"

            case .formatter:
                return "Plugin for code formatting"

            case .linter:
                return "Plugin for code linting and analysis"

            case .lspClient:
                return "Plugin with Language Server Protocol support"

            case .fullFeatured:
                return "Complete plugin with all features"
            }
        }
        
        var icon: String {
            switch self {
            case .basic: return "doc.text"
            case .syntaxHighlighter: return "paintbrush"
            case .completionProvider: return "text.cursor"
            case .formatter: return "textformat"
            case .linter: return "checkmark.shield"
            case .lspClient: return "network"
            case .fullFeatured: return "star.fill"
            }
        }
        
        var capabilities: [String] {
            switch self {
            case .basic:
                return ["Basic structure"]

            case .syntaxHighlighter:
                return ["Syntax highlighting", "Token recognition"]

            case .completionProvider:
                return ["Code completion", "Context awareness"]

            case .formatter:
                return ["Code formatting", "Style configuration"]

            case .linter:
                return ["Code analysis", "Error detection", "Warnings"]

            case .lspClient:
                return ["LSP integration", "External tool support"]

            case .fullFeatured:
                return ["All features", "Complete implementation"]
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Plugin information
                    pluginInfoSection
                    
                    // Template selection
                    templateSelectionSection
                    
                    // Language selection
                    languageSelectionSection
                    
                    // Output configuration
                    outputConfigurationSection
                    
                    // Creation progress
                    if isCreating {
                        creationProgressView
                    }
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Create Plugin")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Creation Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onChange(of: pluginName) { newValue in
                updatePluginIdentifier(from: newValue)
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var pluginInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plugin Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Name")
                        .frame(width: 80, alignment: .leading)
                    TextField("My Awesome Plugin", text: $pluginName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("Identifier")
                        .frame(width: 80, alignment: .leading)
                    TextField("com.example.my-plugin", text: $pluginIdentifier)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Description")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                    }
                    TextEditor(text: $pluginDescription)
                        .frame(height: 80)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        )
                }
                
                HStack {
                    Text("Author")
                        .frame(width: 80, alignment: .leading)
                    TextField("Your Name", text: $pluginAuthor)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Text("Version")
                        .frame(width: 80, alignment: .leading)
                    TextField("1.0.0", text: $pluginVersion)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 120)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var templateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plugin Template")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PluginTemplate.allCases, id: \.self) { template in
                    TemplateCard(
                        template: template,
                        isSelected: selectedTemplate == template
                    )                        { selectedTemplate = template }
                }
            }
        }
    }
    
    @ViewBuilder
    private var languageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported Languages")
                .font(.headline)
            
            Text("Select the programming languages your plugin will support:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(availableLanguages, id: \.self) { language in
                    LanguageToggle(
                        language: language,
                        isSelected: selectedLanguages.contains(language)
                    )                        { toggleLanguage(language) }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var outputConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Output Configuration")
                .font(.headline)
            
            HStack {
                Text("Output Path")
                    .frame(width: 100, alignment: .leading)
                
                TextField("~/Desktop/MyPlugin", text: $outputPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Browse") {
                    browseForOutputPath()
                }
                .buttonStyle(.bordered)
            }
            
            Text("The plugin will be created in this directory with a complete project structure.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var creationProgressView: some View {
        VStack(spacing: 12) {
            ProgressView(value: creationProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(creationStatus)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                if isCreating {
                    cancelCreation()
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(isCreating ? "Creating..." : "Create Plugin") {
                createPlugin()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCreating || !isCreateEnabled)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isCreateEnabled: Bool {
        !pluginName.isEmpty &&
        !pluginIdentifier.isEmpty &&
        !pluginAuthor.isEmpty &&
        !outputPath.isEmpty &&
        !selectedLanguages.isEmpty
    }
    
    private var availableLanguages: [String] {
        [
            "Swift", "JavaScript", "TypeScript", "Python", "Java",
            "C++", "C", "Rust", "Go", "Kotlin", "Ruby", "PHP",
            "HTML", "CSS", "JSON", "XML", "Markdown", "YAML"
        ]
    }
    
    // MARK: - Actions
    
    private func updatePluginIdentifier(from name: String) {
        // Auto-generate identifier from name
        let cleanName = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        
        if !cleanName.isEmpty {
            pluginIdentifier = "com.example.\(cleanName)"
        }
    }
    
    private func toggleLanguage(_ language: String) {
        if selectedLanguages.contains(language) {
            selectedLanguages.remove(language)
        } else {
            selectedLanguages.insert(language)
        }
    }
    
    private func browseForOutputPath() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                outputPath = url.path
            }
        }
        #endif
    }
    
    private func createPlugin() {
        isCreating = true
        creationProgress = 0.0
        errorMessage = nil
        
        Task {
            do {
                await generatePluginStructure()
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isCreating = false
                }
            }
        }
    }
    
    private func generatePluginStructure() async {
        creationStatus = "Creating plugin directory structure..."
        creationProgress = 0.1
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        creationStatus = "Generating manifest file..."
        creationProgress = 0.3
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        creationStatus = "Creating source files..."
        creationProgress = 0.5
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        creationStatus = "Generating template code..."
        creationProgress = 0.7
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        creationStatus = "Finalizing plugin structure..."
        creationProgress = 0.9
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        creationStatus = "Plugin created successfully!"
        creationProgress = 1.0
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // In a real implementation, this would:
        // 1. Create the plugin directory structure
        // 2. Generate the plugin manifest file
        // 3. Create template source files based on selected template
        // 4. Generate language-specific implementations
        // 5. Create build configuration files
        // 6. Generate documentation templates
        
        logger.info("Plugin created: \(pluginName) at \(outputPath)")
    }
    
    private func cancelCreation() {
        isCreating = false
        creationProgress = 0.0
        creationStatus = ""
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: PluginCreationView.PluginTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .accentColor)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                
                Text(template.rawValue)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
                
                Divider()
                    .overlay(isSelected ? Color.white.opacity(0.3) : Color.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Features:")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .secondary)
                    
                    ForEach(template.capabilities.prefix(3), id: \.self) { capability in
                        Text("• \(capability)")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
            .padding()
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Language Toggle

struct LanguageToggle: View {
    let language: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(language)
                    .font(.body)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct PluginCreationView_Previews: PreviewProvider {
    static var previews: some View {
        PluginCreationView(pluginManager: PluginManager())
            .previewDisplayName("Plugin Creation")
    }
}
#endif
