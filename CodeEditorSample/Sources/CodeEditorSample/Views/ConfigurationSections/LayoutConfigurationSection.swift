import CodeEditorPlugin
import SwiftUI

/// Layout configuration section for the unified configuration view.
@available(macOS 13.0, iOS 16.0, *)
struct LayoutConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: adaptiveSectionSpacing()) {
            Toggle("Wrap Lines", isOn: Binding(
                get: { appState.coordinator.configuration.layout.wrapLines },
                set: { newValue in
                    appState.updateConfiguration { config in
                        config.layout.wrapLines = newValue
                    }
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Insert Spaces for Tabs", isOn: Binding(
                get: { appState.coordinator.configuration.layout.insertSpacesForTabs },
                set: { newValue in
                    appState.updateConfiguration { config in
                        config.layout.insertSpacesForTabs = newValue
                    }
                }
            ))
            .toggleStyle(.platform)
            
            // Note: showGutter is not available in the current EditorConfiguration
            
            // Tab Width
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Tab Width")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(appState.coordinator.configuration.layout.tabWidth) spaces")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(appState.coordinator.configuration.layout.tabWidth) },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.tabWidth = Int(newValue.clamped(to: 1...8))
                            }
                        }
                    ),
                    in: 1...8,
                    step: 1
                )
                .accentColor(.blue)
            }
            
            // Line Spacing
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Line Spacing")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text(String(format: "%.1fx", appState.coordinator.configuration.layout.lineSpacing))
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.lineSpacing },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.lineSpacing = newValue.clamped(to: 0.8...3.0)
                            }
                        }
                    ),
                    in: 0.8...3.0,
                    step: 0.1
                )
                .accentColor(.blue)
            }
            
            // Gutter Width
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Gutter Width")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.layout.gutterWidth))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.gutterWidth },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.gutterWidth = newValue.clamped(to: 20...100)
                            }
                        }
                    ),
                    in: 30...100,
                    step: 5
                )
                .accentColor(.blue)
            }
            
            // Line Number Padding
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Line Number Padding")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.layout.lineNumberPadding))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.lineNumberPadding },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.lineNumberPadding = newValue.clamped(to: 4...20)
                            }
                        }
                    ),
                    in: 4...20,
                    step: 1
                )
                .accentColor(.blue)
            }
            
            // Annotation Badge Size
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Annotation Badge Size")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.layout.annotationBadgeSize))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.annotationBadgeSize },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.annotationBadgeSize = newValue.clamped(to: 8...24)
                            }
                        }
                    ),
                    in: 8...24,
                    step: 1
                )
                .accentColor(.blue)
            }
            
            // Annotation Badge Padding
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Annotation Badge Padding")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.layout.annotationBadgePadding))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.annotationBadgePadding },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.annotationBadgePadding = newValue.clamped(to: 2...10)
                            }
                        }
                    ),
                    in: 2...12,
                    step: 1
                )
                .accentColor(.blue)
            }
            
            // Folding Control Size
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Folding Control Size")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.layout.foldingControlSize))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.foldingControlSize },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.foldingControlSize = newValue.clamped(to: 8...20)
                            }
                        }
                    ),
                    in: 8...20,
                    step: 1
                )
                .accentColor(.blue)
                .disabled(!appState.coordinator.configuration.display.enableCodeFolding)
                
                Text("Size of fold/unfold control buttons in the gutter")
                    .font(.system(size: adaptiveControlHelpFontSize()))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Folding Control Padding
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Folding Control Padding")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.layout.foldingControlPadding))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.foldingControlPadding },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.foldingControlPadding = newValue.clamped(to: 2...10)
                            }
                        }
                    ),
                    in: 1...8,
                    step: 1
                )
                .accentColor(.blue)
                .disabled(!appState.coordinator.configuration.display.enableCodeFolding)
                
                Text("Padding around folding control buttons")
                    .font(.system(size: adaptiveControlHelpFontSize()))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Minimap Width
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Minimap Width")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text("\(Int(appState.coordinator.configuration.layout.minimapWidth))pt")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { appState.coordinator.configuration.layout.minimapWidth },
                        set: { newValue in
                            appState.updateConfiguration { config in
                                config.layout.minimapWidth = newValue.clamped(to: 50...200)
                            }
                        }
                    ),
                    in: 80...200,
                    step: 10
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

// MARK: - Comparable Extension for Validation

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
