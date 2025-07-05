import CodeEditorPlugin
import SwiftUI

// TODO: Update remaining configuration bindings to use appState.updateConfiguration() helper method
// This reduces code duplication and ensures consistent objectWillChange.send() calls

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
                    appState.updateConfiguration { config in
                        config.behavior.isEditable = newValue
                    }
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Auto Indent", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoIndent },
                set: { newValue in
                    appState.updateConfiguration { config in
                        config.behavior.autoIndent = newValue
                    }
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Enable Code Completion", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.enableCodeCompletion },
                set: { newValue in
                    appState.updateConfiguration { config in
                        config.behavior.enableCodeCompletion = newValue
                    }
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Spell Checking", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isContinuousSpellCheckingEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isContinuousSpellCheckingEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Smart Quotes", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isAutomaticQuoteSubstitutionEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isAutomaticQuoteSubstitutionEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Auto Close Brackets", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoCloseBrackets },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.autoCloseBrackets = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Auto Close Quotes", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoCloseQuotes },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.autoCloseQuotes = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Is Selectable", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isSelectable },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isSelectable = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Grammar Checking", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isGrammarCheckingEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isGrammarCheckingEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Smart Dashes", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isAutomaticDashSubstitutionEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isAutomaticDashSubstitutionEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Text Replacement", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isAutomaticTextReplacementEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isAutomaticTextReplacementEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Spell Correction", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isAutomaticSpellingCorrectionEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isAutomaticSpellingCorrectionEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Text Completion", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isAutomaticTextCompletionEnabled },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.isAutomaticTextCompletionEnabled = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            
            Toggle("Auto Scroll to Cursor", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoScrollToCursor },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.behavior.autoScrollToCursor = newValue
                    }
                    appState.objectWillChange.send()
                }
            ))
            .toggleStyle(.platform)
            .help("When enabled, the editor automatically scrolls to make the cursor visible")
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
}
