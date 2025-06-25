import CodeEditorPlugin
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var configuration = ConfigurationPreset.fullFeatured.configuration
    @State private var selectedPreset: ConfigurationPreset = .fullFeatured
    @State private var selectedSample: SampleCode = .swift
    @State private var code: String = SampleCodeProvider.getCode(for: .swift)
    @State private var showConfigurationSidebar = true
    @State private var showFeatureTour = false
    @State private var showSplitView = false
    @State private var splitConfiguration = EditorConfiguration()

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
                // Toolbar
                EditorToolbar(
                    configuration: $configuration,
                    showSplitView: $showSplitView,
                    showFeatureTour: $showFeatureTour
                )

                Divider()

                // Editor area
                if showSplitView {
                    // Split view to compare configurations
                    HSplitView {
                        VStack(spacing: 0) {
                            Text("Configuration: \(selectedPreset.displayName)")
                                .font(.caption)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(Color(NSColor.controlBackgroundColor))

                            CodeEditorView(
                                configuration: configuration,
                                text: $code,
                                language: selectedSample.fileExtension
                            )
                        }

                        VStack(spacing: 0) {
                            Text("Configuration: Custom")
                                .font(.caption)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(Color(NSColor.controlBackgroundColor))

                            CodeEditorView(
                                configuration: splitConfiguration,
                                text: $code,
                                language: selectedSample.fileExtension
                            )
                        }
                    }
                } else {
                    // Single editor
                    CodeEditorView(
                        configuration: configuration,
                        text: $code,
                        language: selectedSample.fileExtension
                    )
                }

                Divider()

                // Status bar
                StatusBarView(textView: nil)
                    .frame(height: 24)
            }
        }
        .sheet(isPresented: $showFeatureTour) {
            FeatureTourView(isPresented: $showFeatureTour)
        }
        .navigationTitle("CodeEditor Sample")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    showFeatureTour = true
                } label: {
                    Label("Feature Tour", systemImage: "questionmark.circle")
                }

                Button {
                    if let window = NSApp.keyWindow {
                        ConfigurationExporter.exportConfiguration(configuration, from: window)
                    }
                } label: {
                    Label("Export Config", systemImage: "square.and.arrow.up")
                }

                Button {
                    if let window = NSApp.keyWindow {
                        ConfigurationExporter.importConfiguration(from: window) { imported in
                            if let config = imported {
                                Task { @MainActor in
                                    configuration = config
                                }
                            }
                        }
                    }
                } label: {
                    Label("Import Config", systemImage: "square.and.arrow.down")
                }
            }
        }
        .onAppear {
            // Initialize with sample code
            code = SampleCodeProvider.getCode(for: selectedSample)
            applyPreset(selectedPreset)
            splitConfiguration = ConfigurationPreset.minimal.configuration

            // Show feature tour on first launch
            if !UserDefaults.standard.bool(forKey: "hasSeenFeatureTour") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showFeatureTour = true
                    UserDefaults.standard.set(true, forKey: "hasSeenFeatureTour")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleLineNumbers)) { _ in
            configuration.showLineNumbers.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInvisibleCharacters)) { _ in
            configuration.showInvisibleCharacters.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetLayout)) { _ in
            applyPreset(.fullFeatured)
            selectedPreset = .fullFeatured
        }
    }

    private func applyPreset(_ preset: ConfigurationPreset) {
        configuration = preset.configuration
    }
}

// MARK: - ConfigurationSidebar

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
                    Slider(value: $configuration.fontSize, in: 10 ... 32, step: 1)
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
