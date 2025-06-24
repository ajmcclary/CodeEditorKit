import SwiftUI
import CodeEditorPlugin

struct ContentView: View {
    @State private var configuration = EditorConfiguration()
    @State private var selectedPreset: ConfigurationPreset = .fullFeatured
    @State private var selectedSample: SampleCode = .swift
    @State private var code: String = ""
    @State private var showConfigurationSidebar = true
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with configuration options
            ConfigurationSidebar(
                configuration: $configuration,
                selectedPreset: $selectedPreset,
                selectedSample: $selectedSample,
                code: $code
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            // Main editor view
            VStack(spacing: 0) {
                // Code editor
                CodeEditorView(
                    configuration: configuration,
                    text: $code,
                    language: selectedSample.fileExtension
                )
                .background(Color(configuration.theme.backgroundColor))
            }
        }
        .navigationTitle("CodeEditor Sample")
        .onAppear {
            // Initialize with sample code
            code = SampleCodeProvider.getCode(for: selectedSample)
            applyPreset(selectedPreset)
        }
    }
    
    private func applyPreset(_ preset: ConfigurationPreset) {
        configuration = preset.configuration
    }
}

// MARK: - Configuration Sidebar

struct ConfigurationSidebar: View {
    @Binding var configuration: EditorConfiguration
    @Binding var selectedPreset: ConfigurationPreset
    @Binding var selectedSample: SampleCode
    @Binding var code: String
    
    var body: some View {
        List {
            // Configuration presets
            Section("Configuration Presets") {
                ForEach(ConfigurationPreset.allCases, id: \.self) { preset in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.displayName)
                                .font(.headline)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedPreset == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPreset = preset
                        configuration = preset.configuration
                    }
                }
            }
            
            // Sample code selection
            Section("Sample Code") {
                ForEach(SampleCode.allCases, id: \.self) { sample in
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
                        
                        if selectedSample == sample {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSample = sample
                        code = SampleCodeProvider.getCode(for: sample)
                    }
                }
            }
            
            // Editor settings
            Section("Editor Settings") {
                Toggle("Show Line Numbers", isOn: $configuration.showLineNumbers)
                Toggle("Show Invisible Characters", isOn: $configuration.showInvisibleCharacters)
                Toggle("Wrap Lines", isOn: $configuration.wrapLines)
                Toggle("Highlight Current Line", isOn: $configuration.highlightSelectedLine)
                Toggle("Enable Editing", isOn: $configuration.isEditable)
            }
            
            // Appearance settings
            Section("Appearance") {
                // Font size
                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(configuration.fontSize))pt")
                        .font(.caption)
                    Slider(value: $configuration.fontSize, in: 10...32, step: 1)
                }
                
                // Theme selection
                ForEach(ColorTheme.allCases, id: \.self) { theme in
                    HStack {
                        // Theme preview
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(theme.backgroundColor))
                                .frame(width: 16, height: 16)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(theme.textColor))
                                .frame(width: 16, height: 16)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(theme.keywordColor))
                                .frame(width: 16, height: 16)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(theme.stringColor))
                                .frame(width: 16, height: 16)
                        }
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                        
                        Text(theme.displayName)
                        
                        Spacer()
                        
                        if configuration.theme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        configuration.theme = theme
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Configuration")
    }
}