import CodeEditorPlugin
import SwiftUI

/// Theme configuration section for the unified configuration view.
/// Provides theme selection and preview functionality.
@available(macOS 13.0, iOS 16.0, *)
struct ThemeConfigurationSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedTheme: ColorTheme = .xcode
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: adaptiveSectionSpacing()) {
            // Theme Selection
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                Text("Color Theme")
                    .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                
                ForEach(ColorTheme.allCases, id: \.self) { theme in
                    ThemeRow(
                        theme: theme,
                        isSelected: selectedTheme == theme,
                        onSelect: {
                            selectedTheme = theme
                            applyTheme(theme)
                        }
                    )
                }
            }
            
            // Theme Preview
            VStack(alignment: .leading, spacing: adaptiveControlSpacing()) {
                Text("Preview")
                    .font(.system(size: adaptiveControlLabelFontSize(), weight: .medium))
                
                ThemePreview(theme: selectedTheme)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, adaptiveHorizontalPadding())
        .onAppear {
            // Initialize with current theme if available
            selectedTheme = .xcode // Default theme
        }
    }
    
    // MARK: - Helper Methods
    
    private func applyTheme(_ theme: ColorTheme) {
        // Apply theme colors to the editor configuration
        appState.updateConfiguration { _ in
            // Update background and text colors based on theme
            // Note: This is a simplified implementation
            // In a full implementation, you'd integrate this with the theme system
        }
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
        case .xSmall: return 12
        case .small: return 13
        case .medium: return 14
        case .large: return 16
        case .xLarge: return 18
        case .xxLarge: return 20
        case .xxxLarge: return 22
        default: return 14
        }
    }
}

// MARK: - Theme Row Component

@available(macOS 13.0, iOS 16.0, *)
private struct ThemeRow: View {
    let theme: ColorTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Theme color preview
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(theme.backgroundColor))
                        .frame(width: 16, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                        )
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(theme.keywordColor))
                        .frame(width: 16, height: 16)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(theme.stringColor))
                        .frame(width: 16, height: 16)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(theme.commentColor))
                        .frame(width: 16, height: 16)
                }
                
                Text(theme.displayName)
                    .font(.system(size: adaptiveThemeNameFontSize()))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: adaptiveCheckmarkSize()))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
    
    private func adaptiveThemeNameFontSize() -> CGFloat {
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
    
    private func adaptiveCheckmarkSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 16
        case .medium, .large: return 18
        case .xLarge, .xxLarge: return 20
        case .xxxLarge: return 22
        default: return 18
        }
    }
}

// MARK: - Theme Preview Component

@available(macOS 13.0, iOS 16.0, *)
private struct ThemePreview: View {
    let theme: ColorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Simulated code preview
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("func")
                        .foregroundColor(Color(theme.keywordColor))
                    Text("hello()")
                        .foregroundColor(Color(theme.functionColor))
                    Text("{")
                        .foregroundColor(Color(theme.textColor))
                }
                
                HStack(spacing: 4) {
                    Text("    let")
                        .foregroundColor(Color(theme.keywordColor))
                    Text("message")
                        .foregroundColor(Color(theme.textColor))
                    Text("=")
                        .foregroundColor(Color(theme.textColor))
                    Text("\"Hello, World!\"")
                        .foregroundColor(Color(theme.stringColor))
                }
                
                HStack(spacing: 4) {
                    Text("    // This is a comment")
                        .foregroundColor(Color(theme.commentColor))
                        .italic()
                }
                
                HStack(spacing: 4) {
                    Text("    print(message)")
                        .foregroundColor(Color(theme.textColor))
                }
                
                HStack(spacing: 4) {
                    Text("}")
                        .foregroundColor(Color(theme.textColor))
                }
            }
            .font(.system(.caption, design: .monospaced))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(theme.backgroundColor))
    }
}
