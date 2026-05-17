import CodeEditorPlatform
import Foundation

extension PlatformCapabilities {
    /// Returns a runtime-optimized configuration based on current device capabilities.
    ///
    /// This method analyzes the current device's actual capabilities (CPU cores, memory,
    /// display characteristics) to provide an optimized configuration. It differs from
    /// `EditorConfiguration.platformOptimized` which is a compile-time preset.
    ///
    /// - Returns: An EditorConfiguration optimized for the current device's capabilities
    /// - Note: Must be called on the main actor as it accesses UI-related capabilities
    public func recommendedConfiguration() -> EditorConfiguration {
        PlatformConfigurations.recommended()
    }
}
