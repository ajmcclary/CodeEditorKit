import Foundation

// MARK: - System Load Monitor

/// System load detection for adaptive processing
/// Extracted from AsyncTextProcessor for reusability and testability
internal struct SystemLoadMonitor {
    /// System load levels
    enum SystemLoad {
        case low
        case medium
        case high
    }

    /// Gets the current system load level based on CPU utilization
    func currentSystemLoad() -> SystemLoad {
        let info = ProcessInfo.processInfo

        // Get actual system load average
        var loadavg = [Double](repeating: 0, count: 3)
        getloadavg(&loadavg, 3)

        let oneMinuteLoad = loadavg[0]
        let processorCount = Double(info.activeProcessorCount)

        let normalizedLoad = oneMinuteLoad / processorCount

        if normalizedLoad < 0.5 {
            return .low
        } else if normalizedLoad < 0.8 {
            return .medium
        } else {
            return .high
        }
    }
}
