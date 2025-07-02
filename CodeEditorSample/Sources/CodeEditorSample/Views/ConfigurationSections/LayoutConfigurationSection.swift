import CodeEditorPlugin
import SwiftUI

/// Layout configuration section for the unified configuration view.
@available(macOS 13.0, iOS 16.0, *)
struct LayoutConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(spacing: adaptiveSectionSpacing()) {
            Toggle("Wrap Lines", isOn: Binding(
                get: { appState.coordinator.configuration.layout.wrapLines },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.layout.wrapLines = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Insert Spaces for Tabs", isOn: Binding(
                get: { appState.coordinator.configuration.layout.insertSpacesForTabs },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.layout.insertSpacesForTabs = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
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
                            appState.coordinator.update { config in
                                config.layout.tabWidth = Int(newValue)
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
                            appState.coordinator.update { config in
                                config.layout.lineSpacing = newValue
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
                            appState.coordinator.update { config in
                                config.layout.gutterWidth = newValue
                            }
                        }
                    ),
                    in: 30...100,
                    step: 5
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
    
    private func configurationToggleStyle() -> some ToggleStyle {
        #if os(iOS)
        return SwitchToggleStyle(tint: .blue)
        #elseif targetEnvironment(macCatalyst)
        return SwitchToggleStyle(tint: .blue)
        #else
        // Use default toggle style for macOS (modern switch)
        return DefaultToggleStyle()
        #endif
    }
}
