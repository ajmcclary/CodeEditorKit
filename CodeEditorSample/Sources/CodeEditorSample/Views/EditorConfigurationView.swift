import SwiftUI

// MARK: - EditorConfigurationView

struct EditorConfigurationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            // Configuration presets
            Section("Configuration Presets") {
                ForEach(ConfigurationPreset.allCases, id: \.self) { preset in
                    PresetRow(preset: preset, isSelected: appState.selectedPreset == preset)
                        .onTapGesture {
                            appState.applyPreset(preset)
                        }
                }
            }

            // Sample code selection
            Section("Sample Code") {
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
                    Image(systemName: "doc.text")
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
                    // Show text input dialog or paste from clipboard
                    #if canImport(AppKit)
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        appState.setCustomCode(clipboard)
                    }
                    #else
                    // iOS doesn't have direct clipboard access like macOS
                    // For now, just clear the custom code
                    appState.setCustomCode("")
                    #endif
                }
            }

            // Editor settings
            Section("Editor Settings") {
                // Line numbers
                Toggle("Show Line Numbers", isOn: $appState.currentConfiguration.display.showLineNumbers)

                // Invisible characters
                Toggle("Show Invisible Characters",
                       isOn: $appState.currentConfiguration.display.showInvisibleCharacters)

                // Line wrapping
                Toggle("Wrap Lines", isOn: $appState.currentConfiguration.layout.wrapLines)

                // Line highlighting
                Toggle("Highlight Current Line", isOn: $appState.currentConfiguration.display.highlightSelectedLine)

                // Editing
                Toggle("Enable Editing", isOn: $appState.currentConfiguration.behavior.isEditable)

                // Auto-indent
                Toggle("Auto Indent", isOn: $appState.currentConfiguration.behavior.autoIndent)
                
                // Insert spaces for tabs
                Toggle("Insert Spaces for Tabs", isOn: $appState.currentConfiguration.layout.insertSpacesForTabs)
            }

            // Appearance settings
            Section("Appearance") {
                // Font size
                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(appState.currentConfiguration.display.fontSize))pt")
                        .font(.caption)
                    Slider(value: $appState.currentConfiguration.display.fontSize, in: 10 ... 32, step: 1)
                }

                // Tab width
                VStack(alignment: .leading) {
                    Text("Tab Width: \(appState.currentConfiguration.layout.tabWidth) spaces")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(appState.currentConfiguration.layout.tabWidth) },
                        set: { appState.currentConfiguration.layout.tabWidth = Int($0) }
                    ), in: 2 ... 8, step: 1)
                }

                // Line spacing
                VStack(alignment: .leading) {
                    Text("Line Spacing: \(appState.currentConfiguration.layout.lineSpacing, specifier: "%.1f")")
                        .font(.caption)
                    Slider(value: $appState.currentConfiguration.layout.lineSpacing, in: 0 ... 10, step: 0.5)
                }
                
                // Note: Text container inset and line fragment padding are now handled internally by the plugin
                Text("Text container inset and line fragment padding are now handled internally")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Note: Theme selection is now handled through SwiftUI environment
            Section("Color Theme") {
                Text("Theme selection available through CodeEditor view modifiers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Plugin settings
            Section("Plugins") {
                Toggle("Enable Annotations", isOn: $appState.currentConfiguration.display.enableAnnotations)
                Toggle("Enable Syntax Highlighting",
                       isOn: $appState.currentConfiguration.display.enableSyntaxHighlighting)
            }

            // Performance options
            Section("Performance") {
                Toggle("Use Hardware Acceleration",
                       isOn: $appState.currentConfiguration.performance.useHardwareAcceleration)
                Toggle("Enable Smooth Scrolling", isOn: $appState.currentConfiguration.performance.smoothScrolling)
            }
            
            // Text Processing
            Section("Text Processing") {
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
            }
            
            // Note: Advanced Settings removed as they are not part of the new configuration structure
            Section("Advanced Settings") {
                Text("Advanced text view settings are now handled internally by the plugin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Configuration")
    }
}

// MARK: - PresetRow

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

// MARK: - ThemeRow

struct ThemeRow: View {
    let theme: ColorTheme
    let isSelected: Bool

    var body: some View {
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
            #if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(.systemGray6))
            #endif
            .cornerRadius(4)

            Text(theme.displayName)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
