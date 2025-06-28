import os.log
import SwiftUI

/// SwiftUI view for installing new plugins
@MainActor
public struct PluginInstallationView: View {
    // MARK: - Properties
    
    @ObservedObject private var pluginManager: PluginManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var installationMethod: InstallationMethod = .repository
    @State private var repositoryURL = ""
    @State private var localPath = ""
    @State private var isInstalling = false
    @State private var installationProgress: Double = 0.0
    @State private var installationStatus = ""
    @State private var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "PluginInstallationView")
    
    // MARK: - Types
    
    enum InstallationMethod: String, CaseIterable {
        case repository = "Repository"
        case local = "Local File"
        case marketplace = "Marketplace"
        
        var icon: String {
            switch self {
            case .repository: return "link"
            case .local: return "folder"
            case .marketplace: return "storefront"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Installation method picker
                installationMethodPicker
                
                // Content based on selected method
                switch installationMethod {
                case .repository:
                    repositoryInstallationView

                case .local:
                    localInstallationView

                case .marketplace:
                    marketplaceView
                }
                
                Spacer()
                
                // Installation progress
                if isInstalling {
                    installationProgressView
                }
                
                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Install Plugin")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Installation Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var installationMethodPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installation Method")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(InstallationMethod.allCases, id: \.self) { method in
                    Button(action: {
                        installationMethod = method
                        clearInputs()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: method.icon)
                                .font(.title2)
                                .foregroundColor(installationMethod == method ? .white : .primary)
                            
                            Text(method.rawValue)
                                .font(.caption)
                                .foregroundColor(installationMethod == method ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(installationMethod == method ? Color.accentColor : Color.secondary.opacity(0.2))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    @ViewBuilder
    private var repositoryInstallationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repository URL")
                .font(.headline)
            
            TextField("https://github.com/user/plugin.git", text: $repositoryURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Text("Enter the Git repository URL for the plugin. The repository should contain a valid plugin manifest.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Quick links to popular plugin repositories
            VStack(alignment: .leading, spacing: 8) {
                Text("Popular Plugin Repositories")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(popularRepositories, id: \.name) { repo in
                    Button(action: {
                        repositoryURL = repo.url
                    }) {
                        HStack {
                            Image(systemName: "link.circle")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.name)
                                    .font(.body)
                                Text(repo.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var localInstallationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local Plugin Path")
                .font(.headline)
            
            HStack {
                TextField("/path/to/plugin", text: $localPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Browse") {
                    browseForLocalPlugin()
                }
                .buttonStyle(.bordered)
            }
            
            Text("Select a local plugin file (.plugin) or directory containing a plugin manifest.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Plugin validation status
            if !localPath.isEmpty {
                pluginValidationStatus
            }
        }
    }
    
    @ViewBuilder
    private var marketplaceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Plugin Marketplace")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("The plugin marketplace is coming soon. You'll be able to browse and install plugins from a curated collection.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Learn More") {
                // Open documentation about plugin marketplace
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var pluginValidationStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: isValidPlugin ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isValidPlugin ? .green : .orange)
            
            Text(isValidPlugin ? "Valid plugin detected" : "Invalid or missing plugin manifest")
                .font(.caption)
                .foregroundColor(isValidPlugin ? .green : .orange)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var installationProgressView: some View {
        VStack(spacing: 12) {
            ProgressView(value: installationProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(installationStatus)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                if isInstalling {
                    cancelInstallation()
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(isInstalling ? "Installing..." : "Install Plugin") {
                installPlugin()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isInstalling || !isInstallEnabled)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isInstallEnabled: Bool {
        switch installationMethod {
        case .repository:
            return !repositoryURL.isEmpty && repositoryURL.hasPrefix("http")

        case .local:
            return !localPath.isEmpty && isValidPlugin

        case .marketplace:
            return false // Not yet implemented
        }
    }
    
    private var isValidPlugin: Bool {
        guard !localPath.isEmpty else { return false }
        
        // Check if path exists and has valid plugin structure
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: localPath) {
            // Check for plugin manifest or .plugin extension
            return localPath.hasSuffix(".plugin") || 
                   fileManager.fileExists(atPath: localPath.appending("/plugin.json")) ||
                   fileManager.fileExists(atPath: localPath.appending("/manifest.json"))
        }
        
        return false
    }
    
    private var popularRepositories: [PluginRepository] {
        [
            PluginRepository(
                name: "Swift Syntax Plugin",
                url: "https://github.com/apple/swift-syntax",
                description: "Official Swift syntax support"
            ),
            PluginRepository(
                name: "LSP Plugins Collection",
                url: "https://github.com/codeeditor/lsp-plugins",
                description: "Language Server Protocol plugins"
            ),
            PluginRepository(
                name: "Theme Pack",
                url: "https://github.com/codeeditor/theme-pack",
                description: "Additional editor themes"
            )
        ]
    }
    
    // MARK: - Actions
    
    private func clearInputs() {
        repositoryURL = ""
        localPath = ""
        errorMessage = nil
    }
    
    private func browseForLocalPlugin() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.init(filenameExtension: "plugin")!]
        } else {
            panel.allowedFileTypes = ["plugin"]
        }
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                localPath = url.path
            }
        }
        #endif
    }
    
    private func installPlugin() {
        isInstalling = true
        installationProgress = 0.0
        errorMessage = nil
        
        Task {
            do {
                switch installationMethod {
                case .repository:
                    await installFromRepository()

                case .local:
                    await installFromLocalPath()

                case .marketplace:
                    throw PluginError.unsupportedOperation("Marketplace installation not yet implemented")
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isInstalling = false
                }
            }
        }
    }
    
    private func installFromRepository() async {
        installationStatus = "Cloning repository..."
        installationProgress = 0.2
        
        // Simulate repository cloning
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        installationStatus = "Validating plugin..."
        installationProgress = 0.5
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        installationStatus = "Installing plugin..."
        installationProgress = 0.8
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        installationStatus = "Finalizing installation..."
        installationProgress = 1.0
        
        // In a real implementation, this would:
        // 1. Clone the repository
        // 2. Validate the plugin manifest
        // 3. Build the plugin if necessary
        // 4. Install to the plugins directory
        // 5. Register with the plugin manager
        
        logger.info("Plugin installed from repository: \(repositoryURL)")
    }
    
    private func installFromLocalPath() async {
        installationStatus = "Validating local plugin..."
        installationProgress = 0.3
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        installationStatus = "Copying plugin files..."
        installationProgress = 0.7
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        installationStatus = "Registering plugin..."
        installationProgress = 1.0
        
        // In a real implementation, this would:
        // 1. Validate the local plugin
        // 2. Copy to the plugins directory
        // 3. Register with the plugin manager
        
        logger.info("Plugin installed from local path: \(localPath)")
    }
    
    private func cancelInstallation() {
        isInstalling = false
        installationProgress = 0.0
        installationStatus = ""
    }
}

// MARK: - Supporting Types

struct PluginRepository {
    let name: String
    let url: String
    let description: String
}

// MARK: - Preview

#if DEBUG
struct PluginInstallationView_Previews: PreviewProvider {
    static var previews: some View {
        PluginInstallationView(pluginManager: PluginManager())
            .previewDisplayName("Plugin Installation")
    }
}
#endif
