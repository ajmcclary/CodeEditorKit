import CodeEditorPlugin
import SwiftUI

// MARK: - UnifiedConfigurationView

/// A comprehensive configuration view that exposes ALL EditorConfiguration options
/// Works consistently across macOS and iOS platforms
@available(macOS 13.0, iOS 16.0, *)
struct UnifiedConfigurationView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = ["Display", "Editor Settings"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search bar for filtering options
                searchBar
                
                // Configuration sections
                VStack(spacing: 12) {
                    // Presets section
                    ConfigurationSection(
                        title: "Configuration Presets",
                        systemImage: "slider.horizontal.3",
                        isExpanded: expandedSections.contains("Presets")
                    ) {
                        presetsContent
                    }
                    .onTapGesture {
                        toggleSection("Presets")
                    }
                    
                    // Display section
                    ConfigurationSection(
                        title: "Display",
                        systemImage: "eye",
                        isExpanded: expandedSections.contains("Display")
                    ) {
                        displayContent
                    }
                    .onTapGesture {
                        toggleSection("Display")
                    }
                    
                    // Layout section
                    ConfigurationSection(
                        title: "Layout",
                        systemImage: "rectangle.3.offgrid",
                        isExpanded: expandedSections.contains("Layout")
                    ) {
                        layoutContent
                    }
                    .onTapGesture {
                        toggleSection("Layout")
                    }
                    
                    // Editor Behavior section
                    ConfigurationSection(
                        title: "Editor Behavior",
                        systemImage: "keyboard",
                        isExpanded: expandedSections.contains("Behavior")
                    ) {
                        behaviorContent
                    }
                    .onTapGesture {
                        toggleSection("Behavior")
                    }
                    
                    // Text Input Features section
                    ConfigurationSection(
                        title: "Text Input Features",
                        systemImage: "text.cursor",
                        isExpanded: expandedSections.contains("TextInput")
                    ) {
                        textInputContent
                    }
                    .onTapGesture {
                        toggleSection("TextInput")
                    }
                    
                    // Performance section
                    ConfigurationSection(
                        title: "Performance",
                        systemImage: "speedometer",
                        isExpanded: expandedSections.contains("Performance")
                    ) {
                        performanceContent
                    }
                    .onTapGesture {
                        toggleSection("Performance")
                    }
                    
                    // Advanced Features section
                    ConfigurationSection(
                        title: "Advanced Features",
                        systemImage: "gearshape.2",
                        isExpanded: expandedSections.contains("Advanced")
                    ) {
                        advancedFeaturesContent
                    }
                    .onTapGesture {
                        toggleSection("Advanced")
                    }
                    
                    // Plugin System section
                    ConfigurationSection(
                        title: "Plugin System",
                        systemImage: "puzzlepiece.extension",
                        isExpanded: expandedSections.contains("Plugins")
                    ) {
                        pluginSystemContent
                    }
                    .onTapGesture {
                        toggleSection("Plugins")
                    }
                    
                    // Language Server section
                    ConfigurationSection(
                        title: "Language Server (LSP)",
                        systemImage: "network",
                        isExpanded: expandedSections.contains("LSP")
                    ) {
                        languageServerContent
                    }
                    .onTapGesture {
                        toggleSection("LSP")
                    }
                    
                    // Sample Code section
                    ConfigurationSection(
                        title: "Sample Code",
                        systemImage: "doc.text",
                        isExpanded: expandedSections.contains("Samples")
                    ) {
                        sampleCodeContent
                    }
                    .onTapGesture {
                        toggleSection("Samples")
                    }
                }
                
                // Import/Export buttons
                importExportButtons
            }
            .padding()
        }
        #if canImport(UIKit)
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
    
    // MARK: - Search Bar
    
    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search configuration options...", text: $searchText)
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                .textFieldStyle(.squareBorder)
                #else
                .textFieldStyle(.roundedBorder)
                #endif
        }
        .padding(.horizontal)
    }
    
    // MARK: - Presets Content
    
    @ViewBuilder
    private var presetsContent: some View {
        VStack(spacing: 8) {
            ForEach(ConfigurationPreset.allCases, id: \.self) { preset in
                PresetRow(preset: preset, isSelected: appState.selectedPreset == preset)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.applyPreset(preset)
                    }
            }
        }
    }
    
    // MARK: - Display Content
    
    @ViewBuilder
    private var displayContent: some View {
        VStack(spacing: 12) {
            // Core display options - using PlatformSafeToggle to avoid MainActor crashes
            PlatformSafeToggle("Show Line Numbers", isOn: $appState.coordinator.configuration.display.showLineNumbers)
            PlatformSafeToggle("Highlight Selected Line", isOn: $appState.coordinator.configuration.display.highlightSelectedLine)
            PlatformSafeToggle("Show Invisible Characters", isOn: $appState.coordinator.configuration.display.showInvisibleCharacters)
            PlatformSafeToggle("Enable Syntax Highlighting", isOn: $appState.coordinator.configuration.display.enableSyntaxHighlighting)
            PlatformSafeToggle("Enable Annotations", isOn: $appState.coordinator.configuration.display.enableAnnotations)
            PlatformSafeToggle("Show Indent Guides", isOn: $appState.coordinator.configuration.display.showIndentGuides)
            PlatformSafeToggle("Show Minimap", isOn: $appState.coordinator.configuration.display.showMinimap)
            // Additional display features coming soon
            VStack(alignment: .leading, spacing: 4) {
                Text("Additional Display Features (Coming Soon)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Code Folding, Visual Themes, Search Highlighting")
                        .font(.caption)
                }
            }
            
            // Font size
            SafeSlider(
                "Font Size",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.display.fontSize) },
                    set: { appState.coordinator.configuration.display.fontSize = CGFloat($0) }
                ),
                in: 10...32,
                step: 1.0,
                formatter: { "\(Int($0))pt" }
            )
        }
    }
    
    // MARK: - Layout Content
    
    @ViewBuilder
    private var layoutContent: some View {
        VStack(spacing: 12) {
            // Tab settings
            SafeSlider(
                "Tab Width",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.layout.tabWidth) },
                    set: { appState.coordinator.configuration.layout.tabWidth = Int($0) }
                ),
                in: 2...8,
                step: 1.0,
                formatter: { "\(Int($0)) spaces" }
            )
            
            PlatformSafeToggle("Insert Spaces for Tabs", isOn: $appState.coordinator.configuration.layout.insertSpacesForTabs)
            PlatformSafeToggle("Wrap Lines", isOn: $appState.coordinator.configuration.layout.wrapLines)
            
            // Line spacing
            SafeSlider(
                "Line Spacing",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.layout.lineSpacing) },
                    set: { appState.coordinator.configuration.layout.lineSpacing = CGFloat($0) }
                ),
                in: 1.0...3.0,
                step: 0.1,
                formatter: { String(format: "%.1f", $0) }
            )
            
            // Gutter settings
            SafeSlider(
                "Gutter Width",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.layout.gutterWidth) },
                    set: { appState.coordinator.configuration.layout.gutterWidth = CGFloat($0) }
                ),
                in: 40...100,
                step: 5.0,
                formatter: { "\(Int($0))pt" }
            )
            
            SafeSlider(
                "Line Number Padding",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.layout.lineNumberPadding) },
                    set: { appState.coordinator.configuration.layout.lineNumberPadding = CGFloat($0) }
                ),
                in: 4...16,
                step: 1.0,
                formatter: { "\(Int($0))pt" }
            )
            
            // Annotation settings
            SafeSlider(
                "Annotation Badge Size",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.layout.annotationBadgeSize) },
                    set: { appState.coordinator.configuration.layout.annotationBadgeSize = CGFloat($0) }
                ),
                in: 12...24,
                step: 1.0,
                formatter: { "\(Int($0))pt" }
            )
            
            SafeSlider(
                "Annotation Badge Padding",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.layout.annotationBadgePadding) },
                    set: { appState.coordinator.configuration.layout.annotationBadgePadding = CGFloat($0) }
                ),
                in: 2...8,
                step: 1.0,
                formatter: { "\(Int($0))pt" }
            )
        }
    }
    
    // MARK: - Behavior Content
    
    @ViewBuilder
    private var behaviorContent: some View {
        VStack(spacing: 12) {
            PlatformSafeToggle("Editable", isOn: $appState.coordinator.configuration.behavior.isEditable)
            PlatformSafeToggle("Selectable", isOn: $appState.coordinator.configuration.behavior.isSelectable)
            PlatformSafeToggle("Auto Indent", isOn: $appState.coordinator.configuration.behavior.autoIndent)
            PlatformSafeToggle("Auto Close Brackets", isOn: $appState.coordinator.configuration.behavior.autoCloseBrackets)
            PlatformSafeToggle("Auto Close Quotes", isOn: $appState.coordinator.configuration.behavior.autoCloseQuotes)
            PlatformSafeToggle("Enable Code Completion", isOn: $appState.coordinator.configuration.behavior.enableCodeCompletion)
            // Additional features coming soon
            VStack(alignment: .leading, spacing: 4) {
                Text("Advanced Features (Coming Soon)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Smart Completion, Multi-Cursor, Search & Replace")
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Text Input Content
    
    @ViewBuilder
    private var textInputContent: some View {
        VStack(spacing: 12) {
            PlatformSafeToggle("Continuous Spell Checking", 
                       isOn: $appState.coordinator.configuration.behavior.isContinuousSpellCheckingEnabled)
            PlatformSafeToggle("Grammar Checking", 
                       isOn: $appState.coordinator.configuration.behavior.isGrammarCheckingEnabled)
            PlatformSafeToggle("Automatic Quote Substitution", 
                       isOn: $appState.coordinator.configuration.behavior.isAutomaticQuoteSubstitutionEnabled)
            PlatformSafeToggle("Automatic Dash Substitution", 
                       isOn: $appState.coordinator.configuration.behavior.isAutomaticDashSubstitutionEnabled)
            PlatformSafeToggle("Automatic Text Replacement", 
                       isOn: $appState.coordinator.configuration.behavior.isAutomaticTextReplacementEnabled)
            PlatformSafeToggle("Automatic Spelling Correction", 
                       isOn: $appState.coordinator.configuration.behavior.isAutomaticSpellingCorrectionEnabled)
            PlatformSafeToggle("Automatic Text Completion", 
                       isOn: $appState.coordinator.configuration.behavior.isAutomaticTextCompletionEnabled)
            
            #if canImport(UIKit)
            Text("Note: Some text input features may have limited support on iOS")
                .font(.caption)
                .foregroundColor(.secondary)
            #endif
        }
    }
    
    // MARK: - Performance Content
    
    @ViewBuilder
    private var performanceContent: some View {
        VStack(spacing: 12) {
            PlatformSafeToggle("Hardware Acceleration", isOn: $appState.coordinator.configuration.performance.useHardwareAcceleration)
            PlatformSafeToggle("Smooth Scrolling", isOn: $appState.coordinator.configuration.performance.smoothScrolling)
            // Additional performance features coming soon
            VStack(alignment: .leading, spacing: 4) {
                Text("Advanced Performance Features (Coming Soon)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Performance Monitoring, Memory Optimization")
                        .font(.caption)
                }
            }
            
            // Max syntax highlighting length
            SafeSlider(
                "Max Syntax Highlighting",
                value: Binding(
                    get: { Double(appState.coordinator.configuration.performance.maxSyntaxHighlightingLength) },
                    set: { appState.coordinator.configuration.performance.maxSyntaxHighlightingLength = Int($0) }
                ),
                in: 10_000...1_000_000,
                step: 10_000,
                formatter: { formatBytes(Int($0)) }
            )
            
            // Text change debounce interval
            SafeSlider(
                "Text Change Debounce",
                value: $appState.coordinator.configuration.performance.textChangeDebounceInterval,
                in: 0.0...1.0,
                step: 0.1,
                formatter: { String(format: "%.1fs", $0) }
            )
        }
    }
    
    // MARK: - Advanced Features Content
    
    @ViewBuilder
    private var advancedFeaturesContent: some View {
        VStack(spacing: 12) {
            // Advanced feature status (read-only)
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Advanced Features")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Cross-Platform Coordination")
                        .font(.body)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Unified Event System")
                        .font(.body)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("TextKit Bridge")
                        .font(.body)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Viewport Management")
                        .font(.body)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Async Text Processing")
                        .font(.body)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Feature Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Core Features: Active")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Performance Optimizations: Enabled")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Platform Integration: Ready")
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Plugin System Content
    
    @ViewBuilder
    private var pluginSystemContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plugin System Architecture")
                    .font(.headline)
                
                Text("The CodeEditor Plugin includes a comprehensive plugin architecture designed for " +
                     "extensibility and security.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Plugin Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .foregroundColor(.blue)
                    Text("Core Plugin System: Ready")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "externaldrive.connected")
                        .foregroundColor(.orange)
                    Text("Marketplace Integration: Available")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.green)
                    Text("Security: Sandboxed")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Configuration coming in future release")
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Language Server Content
    
    @ViewBuilder
    private var languageServerContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Language Server Protocol (LSP)")
                    .font(.headline)
                
                Text("The CodeEditor Plugin includes LSP integration architecture for advanced language " +
                     "features like code completion, diagnostics, and semantic analysis.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("LSP Server Support")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                    Text("Protocol Support: LSP 3.17")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Swift: sourcekit-lsp")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("TypeScript: typescript-language-server")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Python: pylsp")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Configuration coming in future release")
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Sample Code Content
    
    @ViewBuilder
    private var sampleCodeContent: some View {
        VStack(spacing: 8) {
            ForEach(SampleCode.allCases, id: \.self) { sample in
                SampleCodeRow(
                    sample: sample,
                    isSelected: appState.selectedSample == sample && appState.customCode.isEmpty
                )
                .onTapGesture {
                    appState.selectSample(sample)
                }
            }
            
            // Custom code option
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.secondary)
                Text("Custom Code")
                Spacer()
                if !appState.customCode.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                #if canImport(AppKit)
                if let clipboard = NSPasteboard.general.string(forType: .string) {
                    appState.setCustomCode(clipboard)
                }
                #else
                // On iOS, we could show a text input sheet
                appState.setCustomCode("// Paste your custom code here")
                #endif
            }
        }
    }
    
    // MARK: - Import/Export Buttons
    
    @ViewBuilder
    private var importExportButtons: some View {
        HStack(spacing: 12) {
            PlatformSafeButton(action: exportConfiguration) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }
            
            PlatformSafeButton(action: importConfiguration) {
                Label("Import", systemImage: "square.and.arrow.down")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            PlatformSafeButton(action: resetConfiguration) {
                Label("Reset All", systemImage: "arrow.counterclockwise")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func toggleSection(_ section: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1_000 {
            return "\(bytes) bytes"
        } else if bytes < 1_000_000 {
            return "\(bytes / 1_000)KB"
        } else {
            return String(format: "%.1fMB", Double(bytes) / 1_000_000)
        }
    }
    
    private func exportConfiguration() {
        #if canImport(AppKit)
        if let window = NSApp.keyWindow {
            ConfigurationExporter.exportConfiguration(appState.coordinator.configuration, from: window)
        }
        #else
        // iOS export implementation would go here
        print("Export configuration: \(appState.coordinator.configuration)")
        #endif
    }
    
    private func importConfiguration() {
        #if canImport(AppKit)
        if let window = NSApp.keyWindow {
            ConfigurationExporter.importConfiguration(from: window) { imported in
                if let config = imported {
                    Task { @MainActor in
                        appState.currentConfiguration = config
                    }
                }
            }
        }
        #else
        // iOS import implementation would go here
        print("Import configuration")
        #endif
    }
    
    private func resetConfiguration() {
        appState.coordinator.reset()
        appState.selectedPreset = .fullFeatured
    }
}

// MARK: - ConfigurationSection

@available(macOS 13.0, iOS 16.0, *)
struct ConfigurationSection<Content: View>: View {
    let title: String
    let systemImage: String
    let isExpanded: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            
            // Section content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.leading, 28)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(PlatformColors.controlBackground))
        )
    }
}

// MARK: - PresetRow

@available(macOS 13.0, iOS 16.0, *)
struct PresetRow: View {
    let preset: ConfigurationPreset
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.displayName)
                    .font(.headline)
                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - SampleCodeRow

@available(macOS 13.0, iOS 16.0, *)
struct SampleCodeRow: View {
    let sample: SampleCode
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: sample.icon)
                .foregroundColor(sample.iconColor)
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text(sample.displayName)
                    .font(.body)
                Text(".\(sample.fileExtension)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

@available(macOS 13.0, iOS 16.0, *)
struct UnifiedConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedConfigurationView()
            .environmentObject(AppState())
    }
}
