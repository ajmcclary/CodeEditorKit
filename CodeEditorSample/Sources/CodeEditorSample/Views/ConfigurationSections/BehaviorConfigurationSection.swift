import CodeEditorPlugin
import SwiftUI

/// Behavior configuration section for the unified configuration view.
@available(macOS 13.0, iOS 16.0, *)
struct BehaviorConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(spacing: adaptiveSectionSpacing()) {
            Toggle("Enable Editing", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isEditable },
                set: { appState.coordinator.configuration.behavior.isEditable = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Auto Indent", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoIndent },
                set: { appState.coordinator.configuration.behavior.autoIndent = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Enable Code Completion", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.enableCodeCompletion },
                set: { appState.coordinator.configuration.behavior.enableCodeCompletion = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Spell Checking", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isContinuousSpellCheckingEnabled },
                set: { appState.coordinator.configuration.behavior.isContinuousSpellCheckingEnabled = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Smart Quotes", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.isAutomaticQuoteSubstitutionEnabled },
                set: { appState.coordinator.configuration.behavior.isAutomaticQuoteSubstitutionEnabled = $0 }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Auto Close Brackets", isOn: Binding(
                get: { appState.coordinator.configuration.behavior.autoCloseBrackets },
                set: { appState.coordinator.configuration.behavior.autoCloseBrackets = $0 }
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
        #else
        return CheckboxToggleStyle()
        #endif
    }
}
