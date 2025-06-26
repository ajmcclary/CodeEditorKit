import os.log
import SwiftUI

/// SwiftUI view for displaying detailed plugin information and configuration
@MainActor
public struct PluginDetailsView: View {
    // MARK: - Properties
    
    let plugin: any LanguagePlugin
    @ObservedObject private var pluginManager: PluginManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: DetailTab = .overview
    @State private var showingUninstallAlert = false
    @State private var showingConfigurationSheet = false
    @State private var isPluginEnabled: Bool
    
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "PluginDetailsView")
    
    // MARK: - Types
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case configuration = "Configuration"
        case performance = "Performance"
        case logs = "Logs"
        
        var icon: String {
            switch self {
            case .overview: return "info.circle"
            case .configuration: return "gear"
            case .performance: return "speedometer"
            case .logs: return "doc.text"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(plugin: any LanguagePlugin, pluginManager: PluginManager) {
        self.plugin = plugin
        self.pluginManager = pluginManager
        self._isPluginEnabled = State(initialValue: pluginManager.isPluginEnabled(plugin.id))
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Plugin header
                pluginHeader
                
                // Tab selection
                tabSelector
                
                // Tab content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(DetailTab.overview)
                    
                    configurationTab
                        .tag(DetailTab.configuration)
                    
                    performanceTab
                        .tag(DetailTab.performance)
                    
                    logsTab
                        .tag(DetailTab.logs)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle(plugin.metadata.name)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(isPluginEnabled ? "Disable" : "Enable") {
                        togglePluginEnabled()
                    }
                    .buttonStyle(.bordered)
                    
                    Menu("Actions") {
                        Button("Configure") {
                            showingConfigurationSheet = true
                        }
                        
                        Button("View Documentation") {
                            openDocumentation()
                        }
                        
                        Divider()
                        
                        Button("Export Settings") {
                            exportPluginSettings()
                        }
                        
                        Button("Reset to Defaults") {
                            resetPluginSettings()
                        }
                        
                        Divider()
                        
                        Button("Uninstall", role: .destructive) {
                            showingUninstallAlert = true
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Uninstall Plugin", isPresented: $showingUninstallAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall", role: .destructive) {
                    uninstallPlugin()
                }
            } message: {
                Text("Are you sure you want to uninstall \(plugin.metadata.name)? This action cannot be undone.")
            }
            .sheet(isPresented: $showingConfigurationSheet) {
                PluginConfigurationSheet(plugin: plugin, pluginManager: pluginManager)
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private var pluginHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Plugin icon
                Image(systemName: plugin.metadata.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(isPluginEnabled ? .accentColor : .secondary)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.metadata.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("v\(plugin.metadata.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text("by \(plugin.metadata.author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isPluginEnabled ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        
                        Text(isPluginEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundColor(isPluginEnabled ? .green : .secondary)
                    }
                }
                
                Spacer()
            }
            
            Text(plugin.metadata.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - Tab Selector
    
    @ViewBuilder
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.secondary.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
                .offset(x: tabIndicatorOffset, y: 0)
                .animation(.easeInOut, value: selectedTab)
            , alignment: .bottom
        )
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Basic information
                infoSection(title: "Information") {
                    InfoRow(label: "Category", value: plugin.metadata.category)
                    InfoRow(label: "Version", value: plugin.metadata.version)
                    InfoRow(label: "Author", value: plugin.metadata.author)
                    InfoRow(label: "License", value: plugin.metadata.license)
                }
                
                // Supported languages
                infoSection(title: "Supported Languages") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(plugin.supportedLanguages, id: \.rawValue) { language in
                            Text(language.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                }
                
                // Capabilities
                infoSection(title: "Capabilities") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(capabilityList, id: \.name) { capability in
                            CapabilityRow(capability: capability)
                        }
                    }
                }
                
                // Dependencies
                if !plugin.metadata.dependencies.isEmpty {
                    infoSection(title: "Dependencies") {
                        ForEach(plugin.metadata.dependencies, id: \.self) { dependency in
                            Text("• \(dependency)")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var configurationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Plugin configuration options will be displayed here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                
                // This would contain actual configuration options
                // based on the plugin's configuration schema
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var performanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let stats = pluginManager.performanceStatistics[plugin.id] {
                    performanceStatsView(stats)
                } else {
                    Text("No performance data available yet.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var logsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Plugin logs and debugging information will be displayed here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                
                // This would contain actual plugin logs
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content()
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func performanceStatsView(_ stats: PluginPerformanceStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Overall Score", value: String(format: "%.1f", stats.overallScore), color: scoreColor(stats.overallScore))
                StatCard(title: "Startup Time", value: "\(Int(stats.startupTime * 1_000))ms", color: .blue)
                StatCard(title: "Memory Usage", value: String(format: "%.1f MB", stats.memoryUsage), color: .orange)
                StatCard(title: "Error Count", value: "\(stats.errorCount)", color: stats.errorCount > 0 ? .red : .green)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Performance History")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Placeholder for performance chart
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Text("Performance chart would be displayed here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var tabIndicatorOffset: CGFloat {
        let tabWidth = UIScreen.main.bounds.width / CGFloat(DetailTab.allCases.count)
        let selectedIndex = DetailTab.allCases.firstIndex(of: selectedTab) ?? 0
        return tabWidth * CGFloat(selectedIndex) - UIScreen.main.bounds.width / 2 + tabWidth / 2
    }
    
    private var capabilityList: [(name: String, enabled: Bool)] {
        [
            ("Syntax Highlighting", plugin.metadata.capabilities.contains("syntax")),
            ("Code Completion", plugin.metadata.capabilities.contains("completion")),
            ("Code Formatting", plugin.metadata.capabilities.contains("formatting")),
            ("Error Detection", plugin.metadata.capabilities.contains("linting")),
            ("Documentation", plugin.metadata.capabilities.contains("documentation")),
            ("Symbol Navigation", plugin.metadata.capabilities.contains("navigation"))
        ]
    }
    
    // MARK: - Actions
    
    private func togglePluginEnabled() {
        Task {
            if isPluginEnabled {
                await pluginManager.disablePlugin(plugin.id)
            } else {
                await pluginManager.enablePlugin(plugin.id)
            }
            
            await MainActor.run {
                isPluginEnabled.toggle()
            }
        }
    }
    
    private func openDocumentation() {
        // Open plugin documentation URL if available
        logger.info("Opening documentation for plugin: \(plugin.id)")
    }
    
    private func exportPluginSettings() {
        // Export plugin configuration
        logger.info("Exporting settings for plugin: \(plugin.id)")
    }
    
    private func resetPluginSettings() {
        // Reset plugin to default settings
        logger.info("Resetting settings for plugin: \(plugin.id)")
    }
    
    private func uninstallPlugin() {
        Task {
            await pluginManager.uninstallPlugin(plugin.id)
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...:
            return .green

        case 0.6..<0.8:
            return .orange

        default:
            return .red
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.body)
            
            Spacer()
        }
    }
}

struct CapabilityRow: View {
    let capability: (name: String, enabled: Bool)
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: capability.enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(capability.enabled ? .green : .secondary)
            
            Text(capability.name)
                .font(.body)
                .foregroundColor(capability.enabled ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Plugin Configuration Sheet

struct PluginConfigurationSheet: View {
    let plugin: any LanguagePlugin
    let pluginManager: PluginManager
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Plugin configuration interface would be displayed here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Configure \(plugin.metadata.name)")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        // Dismiss sheet
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PluginDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PluginDetailsView(
            plugin: TypeScriptPlugin(),
            pluginManager: PluginManager()
        )
        .previewDisplayName("Plugin Details")
    }
}
#endif
