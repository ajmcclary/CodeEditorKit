import CodeEditorPlugin
import SwiftUI

/// A thread-safe coordinator that manages configuration updates to avoid concurrency crashes
@MainActor
final class ConfigurationCoordinator: ObservableObject {
    @Published var configuration: EditorConfiguration
    
    init(configuration: EditorConfiguration = EditorConfiguration()) {
        self.configuration = configuration
    }
    
    /// Safely update configuration immediately
    func update(_ block: (inout EditorConfiguration) -> Void) {
        var newConfig = configuration
        block(&newConfig)
        configuration = newConfig
    }
    
    /// Apply a preset configuration
    func applyPreset(_ preset: ConfigurationPreset) {
        configuration = preset.configuration
    }
    
    /// Reset to default configuration
    func reset() {
        configuration = EditorConfiguration()
    }
}
