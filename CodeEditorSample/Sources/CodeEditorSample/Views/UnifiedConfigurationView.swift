import CodeEditorPlugin
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - UnifiedConfigurationView

/// A comprehensive configuration view that exposes ALL EditorConfiguration options
/// Works consistently across macOS and iOS platforms
@available(macOS 13.0, iOS 16.0, *)
struct UnifiedConfigurationView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = ["Display", "Editor Settings"]
    
    // MARK: - Search Data Structure
    
    private struct SearchableSection {
        let id: String
        let title: String
        let keywords: [String]
        let content: () -> AnyView
    }
    
    private var searchableSections: [SearchableSection] {
        [
            SearchableSection(
                id: "Presets",
                title: "Configuration Presets",
                keywords: [
                    "preset", "configuration", "template", "default", "minimal", "read-only", "markdown", "presentation"
                ],
                content: { AnyView(presetsContent) }
            ),
            SearchableSection(
                id: "Display",
                title: "Display",
                keywords: [
                    "display", "line numbers", "syntax highlighting", "font", "appearance", "visual", 
                    "gutter", "minimap"
                ],
                content: { AnyView(DisplayConfigurationSection()) }
            ),
            SearchableSection(
                id: "Layout",
                title: "Layout",
                keywords: [
                    "layout", "tab width", "line spacing", "wrap", "indent", "spacing", "margin", "width", "height"
                ],
                content: { AnyView(LayoutConfigurationSection()) }
            ),
            SearchableSection(
                id: "Behavior",
                title: "Behavior",
                keywords: [
                    "behavior", "editing", "auto indent", "completion", "spell check", "grammar", "quotes", 
                    "brackets", "selectable", "scroll", "cursor"
                ],
                content: { AnyView(BehaviorConfigurationSection()) }
            ),
            SearchableSection(
                id: "Performance",
                title: "Performance",
                keywords: [
                    "performance", "speed", "optimization", "hardware", "acceleration", "smooth", "scrolling", "memory"
                ],
                content: { AnyView(PerformanceConfigurationSection()) }
            ),
            SearchableSection(
                id: "ImportExport",
                title: "Import/Export",
                keywords: [
                    "import", "export", "settings", "save", "load", "share", "backup", "restore", "reset"
                ],
                content: { AnyView(importExportButtons) }
            )
        ]
    }
    
    private var filteredSections: [SearchableSection] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return searchableSections
        }
        
        let searchTerms = searchText.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        return searchableSections.filter { section in
            let searchableText = ([section.title.lowercased()] + section.keywords).joined(separator: " ")
            return searchTerms.allSatisfy { term in
                searchableText.contains(term)
            }
        }
    }
    
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
                
                // Configuration sections with search filtering
                VStack(spacing: adaptiveSectionSpacing()) {
                    if filteredSections.isEmpty {
                        // No search results
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No settings found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Try adjusting your search terms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 32)
                    } else {
                        ForEach(filteredSections, id: \.id) { section in
                            ConfigurationSection(
                                title: section.title,
                                systemImage: systemImageForSection(section.id),
                                isExpanded: isSearching ? true : expandedSections.contains(section.id)
                            ) {
                                section.content()
                            }
                            .onTapGesture {
                                if !isSearching {
                                    toggleSection(section.id)
                                }
                            }
                        }
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
            // Export/Import row
            HStack(spacing: adaptiveButtonSpacing()) {
                Button("Export Settings") {
                    exportConfiguration()
                }
                .buttonStyle(configurationButtonStyle())
                .help("Export current configuration as JSON file")
                
                Button("Import Settings") {
                    importConfiguration()
                }
                .buttonStyle(configurationButtonStyle())
                .help("Import configuration from JSON file")
            }
            
            // Share Configuration row
            HStack(spacing: adaptiveButtonSpacing()) {
                Button("Share Configuration") {
                    shareConfiguration()
                }
                .buttonStyle(configurationButtonStyle())
                .help("Share current configuration via system share sheet")
                
                Button("Copy as JSON") {
                    copyConfigurationToClipboard()
                }
                .buttonStyle(configurationButtonStyle())
                .help("Copy configuration JSON to clipboard")
            }
            
            // Reset row
            Button("Reset to Defaults") {
                resetToDefaults()
            }
            .buttonStyle(destructiveButtonStyle())
            .help("Reset all settings to default values")
        }
        .padding(.horizontal, adaptiveHorizontalPadding())
    }
    
    // MARK: - Helper Methods
    
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func systemImageForSection(_ sectionId: String) -> String {
        switch sectionId {
        case "Presets": return "slider.horizontal.3"
        case "Display": return "eye"
        case "Layout": return "rectangle.grid.1x2"
        case "Behavior": return "gear"
        case "Performance": return "speedometer"
        case "ImportExport": return "square.and.arrow.up"
        default: return "gear"
        }
    }
    
    private func toggleSection(_ section: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
    
    // MARK: - Import/Export Actions
    
    private func exportConfiguration() {
        guard let json = appState.exportConfigurationAsJSON() else {
            showAlert(title: "Export Failed", message: "Unable to export configuration.")
            return
        }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: Use save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Configuration"
        savePanel.nameFieldStringValue = "editor-config.json"
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            
            do {
                try json.write(to: url, atomically: true, encoding: .utf8)
                showAlert(
            title: "Export Successful", 
            message: "Configuration exported to \(url.lastPathComponent)"
        )
            } catch {
                showAlert(
            title: "Export Failed", 
            message: "Error writing file: \(error.localizedDescription)"
        )
            }
        }
        #else
        // iOS: Use document picker or share sheet
        // For now, copy to clipboard as fallback
        copyConfigurationToClipboard()
        showAlert(
            title: "Configuration Copied", 
            message: "Configuration copied to clipboard. Use Share Configuration for more options."
        )
        #endif
    }
    
    private func importConfiguration() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: Use open panel
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Configuration"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else { return }
            
            do {
                let jsonString = try String(contentsOf: url, encoding: .utf8)
                if appState.importConfiguration(from: jsonString) {
                    showAlert(
                    title: "Import Successful", 
                    message: "Configuration imported from \(url.lastPathComponent)"
                )
                } else {
                    showAlert(title: "Import Failed", message: "Invalid configuration format.")
                }
            } catch {
                showAlert(
                    title: "Import Failed", 
                    message: "Error reading file: \(error.localizedDescription)"
                )
            }
        }
        #else
        // iOS: For now, show instructions to paste JSON
        showAlert(
            title: "Import Configuration", 
            message: "Please paste the configuration JSON in the text field that appears next."
        )
        // In a full implementation, this would show a text input dialog or document picker
        #endif
    }
    
    private func shareConfiguration() {
        guard let json = appState.exportConfigurationAsJSON() else {
            showAlert(title: "Share Failed", message: "Unable to export configuration.")
            return
        }
        
        #if canImport(UIKit)
        // iOS: Use share sheet
        let items = [json]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Present share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = window
            rootVC.present(activityVC, animated: true)
        }
        #else
        // macOS: Copy to clipboard
        copyConfigurationToClipboard()
        showAlert(title: "Configuration Copied", message: "Configuration copied to clipboard for sharing.")
        #endif
    }
    
    private func copyConfigurationToClipboard() {
        guard let json = appState.exportConfigurationAsJSON() else {
            showAlert(title: "Copy Failed", message: "Unable to export configuration.")
            return
        }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        #else
        // Use secure pasteboard access on iOS 16+
        if #available(iOS 16.0, *) {
            UIPasteboard.general.items = [[UIPasteboard.typeAutomatic: json]]
        } else {
            UIPasteboard.general.string = json
        }
        #endif
        
        showAlert(title: "Copied to Clipboard", message: "Configuration JSON copied to clipboard.")
    }
    
    private func resetToDefaults() {
        // Show confirmation before resetting
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults"
        alert.informativeText = 
            "This will reset all configuration settings to their default values. This action cannot be undone."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            appState.resetConfiguration()
            showAlert(title: "Reset Complete", message: "All settings have been reset to default values.")
        }
        #else
        // iOS: Would use UIAlertController in a real implementation
        appState.resetConfiguration()
        showAlert(title: "Reset Complete", message: "All settings have been reset to default values.")
        #endif
    }
    
    private func showAlert(title: String, message: String) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        #else
        // iOS: In a real implementation, this would use UIAlertController
        CrossPlatformLogger.logger().info("\(title): \(message)")
        #endif
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
        #if canImport(UIKit)
        Color(.systemGroupedBackground)
        #else
        Color(.windowBackgroundColor)
        #endif
    }
    
    @ViewBuilder
    private func adaptiveSearchBackground() -> some View {
        #if canImport(UIKit)
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
