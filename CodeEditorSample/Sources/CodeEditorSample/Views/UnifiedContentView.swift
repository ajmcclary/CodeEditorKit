import CodeEditorPlugin
import SwiftUI

// MARK: - UnifiedContentView

/// A unified content view that works consistently across macOS and iOS
@available(macOS 13.0, iOS 16.0, *)
struct UnifiedContentView: View {
    @StateObject private var appState = AppState()
    @State private var showConfiguration = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with configuration
            UnifiedConfigurationView()
                .environmentObject(appState)
                .navigationSplitViewColumnWidth(
                    min: 300,
                    ideal: 350,
                    max: 400
                )
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                .navigationSplitViewStyle(.prominentDetail)
                #endif
        } detail: {
            // Main editor view
            editorView
                .environmentObject(appState)
        }
        .navigationTitle("CodeEditor Configuration Demo")
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
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
                configuration: appState.coordinator.configuration,
                text: $appState.code,
                language: appState.selectedSample.fileExtension
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
                Text(appState.selectedPreset.displayName)
                    .font(.caption)
            }
            
            Spacer()
            
            // Quick toggles for frequently used options
            HStack(spacing: 12) {
                PlatformSafeButton(action: {
                    appState.coordinator.configuration.display.showLineNumbers.toggle()
                }) {
                    Image(systemName: "number")
                        .foregroundColor(appState.coordinator.configuration.display.showLineNumbers ? .accentColor : .secondary)
                        .help("Toggle Line Numbers")
                }
                
                PlatformSafeButton(action: {
                    appState.coordinator.configuration.display.showMinimap.toggle()
                }) {
                    Image(systemName: "map")
                        .foregroundColor(appState.coordinator.configuration.display.showMinimap ? .accentColor : .secondary)
                        .help("Toggle Minimap")
                }
                
                PlatformSafeButton(action: {
                    appState.coordinator.configuration.display.showInvisibleCharacters.toggle()
                }) {
                    Image(systemName: "paragraph")
                        .foregroundColor(appState.coordinator.configuration.display.showInvisibleCharacters ? .accentColor : .secondary)
                        .help("Toggle Invisible Characters")
                }
                
                PlatformSafeButton(action: {
                    appState.coordinator.configuration.behavior.isEditable.toggle()
                }) {
                    Image(systemName: appState.coordinator.configuration.behavior.isEditable ? "pencil" : "pencil.slash")
                        .foregroundColor(appState.coordinator.configuration.behavior.isEditable ? .accentColor : .secondary)
                        .help("Toggle Editing")
                }
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
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
            .font(.caption)
            
            Divider()
                .frame(height: 16)
            
            // Line count
            HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                Text("\(appState.code.components(separatedBy: .newlines).count) lines")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 16)
            
            // Character count
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                Text("\(appState.code.count) characters")
            }
            .font(.caption)
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
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
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
            #if canImport(AppKit)
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
        #if canImport(AppKit)
        if let window = NSApp.keyWindow {
            ConfigurationExporter.exportConfiguration(appState.coordinator.configuration, from: window)
        }
        #endif
    }
    
    private func refreshEditor() {
        // Force editor refresh by toggling a benign setting
        let current = appState.coordinator.configuration.display.enableSyntaxHighlighting
        appState.coordinator.configuration.display.enableSyntaxHighlighting = !current
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            appState.coordinator.configuration.display.enableSyntaxHighlighting = current
        }
    }
}

// MARK: - Preview

@available(macOS 13.0, iOS 16.0, *)
struct UnifiedContentView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedContentView()
    }
}
