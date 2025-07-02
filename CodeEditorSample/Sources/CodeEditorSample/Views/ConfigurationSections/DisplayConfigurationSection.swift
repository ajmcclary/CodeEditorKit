import CodeEditorPlugin
import SwiftUI

/// Display configuration section for the unified configuration view.
@available(macOS 13.0, iOS 16.0, *)
struct DisplayConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(spacing: adaptiveSectionSpacing()) {
            Toggle("Show Line Numbers", isOn: Binding(
                get: { appState.coordinator.configuration.display.showLineNumbers },
                set: { appState.coordinator.configuration.display.showLineNumbers = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Highlight Current Line", isOn: Binding(
                get: { appState.coordinator.configuration.display.highlightSelectedLine },
                set: { appState.coordinator.configuration.display.highlightSelectedLine = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Show Invisible Characters", isOn: Binding(
                get: { appState.coordinator.configuration.display.showInvisibleCharacters },
                set: { appState.coordinator.configuration.display.showInvisibleCharacters = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Enable Syntax Highlighting", isOn: Binding(
                get: { appState.coordinator.configuration.display.enableSyntaxHighlighting },
                set: { appState.coordinator.configuration.display.enableSyntaxHighlighting = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Enable Annotations", isOn: Binding(
                get: { appState.coordinator.configuration.display.enableAnnotations },
                set: { appState.coordinator.configuration.display.enableAnnotations = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Show Minimap", isOn: Binding(
                get: { appState.coordinator.configuration.display.showMinimap },
                set: { appState.coordinator.configuration.display.showMinimap = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
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
                        set: { appState.coordinator.configuration.display.fontSize = $0 }
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
    
    private func configurationToggleStyle() -> some ToggleStyle {
        #if os(iOS)
        return SwitchToggleStyle(tint: .blue)
        #else
        return CheckboxToggleStyle()
        #endif
    }
}
