import Foundation

// MARK: - Adaptive Processing Settings

/// Adaptive performance settings for text processing
/// Extracted from AsyncTextProcessor for reusability and testability
internal struct AdaptiveProcessingSettings {
    var batchSize: Int = 1_000
    var delayBetweenBatches: TimeInterval = 0

    mutating func updateForLoad(_ load: ProcessingLoad) {
        switch load {
        case .idle:
            batchSize = 2_000
            delayBetweenBatches = 0

        case .low:
            batchSize = 1_000
            delayBetweenBatches = 0

        case .medium:
            batchSize = 500
            delayBetweenBatches = 0.001 // 1ms

        case .high:
            batchSize = 200
            delayBetweenBatches = 0.005 // 5ms
        }
    }

    func settingsForLoad(_: ProcessingLoad) -> (batchSize: Int, delayBetweenBatches: TimeInterval) {
        (batchSize: batchSize, delayBetweenBatches: delayBetweenBatches)
    }
}
