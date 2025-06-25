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
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        appState.setCustomCode(clipboard)
                    }
                }
            }

            // Editor settings
            Section("Editor Settings") {
                // Line numbers
                Toggle("Show Line Numbers", isOn: $appState.currentConfiguration.showLineNumbers)

                // Invisible characters
                Toggle("Show Invisible Characters", isOn: $appState.currentConfiguration.showInvisibleCharacters)

                // Line wrapping
                Toggle("Wrap Lines", isOn: $appState.currentConfiguration.wrapLines)

                // Line highlighting
                Toggle("Highlight Current Line", isOn: $appState.currentConfiguration.highlightSelectedLine)

                // Editing
                Toggle("Enable Editing", isOn: $appState.currentConfiguration.isEditable)

                // Auto-indent
                Toggle("Auto Indent", isOn: $appState.currentConfiguration.autoIndent)
                
                // Insert spaces for tabs
                Toggle("Insert Spaces for Tabs", isOn: $appState.currentConfiguration.insertSpacesForTabs)
            }

            // Appearance settings
            Section("Appearance") {
                // Font size
                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(appState.currentConfiguration.fontSize))pt")
                        .font(.caption)
                    Slider(value: $appState.currentConfiguration.fontSize, in: 10 ... 32, step: 1)
                }

                // Tab width
                VStack(alignment: .leading) {
                    Text("Tab Width: \(appState.currentConfiguration.tabWidth) spaces")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(appState.currentConfiguration.tabWidth) },
                        set: { appState.currentConfiguration.tabWidth = Int($0) }
                    ), in: 2 ... 8, step: 1)
                }

                // Line spacing
                VStack(alignment: .leading) {
                    Text("Line Spacing: \(appState.currentConfiguration.lineSpacing, specifier: "%.1f")")
                        .font(.caption)
                    Slider(value: $appState.currentConfiguration.lineSpacing, in: 0 ... 10, step: 0.5)
                }
                
                // Text container inset
                VStack(alignment: .leading) {
                    Text("Text Container Inset: \(Int(appState.currentConfiguration.textContainerInset.width))pt")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { appState.currentConfiguration.textContainerInset.width },
                        set: { 
                            appState.currentConfiguration.textContainerInset = NSSize(width: $0, height: $0)
                        }
                    ), in: 0 ... 20, step: 1)
                }
                
                // Line fragment padding
                VStack(alignment: .leading) {
                    Text("Line Fragment Padding: \(Int(appState.currentConfiguration.lineFragmentPadding))pt")
                        .font(.caption)
                    Slider(value: $appState.currentConfiguration.lineFragmentPadding, in: 0 ... 20, step: 1)
                }
            }

            // Theme selection
            Section("Color Theme") {
                ForEach(ColorTheme.allCases, id: \.self) { theme in
                    ThemeRow(theme: theme, isSelected: appState.currentConfiguration.theme == theme)
                        .onTapGesture {
                            appState.currentConfiguration.theme = theme
                        }
                }
            }

            // Plugin settings
            Section("Plugins") {
                Toggle("Enable Annotations", isOn: $appState.currentConfiguration.enableAnnotations)
                Toggle("Enable Custom Plugin", isOn: $appState.currentConfiguration.enableCustomPlugin)
            }

            // Performance options
            Section("Performance") {
                Toggle("Use Hardware Acceleration", isOn: $appState.currentConfiguration.useHardwareAcceleration)
                Toggle("Enable Smooth Scrolling", isOn: $appState.currentConfiguration.smoothScrolling)
            }
            
            // Text Processing
            Section("Text Processing") {
                Toggle("Continuous Spell Checking", 
                       isOn: $appState.currentConfiguration.isContinuousSpellCheckingEnabled)
                Toggle("Grammar Checking", 
                       isOn: $appState.currentConfiguration.isGrammarCheckingEnabled)
                Toggle("Automatic Quote Substitution", 
                       isOn: $appState.currentConfiguration.isAutomaticQuoteSubstitutionEnabled)
                Toggle("Automatic Dash Substitution", 
                       isOn: $appState.currentConfiguration.isAutomaticDashSubstitutionEnabled)
                Toggle("Automatic Text Replacement", 
                       isOn: $appState.currentConfiguration.isAutomaticTextReplacementEnabled)
                Toggle("Automatic Spelling Correction", 
                       isOn: $appState.currentConfiguration.isAutomaticSpellingCorrectionEnabled)
                Toggle("Automatic Text Completion", 
                       isOn: $appState.currentConfiguration.isAutomaticTextCompletionEnabled)
                Toggle("Incremental Searching", 
                       isOn: $appState.currentConfiguration.isIncrementalSearchingEnabled)
            }
            
            // Advanced Settings
            Section("Advanced Settings") {
                Toggle("Allow Document Background Color Change", 
                       isOn: $appState.currentConfiguration.allowsDocumentBackgroundColorChange)
                Toggle("Allow Image Editing", 
                       isOn: $appState.currentConfiguration.allowsImageEditing)
                Toggle("Allow Character Picker Touch Bar Item", 
                       isOn: $appState.currentConfiguration.allowsCharacterPickerTouchBarItem)
                Toggle("Rich Text Mode", 
                       isOn: $appState.currentConfiguration.isRichText)
                Toggle("Import Graphics", 
                       isOn: $appState.currentConfiguration.importsGraphics)
                Toggle("Use Inspector Bar", 
                       isOn: $appState.currentConfiguration.usesInspectorBar)
                Toggle("Use Find Bar", 
                       isOn: $appState.currentConfiguration.usesFindBar)
                Toggle("Allow Non-Contiguous Layout", 
                       isOn: $appState.currentConfiguration.allowsNonContiguousLayout)
                Toggle("Display Link Tool Tips", 
                       isOn: $appState.currentConfiguration.displaysLinkToolTips)
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
            .background(Color(NSColor.controlBackgroundColor))
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
