import Foundation

/// Extensions to integrate the plugin system with CodeEditorView
@available(macOS 13.0, iOS 16.0, *)
extension CodeEditorView {
    /// Plugin manager for this editor instance
    public var pluginManager: PluginManager? {
        get {
            objc_getAssociatedObject(self, &kPluginManagerKey) as? PluginManager
        }
        set {
            objc_setAssociatedObject(self, &kPluginManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Initialize plugin system for this editor
    @MainActor
    public func initializePluginSystem() {
        guard pluginManager == nil else { return }

        // Create a default event system if none exists in configuration
        let eventSystem = configuration.eventSystem ?? UnifiedEventSystem()

        // Use registry from service registry or create new ones
        // Note: LanguageRegistry is created fresh as it's not shared in service registry
        let languageRegistry = LanguageRegistry()
        let completionRegistry = businessLogicServices.completionProviderRegistry

        let manager = PluginManager(
            configuration: configuration,
            languageRegistry: languageRegistry,
            completionRegistry: completionRegistry,
            eventSystem: eventSystem
        )

        self.pluginManager = manager

        Task {
            // Register built-in plugins
            await registerBuiltInPlugins(manager)

            // Load plugins
            await manager.loadPlugins()
        }
    }

    /// Register built-in plugins
    private func registerBuiltInPlugins(_ manager: PluginManager) async {
        do {
            // Register Markdown plugin
            try await manager.registerPlugin(MarkdownPlugin.self)

            // Register other built-in plugins here as they're created

        } catch {
            CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "Plugins")
                .error("Failed to register built-in plugins: \(error)")
        }
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Enable plugin system for the code editor
    public func codeEditorPlugins(_: Bool = true) -> some View {
        self.onAppear {
            // This would need to be connected to the actual CodeEditorView instance
            // through the environment or view model
        }
    }

    /// Configure allowed plugins
    public func codeEditorAllowedPlugins(_ identifiers: Set<String>) -> some View {
        self.environment(\.allowedPlugins, identifiers)
    }
}

// MARK: - Environment Keys

@available(macOS 13.0, iOS 16.0, *)
private struct AllowedPluginsKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    var allowedPlugins: Set<String> {
        get { self[AllowedPluginsKey.self] }
        set { self[AllowedPluginsKey.self] = newValue }
    }
}
#endif

// MARK: - Plugin Discovery UI

@available(macOS 13.0, iOS 16.0, *)
@MainActor
public struct PluginDiscoveryView: View {
    @StateObject private var viewModel = PluginDiscoveryViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.availablePlugins) { plugin in
                    PluginRow(plugin: plugin) {
                        await viewModel.togglePlugin(plugin)
                    }
                }
            }
            .navigationTitle("Plugins")
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await viewModel.applyChanges()
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadPlugins()
        }
    }
}

@available(macOS 13.0, iOS 16.0, *)
private struct PluginRow: View {
    let plugin: PluginInfo
    let onToggle: () async -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(plugin.name)
                    .font(.headline)
                Text(plugin.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: .constant(plugin.isEnabled))
                .labelsHidden()
                .accessibilityAddTraits(.isButton)
                .onTapGesture {
                    Task {
                        await onToggle()
                    }
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class PluginDiscoveryViewModel: ObservableObject {
    @Published var availablePlugins: [PluginInfo] = []
    private let loader = PluginLoader()
    private var pluginManager: PluginManager?

    func loadPlugins() async {
        let bundles = await loader.discoverPlugins()

        availablePlugins = bundles.map { bundle in
            PluginInfo(
                identifier: bundle.metadata.identifier,
                name: bundle.metadata.name,
                description: bundle.metadata.description,
                version: bundle.metadata.version,
                author: bundle.metadata.author,
                isEnabled: bundle.metadata.enabledByDefault,
                bundle: bundle
            )
        }
    }

    func togglePlugin(_ plugin: PluginInfo) async {
        if let index = availablePlugins.firstIndex(where: { $0.id == plugin.id }) {
            availablePlugins[index].isEnabled.toggle()
        }
    }

    func applyChanges() async {
        // Apply plugin state changes
        // This would interact with the actual plugin manager
    }
}

@available(macOS 13.0, iOS 16.0, *)
private struct PluginInfo: Identifiable {
    let identifier: String
    let name: String
    let description: String
    let version: String
    let author: String
    var isEnabled: Bool
    let bundle: PluginBundle

    var id: String { identifier }
}

// MARK: - Associated Object Keys

@MainActor
private var kPluginManagerKey: UInt8 = 0
