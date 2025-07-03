import CodeEditorPlugin
import SwiftUI

/// Performance configuration section for the unified configuration view.
@available(macOS 13.0, iOS 16.0, *)
struct PerformanceConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: adaptiveSectionSpacing()) {
            Toggle("Hardware Acceleration", isOn: Binding(
                get: { appState.coordinator.configuration.performance.useHardwareAcceleration },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.performance.useHardwareAcceleration = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            Toggle("Smooth Scrolling", isOn: Binding(
                get: { appState.coordinator.configuration.performance.smoothScrolling },
                set: { newValue in
                    appState.coordinator.update { config in
                        config.performance.smoothScrolling = newValue
                    }
                }
            ))
            .toggleStyle(configurationToggleStyle())
            
            // Note: Background processing setting not available in current configuration
            
            // File Size Limit
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Max File Size")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text(formatFileSize(appState.coordinator.configuration.performance.maxSyntaxHighlightingLength))
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(appState.coordinator.configuration.performance.maxSyntaxHighlightingLength) },
                        set: { newValue in
                            appState.coordinator.update { config in
                                config.performance.maxSyntaxHighlightingLength = Int(newValue)
                            }
                        }
                    ),
                    in: 100_000...5_000_000,
                    step: 100_000
                )
                .accentColor(.blue)
            }
            
            // Max Syntax Highlighting Length
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                HStack {
                    Text("Syntax Highlight Limit")
                        .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                    Spacer()
                    Text(formatNumber(
                        appState.coordinator.configuration.performance.maxSyntaxHighlightingLength
                    ) + " chars")
                        .font(.system(size: adaptiveControlValueFontSize()))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(appState.coordinator.configuration.performance.maxSyntaxHighlightingLength) },
                        set: { newValue in
                            appState.coordinator.update { config in
                                config.performance.maxSyntaxHighlightingLength = Int(newValue)
                            }
                        }
                    ),
                    in: 10_000...1_000_000,
                    step: 10_000
                )
                .accentColor(.blue)
            }
        }
        .padding(.horizontal, adaptiveHorizontalPadding())
    }
    
    // MARK: - Helper Methods
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
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
