import CodeEditorPlugin
import SwiftUI

// MARK: - UnifiedConfigurationView

/// A comprehensive configuration view that exposes ALL EditorConfiguration options
/// Works consistently across macOS and iOS platforms
@available(macOS 13.0, iOS 16.0, *)
struct UnifiedConfigurationView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = ["Display", "Editor Settings"]
    
    // Dynamic Type support
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        ScrollView {
            VStack(spacing: adaptiveMainSpacing()) {
                // Search bar for filtering options
                searchBar
                    .padding(.top, -adaptiveSearchTopPadding()) // Reduce top spacing
                
                // Configuration sections
                VStack(spacing: adaptiveSectionSpacing()) {
                    // Presets section
                    ConfigurationSection(
                        title: "Configuration Presets",
                        systemImage: "slider.horizontal.3",
                        isExpanded: expandedSections.contains("Presets")
                    ) {
                        presetsContent
                    }
                    .onTapGesture {
                        toggleSection("Presets")
                    }
                    
                    // Display section
                    ConfigurationSection(
                        title: "Display",
                        systemImage: "eye",
                        isExpanded: expandedSections.contains("Display")
                    ) {
                        DisplayConfigurationSection()
                    }
                    .onTapGesture {
                        toggleSection("Display")
                    }
                    
                    // Layout section
                    ConfigurationSection(
                        title: "Layout",
                        systemImage: "rectangle.grid.1x2",
                        isExpanded: expandedSections.contains("Layout")
                    ) {
                        LayoutConfigurationSection()
                    }
                    .onTapGesture {
                        toggleSection("Layout")
                    }
                    
                    // Behavior section
                    ConfigurationSection(
                        title: "Behavior",
                        systemImage: "gear",
                        isExpanded: expandedSections.contains("Behavior")
                    ) {
                        BehaviorConfigurationSection()
                    }
                    .onTapGesture {
                        toggleSection("Behavior")
                    }
                    
                    // Performance section
                    ConfigurationSection(
                        title: "Performance",
                        systemImage: "speedometer",
                        isExpanded: expandedSections.contains("Performance")
                    ) {
                        PerformanceConfigurationSection()
                    }
                    .onTapGesture {
                        toggleSection("Performance")
                    }
                    
                    // Import/Export section
                    ConfigurationSection(
                        title: "Import/Export",
                        systemImage: "square.and.arrow.up",
                        isExpanded: expandedSections.contains("ImportExport")
                    ) {
                        importExportButtons
                    }
                    .onTapGesture {
                        toggleSection("ImportExport")
                    }
                }
                .padding(.horizontal, adaptiveMainHorizontalPadding())
            }
            .padding(.bottom, adaptiveBottomPadding())
        }
        .background(adaptiveBackgroundColor())
    }
    
    // MARK: - Search Bar
    
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: adaptiveSearchSpacing()) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: adaptiveSearchIconSize()))
                .foregroundColor(.secondary)
            
            TextField("Search settings...", text: $searchText)
                .font(.system(size: adaptiveSearchTextSize()))
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, adaptiveSearchVerticalPadding())
        }
        .padding(.horizontal, adaptiveSearchHorizontalPadding())
        .background(adaptiveSearchBackground())
        .clipShape(RoundedRectangle(cornerRadius: adaptiveSearchCornerRadius()))
        .padding(.horizontal, adaptiveMainHorizontalPadding())
        .minimumScaleFactor(0.7)  // Allow text to scale down if needed
        .lineLimit(1)
    }
    
    // MARK: - Presets Content
    
    @ViewBuilder
    private var presetsContent: some View {
        VStack(spacing: 8) {
            ForEach(ConfigurationPreset.allCases, id: \.self) { preset in
                PresetRow(preset: preset, isSelected: appState.selectedPreset == preset) {
                    appState.applyPreset(preset)
                }
            }
        }
    }
    
    // MARK: - Import/Export Buttons
    
    @ViewBuilder
    private var importExportButtons: some View {
        VStack(spacing: adaptiveButtonSpacing()) {
            HStack(spacing: adaptiveButtonSpacing()) {
                Button("Export Settings") {
                    if let json = appState.exportConfigurationAsJSON() {
                        // In a real app, present save dialog or share sheet
                        print("Configuration exported: \(json)")
                    }
                }
                .buttonStyle(configurationButtonStyle())
                
                Button("Import Settings") {
                    // In a real app, present file picker or import dialog
                    // appState.importConfiguration(from: jsonString)
                }
                .buttonStyle(configurationButtonStyle())
            }
            
            Button("Reset to Defaults") {
                appState.resetConfiguration()
            }
            .buttonStyle(destructiveButtonStyle())
        }
        .padding(.horizontal, adaptiveHorizontalPadding())
    }
    
    // MARK: - Helper Methods
    
    private func toggleSection(_ section: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
    
    // MARK: - Adaptive Layout Helpers
    
    private func adaptiveMainSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 12
        case .medium, .large: return 16
        case .xLarge, .xxLarge: return 20
        case .xxxLarge: return 24
        default: return 16
        }
    }
    
    private func adaptiveSectionSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    private func adaptiveMainHorizontalPadding() -> CGFloat {
        switch horizontalSizeClass {
        case .compact:
            switch dynamicTypeSize {
            case .xSmall, .small: return 12
            case .medium, .large: return 16
            case .xLarge, .xxLarge: return 20
            case .xxxLarge: return 24
            default: return 16
            }
        case .regular:
            switch dynamicTypeSize {
            case .xSmall, .small: return 20
            case .medium, .large: return 24
            case .xLarge, .xxLarge: return 28
            case .xxxLarge: return 32
            default: return 24
            }
        default:
            return 16
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
    
    private func adaptiveBottomPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 16
        case .medium, .large: return 20
        case .xLarge, .xxLarge: return 24
        case .xxxLarge: return 28
        default: return 20
        }
    }
    
    private func adaptiveSearchTopPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 4
        case .medium, .large: return 6
        case .xLarge, .xxLarge: return 8
        case .xxxLarge: return 10
        default: return 6
        }
    }
    
    private func adaptiveSearchSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 10
        case .xLarge, .xxLarge: return 12
        case .xxxLarge: return 14
        default: return 10
        }
    }
    
    private func adaptiveSearchIconSize() -> CGFloat {
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
    
    private func adaptiveSearchTextSize() -> CGFloat {
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
    
    private func adaptiveSearchVerticalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 10
        case .xLarge, .xxLarge: return 12
        case .xxxLarge: return 14
        default: return 10
        }
    }
    
    private func adaptiveSearchHorizontalPadding() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 12
        case .medium, .large: return 16
        case .xLarge, .xxLarge: return 20
        case .xxxLarge: return 24
        default: return 16
        }
    }
    
    private func adaptiveSearchCornerRadius() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 10
        case .xLarge, .xxLarge: return 12
        case .xxxLarge: return 14
        default: return 10
        }
    }
    
    private func adaptiveButtonSpacing() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        case .xxxLarge: return 20
        default: return 12
        }
    }
    
    @ViewBuilder
    private func adaptiveBackgroundColor() -> some View {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(.windowBackgroundColor)
        #endif
    }
    
    @ViewBuilder
    private func adaptiveSearchBackground() -> some View {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(.textBackgroundColor)
        #endif
    }
    
    private func configurationButtonStyle() -> some ButtonStyle {
        return ConfigurationButtonStyle()
    }
    
    private func destructiveButtonStyle() -> some ButtonStyle {
        return DestructiveButtonStyle()
    }
}

// MARK: - Button Styles

@available(macOS 13.0, iOS 16.0, *)
struct ConfigurationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

@available(macOS 13.0, iOS 16.0, *)
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

@available(macOS 13.0, iOS 16.0, *)
struct UnifiedConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UnifiedConfigurationView()
                .navigationTitle("Configuration")
        }
        .environmentObject(AppState())
    }
}
