import os.log
import SwiftUI

/// SwiftUI view for configuring plugins and their settings
@MainActor
public struct PluginConfigurationView: View {
    // MARK: - State
    
    /// Plugin manager reference
    @ObservedObject private var pluginManager: PluginManager
    
    /// Currently selected plugin for detailed configuration
    @State private var selectedPlugin: (any LanguagePlugin)?
    
    /// Search text for filtering plugins
    @State private var searchText = ""
    
    /// Whether to show only enabled plugins
    @State private var showOnlyEnabled = false
    
    /// Show plugin installation sheet
    @State private var showInstallSheet = false
    
    /// Show plugin creation sheet
    @State private var showCreateSheet = false
    
    /// Show plugin details sheet
    @State private var showDetailsSheet = false
    
    /// Plugin performance statistics visibility
    @State private var showPerformanceStats = false
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "PluginConfigurationView")
    
    // MARK: - Initialization
    
    public init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and filters
                headerView
                
                // Main content area
                if filteredPlugins.isEmpty {
                    emptyStateView
                } else {
                    pluginListView
                }
                
                // Footer with statistics
                footerView
            }
            .navigationTitle("Plugin Configuration")
            .toolbar {
                toolbarContent
            }
            .searchable(text: $searchText, prompt: "Search plugins...")
            .sheet(isPresented: $showInstallSheet) {
                PluginInstallationView(pluginManager: pluginManager)
            }
            .sheet(isPresented: $showCreateSheet) {
                PluginCreationView(pluginManager: pluginManager)
            }
            .sheet(isPresented: $showDetailsSheet) {
                if let plugin = selectedPlugin {
                    PluginDetailsView(plugin: plugin, pluginManager: pluginManager)
                }
            }
        }
        #if canImport(UIKit)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Manage Plugins")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Enabled Only", isOn: $showOnlyEnabled)
                    .toggleStyle(SwitchToggleStyle())
            }
            .padding(.horizontal)
            
            Divider()
        }
        .padding(.top)
    }
    
    @ViewBuilder
    private var pluginListView: some View {
        List {
            ForEach(groupedPlugins.keys.sorted(), id: \.self) { category in
                Section(header: Text(category).font(.subheadline).foregroundColor(.secondary)) {
                    ForEach(groupedPlugins[category] ?? [], id: \.id) { plugin in
                        PluginRowView(
                            plugin: plugin,
                            pluginManager: pluginManager
                        ) { selectedPlugin = plugin; showDetailsSheet = true }
                    }
                }
            }
        }
        #if canImport(UIKit)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(DefaultListStyle())
        #endif
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Plugins Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(searchText.isEmpty ? "No plugins are installed" : "No plugins match your search")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Install Plugin") {
                showInstallSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var footerView: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Statistics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        StatisticView(
                            title: "Total",
                            value: "\(pluginManager.registeredPlugins.count)"
                        )
                        
                        StatisticView(
                            title: "Enabled",
                            value: "\(enabledPluginsCount)"
                        )
                        
                        StatisticView(
                            title: "Performance Score",
                            value: String(format: "%.1f", averagePerformanceScore)
                        )
                    }
                }
                
                Spacer()
                
                Button("Performance Details") {
                    showPerformanceStats.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
        }
        .background(Color(PlatformColors.systemBackground))
        .popover(isPresented: $showPerformanceStats) {
            PerformanceStatsView(pluginManager: pluginManager)
                .frame(minWidth: 300, minHeight: 200)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Create Plugin") {
                showCreateSheet = true
            }
            
            Button("Install Plugin") {
                showInstallSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        
        ToolbarItemGroup(placement: .automatic) {
            Menu("Plugin Actions") {
                Button("Refresh All") {
                    Task {
                        // Refresh all plugins by rescanning directories
                        // This method doesn't exist yet, so we'll leave it as a placeholder
                        // await pluginManager.refreshAllPlugins()
                    }
                }
                
                Button("Check for Updates") {
                    Task {
                        await checkForPluginUpdates()
                    }
                }
                
                Divider()
                
                Button("Export Configuration") {
                    exportPluginConfiguration()
                }
                
                Button("Import Configuration") {
                    importPluginConfiguration()
                }
                
                Divider()
                
                Button("Reset All Settings") {
                    resetAllPluginSettings()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredPlugins: [any LanguagePlugin] {
        var plugins = pluginManager.registeredPlugins
        
        // Filter by enabled status
        if showOnlyEnabled {
            plugins = plugins.filter { pluginManager.isPluginEnabled($0.id) }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            plugins = plugins.filter { plugin in
                plugin.metadata.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.metadata.description.localizedCaseInsensitiveContains(searchText) ||
                plugin.metadata.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return plugins
    }
    
    private var groupedPlugins: [String: [any LanguagePlugin]] {
        Dictionary(grouping: filteredPlugins) { plugin in
            plugin.metadata.category
        }
    }
    
    private var enabledPluginsCount: Int {
        pluginManager.registeredPlugins.filter { pluginManager.isPluginEnabled($0.id) }.count
    }
    
    private var averagePerformanceScore: Double {
        let stats = pluginManager.performanceStatistics
        guard !stats.isEmpty else { return 0.0 }
        
        let totalScore = stats.values.reduce(0.0) { sum, stat in
            sum + stat.overallScore
        }
        
        return totalScore / Double(stats.count)
    }
    
    // MARK: - Actions
    
    private func checkForPluginUpdates() async {
        logger.info("Checking for plugin updates...")
        // Implementation would check for updates from plugin repositories
        // For now, this is a placeholder
    }
    
    private func exportPluginConfiguration() {
        logger.info("Exporting plugin configuration...")
        // Implementation would export current plugin settings to a file
        // For now, this is a placeholder
    }
    
    private func importPluginConfiguration() {
        logger.info("Importing plugin configuration...")
        // Implementation would import plugin settings from a file
        // For now, this is a placeholder
    }
    
    private func resetAllPluginSettings() {
        logger.info("Resetting all plugin settings...")
        
        Task {
            for plugin in pluginManager.registeredPlugins {
                await pluginManager.disablePlugin(plugin.id)
            }
            
            // Reset to default configuration
            // Load default plugins - this method doesn't exist yet
            // await pluginManager.loadDefaultPlugins()
        }
    }
}

// MARK: - Plugin Row View

struct PluginRowView: View {
    let plugin: any LanguagePlugin
    let pluginManager: PluginManager
    let onSelect: () -> Void
    
    @State private var isEnabled: Bool
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "PluginRowView")
    
    init(plugin: any LanguagePlugin, pluginManager: PluginManager, onSelect: @escaping () -> Void) {
        self.plugin = plugin
        self.pluginManager = pluginManager
        self.onSelect = onSelect
        self._isEnabled = State(initialValue: pluginManager.isPluginEnabled(plugin.id))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Plugin icon/status
            VStack {
                Image(systemName: plugin.metadata.iconName)
                    .font(.title2)
                    .foregroundColor(isEnabled ? .green : .secondary)
                
                Circle()
                    .fill(isEnabled ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 40)
            
            // Plugin information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.metadata.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("v\(plugin.metadata.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(plugin.metadata.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label(
                        "Languages: \(plugin.supportedLanguages.map(\.name).joined(separator: ", "))", 
                        systemImage: "textformat"
                    )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let stats = pluginManager.performanceStatistics[plugin.id] {
                        Label(
                            "Score: \(String(format: "%.1f", stats.overallScore))", 
                            systemImage: "speedometer"
                        )
                            .font(.caption)
                            .foregroundColor(scoreColor(stats.overallScore))
                    }
                }
            }
            
            // Toggle and actions
            VStack(spacing: 8) {
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: isEnabled) { newValue in
                        Task {
                            do {
                                if newValue {
                                    try await pluginManager.enablePlugin(plugin.id)
                                } else {
                                    await pluginManager.disablePlugin(plugin.id)
                                }
                            } catch {
                                logger.error("Failed to toggle plugin: \(error)")
                            }
                        }
                    }
                
                Button("Details") {
                    onSelect()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .accessibilityAddTraits(.isButton)
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

// MARK: - Statistic View

struct StatisticView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Performance Stats View

struct PerformanceStatsView: View {
    @ObservedObject var pluginManager: PluginManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plugin Performance Statistics")
                .font(.headline)
                .padding(.bottom, 8)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sortedPerformanceStats, id: \.0) { pluginId, stats in
                        PerformanceStatRow(pluginId: pluginId, stats: stats)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("Last Updated: \(Date(), style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Refresh") {
                    // Refresh performance stats
                }
                .font(.caption)
            }
        }
        .padding()
    }
    
    private var sortedPerformanceStats: [(String, PluginPerformanceStatistics)] {
        pluginManager.performanceStatistics
            .sorted { $0.value.overallScore > $1.value.overallScore }
    }
}

struct PerformanceStatRow: View {
    let pluginId: String
    let stats: PluginPerformanceStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pluginId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.2f", stats.overallScore))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor)
            }
            
            HStack(spacing: 16) {
                StatDetail(title: "Startup", value: "\(Int(stats.startupTime * 1_000))ms")
                StatDetail(title: "Memory", value: String(format: "%.1fMB", stats.memoryUsage))
                StatDetail(title: "Errors", value: "\(stats.errorCount)")
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
    
    private var scoreColor: Color {
        switch stats.overallScore {
        case 0.8...:
            return .green

        case 0.6..<0.8:
            return .orange

        default:
            return .red
        }
    }
}

struct StatDetail: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text(value)
                .fontWeight(.medium)
            Text(title)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
}

// MARK: - Preview

#if DEBUG
struct PluginConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        PluginConfigurationView(pluginManager: PluginManager())
            .previewDisplayName("Plugin Configuration")
    }
}
#endif

