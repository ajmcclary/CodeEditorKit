import CodeEditorInstrumentation
import CodeEditorLanguages
import Foundation

/// Immutable frequency and recency values consumed by `CompletionRanker`.
struct CompletionLearningSnapshot: Sendable {
    let usageCounts: [String: Int]
    let lastUsed: [String: Date]

    static let empty = Self(
        usageCounts: [:],
        lastUsed: [:]
    )
}

private struct CompletionFrequencyEntry: Sendable {
    var usageCount: Int
    var lastUsed: Date
}

/// Owns session-local completion selection learning.
@MainActor
final class CompletionLearningStore {
    private let entries: LRUCache<String, CompletionFrequencyEntry>
    private var lastContext: CompletionContextModel?

    init(capacity: Int, memoryMonitor: any MemoryMonitoring) {
        self.entries = LRUCache(capacity: capacity, memoryMonitor: memoryMonitor)
    }

    /// Records the context used to scope subsequent accepted items.
    func noteContext(_ context: CompletionContextModel) {
        lastContext = context
    }

    /// Drops the active context without clearing learned values.
    func clearContext() {
        lastContext = nil
    }

    /// Records one accepted completion in the active language context.
    func recordSelection(_ item: CompletionItemModel) {
        guard let language = lastContext?.language else { return }
        let key = "\(language.identifier):\(item.label)"
        var entry = entries.get(key) ?? CompletionFrequencyEntry(
            usageCount: 0,
            lastUsed: Date()
        )
        entry.usageCount += 1
        entry.lastUsed = Date()
        entries.set(entry, forKey: key)
    }

    /// Builds the immutable learning values for one language.
    func snapshot(for language: Language) -> CompletionLearningSnapshot {
        let prefix = "\(language.identifier):"
        var usageCounts: [String: Int] = [:]
        var lastUsed: [String: Date] = [:]
        for key in entries.allKeys where key.hasPrefix(prefix) {
            guard let entry = entries.get(key) else { continue }
            let label = String(key.dropFirst(prefix.count))
            usageCounts[label] = entry.usageCount
            lastUsed[label] = entry.lastUsed
        }
        return CompletionLearningSnapshot(
            usageCounts: usageCounts,
            lastUsed: lastUsed
        )
    }

    /// Clears all learned frequency and recency values.
    func clear() {
        entries.removeAll()
    }

    /// Rebinds memory-pressure observation without replacing learned values.
    func setMemoryMonitor(_ monitor: any MemoryMonitoring) {
        entries.setMemoryMonitor(monitor)
    }
}
