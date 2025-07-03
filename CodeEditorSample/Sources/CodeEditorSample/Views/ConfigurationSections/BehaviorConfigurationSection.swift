import CodeEditorPlugin
import SwiftUI

/// Behavior configuration section for the unified configuration view.
@available(macOS 13.0, iOS 16.0, *)
struct BehaviorConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: adaptiveSectionSpacing()) {
            Toggle("Enable Editing", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isEditable },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isEditable = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Auto Indent", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoIndent },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.autoIndent = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Enable Code Completion", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.enableCodeCompletion },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.enableCodeCompletion = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Spell Checking", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isContinuousSpellCheckingEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isContinuousSpellCheckingEnabled = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Smart Quotes", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isAutomaticQuoteSubstitutionEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isAutomaticQuoteSubstitutionEnabled = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Auto Close Brackets", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoCloseBrackets },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.autoCloseBrackets = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
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
    
    private func adaptiveHorizontalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 12
        case .medium, .large: return 16
        case .xLarge, .xxLarge: return 20
        case .xxxLarge: return 24
        default: return 16
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
