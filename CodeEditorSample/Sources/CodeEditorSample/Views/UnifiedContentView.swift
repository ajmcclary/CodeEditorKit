import CodeEditorPlugin
import SwiftUI

// MARK: - UnifiedContentView

/// The main content view for the CodeEditor Sample application.
///
/// `UnifiedContentView` provides a cross-platform interface that adapts to
/// different device types and screen sizes while maintaining a consistent
/// user experience across macOS, iOS, and Mac Catalyst.
///
/// ## Platform Adaptations
///
/// The view automatically adapts its layout based on the platform:
/// - **iPhone**: Single-stack navigation with toolbar access to configuration
/// - **iPad**: Split-view layout with sidebar configuration panel
/// - **macOS**: Split-view layout optimized for desktop interaction
/// - **Mac Catalyst**: Desktop-style split view with touch support
///
/// ## Features
///
/// - Responsive design that adapts to Dynamic Type settings
/// - Configurable sidebar visibility and width
/// - Integrated code editor with live configuration
/// - Cross-platform navigation patterns
/// - Accessibility support throughout
///
/// ## Architecture
///
/// The view uses SwiftUI's `NavigationSplitView` for larger screens and
/// `NavigationStack` for iPhone to provide platform-appropriate navigation.
/// State management is handled through the ``AppState`` observable object.
///
/// ## Example Usage
///
/// ```swift
/// var body: some Scene {
///     WindowGroup {
///         UnifiedContentView()
///             .frame(minWidth: 1200, minHeight: 800) // macOS
///     }
/// }
/// ```
///
/// - Requires: iOS 16.0+, macOS 13.0+
///
/// - SeeAlso: ``AppState`` for state management
/// - SeeAlso: ``UnifiedConfigurationView`` for the configuration panel
/// - SeeAlso: ``SampleCodeEditorView`` for the editor component
@available(macOS 13.0, iOS 16.0, *)
struct UnifiedContentView: View {
    @StateObject private var appState = AppState()
    @State private var showConfiguration = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    // Dynamic Type support
    @Environment(\.sizeCategory) private var sizeCategory
    
    var body: some View {
        Group {
            #if canImport(UIKit) && !targetEnvironment(macCatalyst)
            if !isIPad() {
                iPhoneLayout
            } else {
                iPadLayout
            }
            #else
            desktopLayout
            #endif
        }
    }
    
    // MARK: - Platform-Specific Layouts
    
    @ViewBuilder
    private var iPhoneLayout: some View {
        NavigationStack {
            editorView
                .environmentObject(appState)
                .navigationTitle("CodeEditor")
                #if canImport(UIKit)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: {
                        #if canImport(UIKit)
                        return .navigationBarLeading
                        #else
                        return .automatic
                        #endif
                    }()) {
                        NavigationLink(destination: UnifiedConfigurationView().environmentObject(appState)) {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var iPadLayout: some View {
        navigationSplitView
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationSplitViewStyle(.automatic)
    }
    
    @ViewBuilder
    private var desktopLayout: some View {
        navigationSplitView
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            .navigationSplitViewStyle(.prominentDetail)
            #endif
    }
    
    @ViewBuilder
    private var navigationSplitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with configuration
            UnifiedConfigurationView()
                .environmentObject(appState)
                .navigationSplitViewColumnWidth(
                    min: adaptiveColumnWidth().min,
                    ideal: adaptiveColumnWidth().ideal,
                    max: adaptiveColumnWidth().max
                )
                .frame(minWidth: adaptiveSidebarMinWidth())
        } detail: {
            // Main editor view
            editorView
                .environmentObject(appState)
        }
        .navigationTitle("CodeEditor Configuration Demo")
    }
    
    // MARK: - Adaptive Layout Helpers
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private struct ColumnWidth {
        let min: CGFloat
        let ideal: CGFloat
        let max: CGFloat
    }
    
    private func adaptiveColumnWidth() -> ColumnWidth {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        if isIPad() {
            // iPad gets much more generous spacing to utilize screen
            return ColumnWidth(min: 450, ideal: 500, max: 600)
        } else {
            // iPhone gets compact spacing
            return ColumnWidth(min: 300, ideal: 350, max: 400)
        }
        #else
        // macOS/Catalyst default
        return ColumnWidth(min: 300, ideal: 350, max: 400)
        #endif
    }
    
    private func adaptiveSidebarMinWidth() -> CGFloat {
        #if targetEnvironment(macCatalyst)
        return 350
        #elseif canImport(UIKit)
        return horizontalSizeClass == .regular ? 375 : 300
        #else
        return 300
        #endif
    }
    
    private func isIPad() -> Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    private func adaptiveToolbarHorizontalPadding() -> CGFloat {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        if isIPad() {
            return 16  // Less horizontal padding on iPad toolbar
        } else {
            return 12  // Tighter padding for iPhone
        }
        #else
        return 16  // Default
        #endif
    }
    
    private func dynamicImageScale() -> Image.Scale {
        #if canImport(UIKit)
        switch sizeCategory {
        case .extraSmall, .small:
            return .small
        case .medium, .large, .extraLarge:
            return .medium
        default:
            return .large
        }
        #else
        return .medium
        #endif
    }
    
    // MARK: - Editor View
    
    @ViewBuilder
    private var editorView: some View {
        VStack(spacing: 0) {
            // Editor toolbar
            editorToolbar
            
            Divider()
            
            // Main editor with live preview
            SampleCodeEditorView(
                text: $appState.code,
                language: appState.selectedLanguage?.fileExtensions.first ?? appState.selectedSample.fileExtension
            )
            .environmentObject(appState)
            
            Divider()
            
            // Status bar
            statusBar
        }
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
    
    // MARK: - Editor Toolbar
    
    @ViewBuilder
    private var editorToolbar: some View {
        HStack {
            // Configuration visibility toggle
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            PlatformSafeButton(action: toggleSidebar) {
                Image(systemName: "sidebar.left")
                    .help("Toggle Configuration Sidebar")
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 20)
            #endif
            
            // Current configuration preset
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.secondary)
                    .imageScale(dynamicImageScale())
                Text(appState.selectedPreset.displayName)
                    .font(isIPad() ? .caption : .caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
            
            // Quick toggles for frequently used options
            HStack(spacing: {
                #if targetEnvironment(macCatalyst)
                return 6
                #elseif canImport(UIKit)
                return isIPad() ? 8 : 4
                #else
                return 12
                #endif
            }()) {
                quickToggleButtons
            }
            
            Spacer()
            
            // Advanced Features Demo button
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            NavigationLink(destination: AdvancedFeaturesShowcaseView().environmentObject(appState)) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.2.fill")
                    Text("Advanced Demo")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            #endif
            
            // Platform-specific actions
            Menu {
                Button(action: copyConfiguration) {
                    Label("Copy Configuration", systemImage: "doc.on.doc")
                }
                
                Button(action: shareConfiguration) {
                    Label("Share Configuration", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Button(action: refreshEditor) {
                    Label("Refresh Editor", systemImage: "arrow.clockwise")
                }
                
                #if canImport(UIKit)
                Divider()
                
                NavigationLink(destination: AdvancedFeaturesShowcaseView().environmentObject(appState)) {
                    Label("Advanced Demo", systemImage: "gearshape.2.fill")
                }
                #endif
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(dynamicImageScale())
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, adaptiveToolbarHorizontalPadding())
        #if targetEnvironment(macCatalyst)
        .padding(.vertical, 2)
        .frame(height: 32)
        #elseif canImport(UIKit)
        .padding(.vertical, isIPad() ? 4 : 4)
        .frame(height: isIPad() ? 44 : 36)
        #else
        .padding(.vertical, 8)
        #endif
        .background(Color(PlatformColors.controlBackground))
    }
    
    // MARK: - Status Bar
    
    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 16) {
            // Language indicator
            HStack(spacing: 4) {
                Image(systemName: appState.selectedSample.icon)
                    .foregroundColor(appState.selectedSample.iconColor)
                Text(appState.selectedSample.displayName)
            }
            .font(isIPad() ? .caption : .caption2)
            
            Divider()
                .frame(height: isIPad() ? 16 : 12)
            
            // Line count
            HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                Text("\(appState.code.components(separatedBy: .newlines).count) lines")
            }
            .font(isIPad() ? .caption : .caption2)
            .foregroundColor(.secondary)
            
            Divider()
                .frame(height: isIPad() ? 16 : 12)
            
            // Character count
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                Text("\(appState.code.count) characters")
            }
            .font(isIPad() ? .caption : .caption2)
            .foregroundColor(.secondary)
            
            Spacer()
            
            // Active features indicator
            HStack(spacing: 8) {
                if appState.coordinator.configuration.display.enableSyntaxHighlighting {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(.green)
                        .help("Syntax Highlighting Active")
                }
                
                if appState.coordinator.configuration.display.enableAnnotations {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.orange)
                        .help("Annotations Active")
                }
                
                if appState.coordinator.configuration.behavior.enableCodeCompletion {
                    Image(systemName: "text.insert")
                        .foregroundColor(.blue)
                        .help("Code Completion Active")
                }
                
                if appState.coordinator.configuration.display.showMinimap {
                    Image(systemName: "map.fill")
                        .foregroundColor(.purple)
                        .help("Minimap Active")
                }
            }
            .font(isIPad() ? .caption : .caption2)
        }
        .padding(.horizontal, adaptiveToolbarHorizontalPadding())
        #if targetEnvironment(macCatalyst)
        .padding(.vertical, 3)
        #elseif canImport(UIKit)
        .padding(.vertical, isIPad() ? 3 : 2)
        .frame(height: isIPad() ? 32 : 24)
        #else
        .padding(.vertical, 6)
        #endif
        .background(Color(PlatformColors.controlBackground))
    }
    
    // MARK: - Helper Methods
    
    private func toggleSidebar() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        #endif
    }
    
    private func copyConfiguration() {
        if let jsonData = try? JSONEncoder().encode(appState.coordinator.configuration),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)
            #else
            UIPasteboard.general.string = jsonString
            #endif
        }
    }
    
    private func shareConfiguration() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        exportConfiguration()
        #else
        // iOS share sheet implementation
        if let jsonData = try? JSONEncoder().encode(appState.currentConfiguration) {
            let activityVC = UIActivityViewController(activityItems: [jsonData], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
        #endif
    }
    
    private func exportConfiguration() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let window = NSApp.keyWindow {
            ConfigurationExporter.exportConfiguration(appState.coordinator.configuration, from: window)
        }
        #else
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            ConfigurationExporter.exportConfiguration(appState.coordinator.configuration, from: rootVC)
        }
        #endif
    }
    
    private func refreshEditor() {
        // Force editor refresh by toggling a benign setting
        let current = appState.coordinator.configuration.display.enableSyntaxHighlighting
        appState.coordinator.update { config in
            config.display.enableSyntaxHighlighting = !current
        }
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            appState.coordinator.update { config in
                config.display.enableSyntaxHighlighting = current
            }
        }
    }
    
    // MARK: - Quick Toggle Buttons
    
    @ViewBuilder
    private var quickToggleButtons: some View {
        PlatformSafeButton(
            action: {
                appState.coordinator.update { config in
                    config.display.isLineNumbersEnabled.toggle()
                }
            },
            label: {
                Image(systemName: "number")
                    .imageScale(dynamicImageScale())
                    .foregroundColor(
                        appState.coordinator.configuration.display.isLineNumbersEnabled
                            ? .accentColor : .secondary
                    )
                    .help("Toggle Line Numbers")
            }
        )
        
        // Show additional toggles on platforms that support them
        if shouldShowExtendedToggles() {
            minimapToggleButton
            invisibleCharactersToggleButton
        }
        
        PlatformSafeButton(
            action: {
                appState.coordinator.update { config in
                    config.behavior.isEditable.toggle()
                }
            },
            label: {
                let isEditable = appState.coordinator.configuration.behavior.isEditable
                Image(systemName: isEditable ? "pencil" : "pencil.slash")
                    .imageScale(dynamicImageScale())
                    .foregroundColor(isEditable ? .accentColor : .secondary)
                    .help("Toggle Editing")
            }
        )
    }
    
    // MARK: - Toggle Button Helpers
    
    private func shouldShowExtendedToggles() -> Bool {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        return isIPad()
        #else
        return true
        #endif
    }
    
    @ViewBuilder
    private var minimapToggleButton: some View {
        PlatformSafeButton(
            action: {
                appState.coordinator.update { config in
                    config.display.showMinimap.toggle()
                }
            },
            label: {
                Image(systemName: "map")
                    .imageScale(dynamicImageScale())
                    .foregroundColor(
                        appState.coordinator.configuration.display.showMinimap
                            ? .accentColor : .secondary
                    )
                    .help("Toggle Minimap")
            }
        )
    }
    
    @ViewBuilder
    private var invisibleCharactersToggleButton: some View {
        PlatformSafeButton(
            action: {
                appState.coordinator.update { config in
                    config.display.showInvisibleCharacters.toggle()
                }
            },
            label: {
                Image(systemName: "paragraph")
                    .imageScale(dynamicImageScale())
                    .foregroundColor(
                        appState.coordinator.configuration.display.showInvisibleCharacters
                            ? .accentColor : .secondary
                    )
                    .help("Toggle Invisible Characters")
            }
        )
    }
}

// MARK: - Preview

@available(macOS 13.0, iOS 16.0, *)
struct UnifiedContentView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedContentView()
    }
}
