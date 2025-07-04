import CodeEditorPlugin
import SwiftUI

// MARK: - ConfigurationSection

/// A collapsible section container for configuration options.
@available(macOS 13.0, iOS 16.0, *)
struct ConfigurationSection<Content: View>: View {
    let title: String
    let systemImage: String
    let isExpanded: Bool
    let content: Content
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init(title: String, systemImage: String, isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.isExpanded = isExpanded
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: sectionHeaderSpacing()) {
                Image(systemName: systemImage)
                    .font(.system(size: sectionIconSize(), weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: sectionIconFrameSize(), height: sectionIconFrameSize())
                
                Text(title)
                    .font(.system(size: sectionTitleFontSize(), weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: sectionChevronSize(), weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, sectionHeaderHorizontalPadding())
            .padding(.vertical, sectionHeaderVerticalPadding())
            .background(sectionHeaderBackground())
            .clipShape(RoundedRectangle(cornerRadius: sectionHeaderCornerRadius()))
            
            // Section content
            if isExpanded {
                VStack(spacing: sectionContentSpacing()) {
                    content
                }
                .padding(.top, sectionContentTopPadding())
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
            }
        }
        .background(sectionBackground())
        .clipShape(RoundedRectangle(cornerRadius: sectionCornerRadius()))
        .shadow(color: sectionShadowColor(), radius: sectionShadowRadius(), x: 0, y: sectionShadowY())
    }
    
    // MARK: - Section Adaptive Helpers
    
    private func sectionHeaderSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    private func sectionIconSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 14
        case .small: return 15
        case .medium: return 16
        case .large: return 17
        case .xLarge: return 19
        case .xxLarge: return 21
        case .xxxLarge: return 23
        default: return 16
        }
    }
    
    private func sectionIconFrameSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 20
        case .small: return 22
        case .medium: return 24
        case .large: return 26
        case .xLarge: return 30
        case .xxLarge: return 34
        case .xxxLarge: return 38
        default: return 24
        }
    }
    
    private func sectionTitleFontSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 15
        case .small: return 16
        case .medium: return 17
        case .large: return 18
        case .xLarge: return 20
        case .xxLarge: return 22
        case .xxxLarge: return 24
        default: return 17
        }
    }
    
    private func sectionChevronSize() -> CGFloat {
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
    
    private func sectionHeaderHorizontalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 12
        case .medium, .large: return 16
        case .xLarge, .xxLarge: return 20
        case .xxxLarge: return 24
        default: return 16
        }
    }
    
    private func sectionHeaderVerticalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 10
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 14
        case .xxxLarge: return 16
        default: return 12
        }
    }
    
    private func sectionContentSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    private func sectionContentTopPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    private func sectionHeaderCornerRadius() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 10
        case .xLarge, .xxLarge: return 12
        case .xxxLarge: return 14
        default: return 10
        }
    }
    
    private func sectionCornerRadius() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 10
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 14
        case .xxxLarge: return 16
        default: return 12
        }
    }
    
    private func sectionShadowRadius() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 2
        case .medium, .large: return 3
        case .xLarge, .xxLarge: return 4
        case .xxxLarge: return 5
        default: return 3
        }
    }
    
    private func sectionShadowY() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 1
        case .medium, .large: return 2
        case .xLarge, .xxLarge: return 3
        case .xxxLarge: return 4
        default: return 2
        }
    }
    
    @ViewBuilder
    private func sectionHeaderBackground() -> some View {
        #if canImport(UIKit)
        Color(.systemGray6)
        #else
        Color(.controlBackgroundColor)
        #endif
    }
    
    @ViewBuilder
    private func sectionBackground() -> some View {
        #if canImport(UIKit)
        Color(.systemBackground)
        #else
        Color(.windowBackgroundColor)
        #endif
    }
    
    private func sectionShadowColor() -> Color {
        #if canImport(UIKit)
        return Color.black.opacity(0.1)
        #else
        return Color.black.opacity(0.05)
        #endif
    }
}

// MARK: - PresetRow

/// A row for displaying and selecting configuration presets.
@available(macOS 13.0, iOS 16.0, *)
struct PresetRow: View {
    let preset: ConfigurationPreset
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: presetRowSpacing()) {
                VStack(alignment: .leading, spacing: presetRowTextSpacing()) {
                    Text(preset.displayName)
                        .font(.system(size: presetRowTitleFontSize(), weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(preset.description)
                        .font(.system(size: presetRowDescriptionFontSize()))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: presetRowCheckmarkSize(), weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, presetRowHorizontalPadding())
            .padding(.vertical, presetRowVerticalPadding())
            .background(presetRowBackground())
            .clipShape(RoundedRectangle(cornerRadius: presetRowCornerRadius()))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Preset Row Adaptive Helpers
    
    private func presetRowSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    private func presetRowTextSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 2
        case .medium, .large: return 4
        case .xLarge, .xxLarge: return 6
        case .xxxLarge: return 8
        default: return 4
        }
    }
    
    private func presetRowTitleFontSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 14
        case .small: return 15
        case .medium: return 16
        case .large: return 17
        case .xLarge: return 19
        case .xxLarge: return 21
        case .xxxLarge: return 23
        default: return 16
        }
    }
    
    private func presetRowDescriptionFontSize() -> CGFloat {
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
    
    private func presetRowCheckmarkSize() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 16
        case .small: return 17
        case .medium: return 18
        case .large: return 19
        case .xLarge: return 21
        case .xxLarge: return 23
        case .xxxLarge: return 25
        default: return 18
        }
    }
    
    private func presetRowHorizontalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 12
        case .medium, .large: return 16
        case .xLarge, .xxLarge: return 20
        case .xxxLarge: return 24
        default: return 16
        }
    }
    
    private func presetRowVerticalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    private func presetRowCornerRadius() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 6
        case .medium, .large: return 8
        case .xLarge, .xxLarge: return 10
        case .xxxLarge: return 12
        default: return 8
        }
    }
    
    @ViewBuilder
    private func presetRowBackground() -> some View {
        if isSelected {
            #if canImport(UIKit)
            Color.blue.opacity(0.1)
            #else
            Color.blue.opacity(0.1)
            #endif
        } else {
            #if canImport(UIKit)
            Color(.systemGray6)
            #else
            Color(.controlBackgroundColor)
            #endif
        }
    }
}
