import Foundation

// MARK: - MemoryMonitor Extension for Available Memory

extension MemoryMonitor {
    /// Get available memory in MB (estimated based on current usage)
    @MainActor
    public var availableMemoryMB: Double {
        // For simplicity, assume we have at least 100MB available if not under pressure
        // This is a reasonable assumption for modern devices
        let pressure = getMemoryPressure()

        switch pressure {
        case .normal:
            return 500.0 // Plenty of memory available

        case .warning:
            return 100.0 // Some memory available

        case .critical:
            return 50.0 // Very limited memory

        case .urgent:
            return 10.0 // Almost no memory
        }
    }
}
