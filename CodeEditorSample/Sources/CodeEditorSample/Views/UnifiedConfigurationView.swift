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
        #if os(iOS)
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
                #if os(macOS)
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
            // Core display options
            Toggle("Show Line Numbers", isOn: $appState.currentConfiguration.display.showLineNumbers)
            Toggle("Highlight Selected Line", isOn: $appState.currentConfiguration.display.highlightSelectedLine)
            Toggle("Show Invisible Characters", isOn: $appState.currentConfiguration.display.showInvisibleCharacters)
            Toggle("Enable Syntax Highlighting", isOn: $appState.currentConfiguration.display.enableSyntaxHighlighting)
            Toggle("Enable Annotations", isOn: $appState.currentConfiguration.display.enableAnnotations)
            Toggle("Show Indent Guides", isOn: $appState.currentConfiguration.display.showIndentGuides)
            Toggle("Show Minimap", isOn: $appState.currentConfiguration.display.showMinimap)
            
            // Font size
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(appState.currentConfiguration.display.fontSize))pt")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appState.currentConfiguration.display.fontSize, in: 10...32, step: 1)
            }
        }
    }
    
    // MARK: - Layout Content
    
    @ViewBuilder
    private var layoutContent: some View {
        VStack(spacing: 12) {
            // Tab settings
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tab Width")
                    Spacer()
                    Text("\(appState.currentConfiguration.layout.tabWidth) spaces")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(appState.currentConfiguration.layout.tabWidth) },
                        set: { appState.currentConfiguration.layout.tabWidth = Int($0) }
                    ),
                    in: 2...8,
                    step: 1
                )
            }
            
            Toggle("Insert Spaces for Tabs", isOn: $appState.currentConfiguration.layout.insertSpacesForTabs)
            Toggle("Wrap Lines", isOn: $appState.currentConfiguration.layout.wrapLines)
            
            // Line spacing
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Line Spacing")
                    Spacer()
                    Text("\(appState.currentConfiguration.layout.lineSpacing, specifier: "%.1f")")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appState.currentConfiguration.layout.lineSpacing, in: 1.0...3.0, step: 0.1)
            }
            
            // Gutter settings
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Gutter Width")
                    Spacer()
                    Text("\(Int(appState.currentConfiguration.layout.gutterWidth))pt")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appState.currentConfiguration.layout.gutterWidth, in: 40...100, step: 5)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Line Number Padding")
                    Spacer()
                    Text("\(Int(appState.currentConfiguration.layout.lineNumberPadding))pt")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appState.currentConfiguration.layout.lineNumberPadding, in: 4...16, step: 1)
            }
            
            // Annotation settings
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Annotation Badge Size")
                    Spacer()
                    Text("\(Int(appState.currentConfiguration.layout.annotationBadgeSize))pt")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appState.currentConfiguration.layout.annotationBadgeSize, in: 12...24, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Annotation Badge Padding")
                    Spacer()
                    Text("\(Int(appState.currentConfiguration.layout.annotationBadgePadding))pt")
                        .foregroundColor(.secondary)
                }
                Slider(value: $appState.currentConfiguration.layout.annotationBadgePadding, in: 2...8, step: 1)
            }
        }
    }
    
    // MARK: - Behavior Content
    
    @ViewBuilder
    private var behaviorContent: some View {
        VStack(spacing: 12) {
            Toggle("Editable", isOn: $appState.currentConfiguration.behavior.isEditable)
            Toggle("Selectable", isOn: $appState.currentConfiguration.behavior.isSelectable)
            Toggle("Auto Indent", isOn: $appState.currentConfiguration.behavior.autoIndent)
            Toggle("Auto Close Brackets", isOn: $appState.currentConfiguration.behavior.autoCloseBrackets)
            Toggle("Auto Close Quotes", isOn: $appState.currentConfiguration.behavior.autoCloseQuotes)
            Toggle("Enable Code Completion", isOn: $appState.currentConfiguration.behavior.enableCodeCompletion)
        }
    }
    
    // MARK: - Text Input Content
    
    @ViewBuilder
    private var textInputContent: some View {
        VStack(spacing: 12) {
            Toggle("Continuous Spell Checking", 
                   isOn: $appState.currentConfiguration.behavior.isContinuousSpellCheckingEnabled)
            Toggle("Grammar Checking", 
                   isOn: $appState.currentConfiguration.behavior.isGrammarCheckingEnabled)
            Toggle("Automatic Quote Substitution", 
                   isOn: $appState.currentConfiguration.behavior.isAutomaticQuoteSubstitutionEnabled)
            Toggle("Automatic Dash Substitution", 
                   isOn: $appState.currentConfiguration.behavior.isAutomaticDashSubstitutionEnabled)
            Toggle("Automatic Text Replacement", 
                   isOn: $appState.currentConfiguration.behavior.isAutomaticTextReplacementEnabled)
            Toggle("Automatic Spelling Correction", 
                   isOn: $appState.currentConfiguration.behavior.isAutomaticSpellingCorrectionEnabled)
            Toggle("Automatic Text Completion", 
                   isOn: $appState.currentConfiguration.behavior.isAutomaticTextCompletionEnabled)
            
            #if os(iOS)
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
            Toggle("Hardware Acceleration", isOn: $appState.currentConfiguration.performance.useHardwareAcceleration)
            Toggle("Smooth Scrolling", isOn: $appState.currentConfiguration.performance.smoothScrolling)
            
            // Max syntax highlighting length
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Max Syntax Highlighting")
                    Spacer()
                    Text("\(formatBytes(appState.currentConfiguration.performance.maxSyntaxHighlightingLength))")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(appState.currentConfiguration.performance.maxSyntaxHighlightingLength) },
                        set: { appState.currentConfiguration.performance.maxSyntaxHighlightingLength = Int($0) }
                    ),
                    in: 10_000...1_000_000,
                    step: 10_000
                )
            }
            
            // Text change debounce interval
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Text Change Debounce")
                    Spacer()
                    Text("\(appState.currentConfiguration.performance.textChangeDebounceInterval, specifier: "%.1f")s")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $appState.currentConfiguration.performance.textChangeDebounceInterval,
                    in: 0.0...1.0,
                    step: 0.1
                )
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
            Button(action: exportConfiguration) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            
            Button(action: importConfiguration) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(action: resetConfiguration) {
                Label("Reset All", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
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
            ConfigurationExporter.exportConfiguration(appState.currentConfiguration, from: window)
        }
        #else
        // iOS export implementation would go here
        print("Export configuration: \(appState.currentConfiguration)")
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
        appState.currentConfiguration = EditorConfiguration()
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
                #if canImport(AppKit)
                .fill(Color(NSColor.controlBackgroundColor))
                #else
                .fill(Color(.secondarySystemBackground))
                #endif
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
