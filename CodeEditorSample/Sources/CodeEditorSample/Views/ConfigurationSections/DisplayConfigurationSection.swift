import CodeEditorPlugin
import SwiftUI

/// Display configuration section for the unified configuration view.
@available(macOS 13.0, iOS 16.0, *)
struct DisplayConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: adaptiveSectionSpacing()) {
            Toggle("Show Line Numbers", isOn: Binding(
                get: { appState.coordinator.configuration.display.isLineNumbersEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.isLineNumbersEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Highlight Current Line", isOn: Binding(
                get: { appState.coordinator.configuration.display.highlightSelectedLine },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.highlightSelectedLine = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Show Invisible Characters", isOn: Binding(
                get: { appState.coordinator.configuration.display.showInvisibleCharacters },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.showInvisibleCharacters = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Enable Syntax Highlighting", isOn: Binding(
                get: { appState.coordinator.configuration.display.enableSyntaxHighlighting },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.enableSyntaxHighlighting = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Enable Annotations", isOn: Binding(
                get: { appState.coordinator.configuration.display.enableAnnotations },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.enableAnnotations = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Show Indent Guides", isOn: Binding(
                get: { appState.coordinator.configuration.display.showIndentGuides },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.showIndentGuides = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Show Minimap", isOn: Binding(
                get: { appState.coordinator.configuration.display.showMinimap },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.showMinimap = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Enable Code Folding", isOn: Binding(
                get: { appState.coordinator.configuration.display.enableCodeFolding },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.enableCodeFolding = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            .help("Allow collapsing and expanding code sections like functions, classes, and blocks")
            
            Toggle("Show Folding Controls", isOn: Binding(
                get: { appState.coordinator.configuration.display.showFoldingControls },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.display.showFoldingControls = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            .help("Display ▶️/▼ fold/unfold buttons in the gutter")
            .disabled(!appState.coordinator.configuration.display.enableCodeFolding)
            
            // Minimum Foldable Lines
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Minimum Foldable Lines")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(appState.coordinator.configuration.display.minimumFoldableLines)")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(appState.coordinator.configuration.display.minimumFoldableLines) },
                        set: { newValue in
                            appState.coordinator.update { config in
                                config.display.minimumFoldableLines = Int(newValue)
                            }
                            appState.objectWillChange.send()
                        }
                    ),
                    in: 1...10,
                    step: 1
                )
                .accentColor(.blue)
                .disabled(!appState.coordinator.configuration.display.enableCodeFolding)
                
                Text("Minimum number of lines required for a code section to be foldable")
                    .font(.system(size: adaptiveControlHelpFontSize()))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Font Size
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Font Size")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.display.fontSize))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.display.fontSize },
                        set: { newValue in
                            appState.coordinator.update { config in
                                config.display.fontSize = newValue
                            }
                            appState.objectWillChange.send()
                        }
                    ),
                    in: 8...32,
                    step: 1
                )
                .accentColor(.blue)
            }
        }
        .padding(.horizontal, adaptiveHorizontalPadding())
    }
    
    // MARK: - Adaptive Layout Helpers
    
    private func adaptiveSectionSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    private func adaptiveControlSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 6
        case .medium, .large: return 8
        case .xLarge, .xxLarge: return 10
        case .xxxLarge: return 12
        default: return 8
        }
    }
    
    private func adaptiveHorizontalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 12
        case .medium, .large: return 16
        case .xLarge, .xxLarge: return 20
        case .xxxLarge: return 24
        default: return 16
        }
    }
    
    private func adaptiveControlLabelFontSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 13
        case .small: return 14
        case .medium: return 15
        case .large: return 16
        case .xLarge: return 18
        case .xxLarge: return 20
        case .xxxLarge: return 22
        default: return 15
        }
    }
    
    private func adaptiveControlValueFontSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 12
        case .small: return 13
        case .medium: return 14
        case .large: return 15
        case .xLarge: return 17
        case .xxLarge: return 19
        case .xxxLarge: return 21
        default: return 14
        }
    }
    
    private func adaptiveControlHelpFontSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 11
        case .small: return 12
        case .medium: return 13
        case .large: return 14
        case .xLarge: return 16
        case .xxLarge: return 18
        case .xxxLarge: return 20
        default: return 13
        }
    }
}
