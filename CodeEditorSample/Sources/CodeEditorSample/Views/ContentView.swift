import CodeEditorPlugin
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    
    var body: some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            MacOSContentView()
        } else {
            Text("macOS 13.0 or later required")
        }
        #elseif os(iOS) || os(visionOS)
        if #available(iOS 16.0, *) {
            IOSContentView()
        } else {
            Text("iOS 16.0 or later required")
        }
        #endif
    }
}

// MARK: - macOS Content View

#if os(macOS)
@available(macOS 13.0, *)
struct MacOSContentView: View {
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
                                .background(Color(.controlBackgroundColor))

                            SampleCodeEditorView(
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
                                .background(Color(.controlBackgroundColor))

                            SampleCodeEditorView(
                                configuration: splitConfiguration,
                                text: $code,
                                language: selectedSample.fileExtension
                            )
                        }
                    }
                } else {
                    // Single editor
                    SampleCodeEditorView(
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
            configuration.display.showLineNumbers.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInvisibleCharacters)) { _ in
            configuration.display.showInvisibleCharacters.toggle()
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

@available(macOS 13.0, *)
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
                Toggle("Show Line Numbers", isOn: $configuration.display.showLineNumbers)
                Toggle("Show Invisible Characters", isOn: $configuration.display.showInvisibleCharacters)
                Toggle("Wrap Lines", isOn: $configuration.layout.wrapLines)
                Toggle("Highlight Current Line", isOn: $configuration.display.highlightSelectedLine)
                Toggle("Enable Editing", isOn: $configuration.behavior.isEditable)
                Toggle("Auto Indent", isOn: $configuration.behavior.autoIndent)
                Toggle("Insert Spaces for Tabs", isOn: $configuration.layout.insertSpacesForTabs)
            }

            // Appearance settings
            Section("Appearance") {
                // Font size
                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(configuration.display.fontSize))pt")
                        .font(.caption)
                    Slider(value: $configuration.display.fontSize, in: 10 ... 32, step: 1)
                }

                // Note: Theme selection removed as it's now handled through SwiftUI environment
                // Will be implemented through CodeEditor view modifiers
                Text("Theme selection available through CodeEditor view modifiers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Configuration")
    }
}
#endif
