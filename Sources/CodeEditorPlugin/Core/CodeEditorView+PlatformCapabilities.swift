import Foundation

// MARK: - CodeEditorView Platform Capability Convenience

extension CodeEditorView {
    /// Apply platform-optimized configuration.
    public func applyPlatformOptimizations() {
        let capabilities = runtime.dependencies.platformCapabilities
        let config = capabilities.recommendedConfiguration()
        self.configuration = config
    }
}
