import Foundation

// MARK: - Specialized Actors for Different Subsystems

/// Actor responsible for managing text processing operations
/// 
/// This actor isolates all text manipulation and processing operations,
/// ensuring thread-safe access to text buffers and processing state.
@available(macOS 13.0, iOS 16.0, *)
public actor TextProcessingActor {
    private var activeProcessors: [UUID: TextProcessor] = [:]
    private var textBuffers: [UUID: String] = [:]
    private let errorRecovery = ErrorRecoveryCoordinator()
    
    public struct TextProcessor {
        let id: UUID
        let type: ProcessorType
        let priority: TaskPriority
        var isCancelled: Bool = false
        
        public enum ProcessorType: Sendable {
            case indentation
            case bracketMatching
            case lineWrapping
            case whitespaceNormalization
            case encoding(String.Encoding)
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToSwiftPriority(_ priority: TaskPriority) -> _Concurrency.TaskPriority {
        switch priority {
        case .low: return .low
        case .normal: return .medium
        case .high: return .high
        case .critical: return .high  // No .critical in Swift Concurrency
        }
    }
    
    /// Process text with the specified processor type
    public func process(
        text: String,
        with processorType: TextProcessor.ProcessorType,
        priority: TaskPriority = .high
    ) async throws -> String {
        let processorId = UUID()
        let processor = TextProcessor(
            id: processorId,
            type: processorType,
            priority: priority
        )
        
        activeProcessors[processorId] = processor
        defer { activeProcessors.removeValue(forKey: processorId) }
        
        switch processorType {
        case .indentation:
            return try await processIndentation(text)

        case .bracketMatching:
            return try await processBracketMatching(text)

        case .lineWrapping:
            return try await processLineWrapping(text)

        case .whitespaceNormalization:
            return try await normalizeWhitespace(text)

        case .encoding(let encoding):
            return try await processEncoding(text, encoding: encoding)
        }
    }
    
    /// Cancel all active text processing operations
    public func cancelAllProcessing() {
        for id in activeProcessors.keys {
            activeProcessors[id]?.isCancelled = true
        }
    }
    
    private func processIndentation(_ text: String) async throws -> String {
        // Implementation for smart indentation
        try Task.checkCancellation()
        // Simplified implementation
        return text
    }
    
    private func processBracketMatching(_ text: String) async throws -> String {
        // Implementation for bracket matching
        try Task.checkCancellation()
        // Simplified implementation
        return text
    }
    
    private func processLineWrapping(_ text: String) async throws -> String {
        // Implementation for line wrapping
        try Task.checkCancellation()
        // Simplified implementation
        return text
    }
    
    private func normalizeWhitespace(_ text: String) async throws -> String {
        // Implementation for whitespace normalization
        try Task.checkCancellation()
        // Simplified implementation
        return text
    }
    
    private func processEncoding(_ text: String, encoding: String.Encoding) async throws -> String {
        // Implementation for encoding conversion
        try Task.checkCancellation()
        guard let data = text.data(using: encoding),
              let result = String(data: data, encoding: encoding) else {
            throw CodeEditorError.encodingFailed(.utf8)
        }
        return result
    }
}

/// Actor responsible for managing caching operations across the editor
@available(macOS 13.0, iOS 16.0, *)
public actor CacheCoordinatorActor {
    private var caches: [String: AnyCacheWrapper] = [:]
    
    /// Type-erased wrapper for CacheProtocol
    private struct AnyCacheWrapper: Sendable {
        let getValue: @Sendable (String) async -> (any Sendable)?
        let setValue: @Sendable (any Sendable, String, Int) async -> Void
        let contains: @Sendable (String) async -> Bool
        let clear: @Sendable () async -> Void
        
        init<Cache: CacheProtocol>(_ cache: Cache) where Cache.Value: Sendable {
            self.getValue = { key in
                await cache.getValue(for: key)
            }
            self.setValue = { value, key, cost in
                if let typedValue = value as? Cache.Value {
                    await cache.setValue(typedValue, for: key, cost: cost)
                }
            }
            self.contains = { key in
                await cache.contains(key: key)
            }
            self.clear = {
                await cache.clear()
            }
        }
    }
    
    private var cacheStats: [String: CacheStatistics] = [:]
    private let maxGlobalMemoryMB: Double = 200.0
    private var currentMemoryUsageMB: Double = 0.0
    
    public struct CacheStatistics {
        public let hits: Int
        public let misses: Int
        public let evictions: Int
        public let memoryUsageMB: Double
        public let lastAccessTime: Date
    }
    
    /// Register a cache with the coordinator
    public func registerCache<T: CacheProtocol>(_ cache: T, identifier: String) where T.Value: Sendable {
        caches[identifier] = AnyCacheWrapper(cache)
        cacheStats[identifier] = CacheStatistics(
            hits: 0,
            misses: 0,
            evictions: 0,
            memoryUsageMB: 0,
            lastAccessTime: Date()
        )
    }
    
    /// Get value from cache
    public func getValue<T: Sendable>(
        for key: String,
        from cacheId: String
    ) async -> T? {
        guard let cache = caches[cacheId] else { return nil }
        
        // Update stats
        if let stats = cacheStats[cacheId] {
            let hit = await cache.contains(key)
            cacheStats[cacheId] = CacheStatistics(
                hits: stats.hits + (hit ? 1 : 0),
                misses: stats.misses + (hit ? 0 : 1),
                evictions: stats.evictions,
                memoryUsageMB: stats.memoryUsageMB,
                lastAccessTime: Date()
            )
        }
        
        let value = await cache.getValue(key)
        return value as? T
    }
    
    /// Set value in cache
    public func setValue<T: Sendable>(
        _ value: T,
        for key: String,
        in cacheId: String,
        cost: Int = 1
    ) async {
        guard let cache = caches[cacheId] else { return }
        
        // Check memory pressure
        if currentMemoryUsageMB > maxGlobalMemoryMB * 0.9 {
            await performGlobalEviction()
        }
        
        await cache.setValue(value, key, cost)
    }
    
    /// Clear specific cache
    public func clearCache(_ cacheId: String) async {
        guard let cache = caches[cacheId] else { return }
        await cache.clear()
        
        if let stats = cacheStats[cacheId] {
            cacheStats[cacheId] = CacheStatistics(
                hits: stats.hits,
                misses: stats.misses,
                evictions: stats.evictions + 1,
                memoryUsageMB: 0,
                lastAccessTime: Date()
            )
        }
    }
    
    /// Perform global cache eviction based on LRU
    private func performGlobalEviction() async {
        // Find least recently used caches
        let sortedCaches = cacheStats.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
        
        // Evict 20% of caches starting with LRU
        let evictionCount = max(1, sortedCaches.count / 5)
        for (cacheId, _) in sortedCaches.prefix(evictionCount) {
            await clearCache(cacheId)
        }
    }
}

/// Protocol for caches that can be managed by CacheCoordinatorActor
@available(macOS 13.0, iOS 16.0, *)
public protocol CacheProtocol: Actor {
    associatedtype Value: Sendable
    func getValue(for key: String) async -> Value?
    func setValue(_ value: Value, for key: String, cost: Int) async
    func contains(key: String) async -> Bool
    func clear() async
}

/// Actor responsible for file system operations
@available(macOS 13.0, iOS 16.0, *)
public actor FileSystemActor {
    private let fileManager = FileManager.default
    private var fileHandles: [URL: FileHandle] = [:]
    private var watchers: [URL: FileWatcher] = [:]
    
    private struct FileWatcher {
        let url: URL
        let handler: @Sendable (FileChangeNotification) async -> Void
        let source: DispatchSourceFileSystemObject?
    }
    
    /// Read file contents
    public func readFile(at url: URL) async throws -> String {
        if let handle = fileHandles[url] {
            try handle.seek(toOffset: 0)
            let data = handle.readDataToEndOfFile()
            guard let content = String(data: data, encoding: .utf8) else {
                throw CodeEditorError.encodingFailed(.utf8)
            }
            return content
        }
        
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw CodeEditorError.encodingFailed(.utf8)
        }
        return content
    }
    
    /// Write file contents
    public func writeFile(_ content: String, to url: URL) async throws {
        guard let data = content.data(using: .utf8) else {
            throw CodeEditorError.encodingFailed(.utf8)
        }
        
        if fileHandles[url] != nil {
            closeFile(at: url)
        }
        
        try data.write(to: url)
    }
    
    /// Open file handle for repeated access
    public func openFile(at url: URL) throws {
        guard fileHandles[url] == nil else { return }
        
        let handle = try FileHandle(forReadingFrom: url)
        fileHandles[url] = handle
    }
    
    /// Close file handle
    public func closeFile(at url: URL) {
        if let handle = fileHandles[url] {
            try? handle.close()
            fileHandles.removeValue(forKey: url)
        }
    }
    
    /// Watch file for changes
    public func watchFile(
        at url: URL,
        handler: @escaping @Sendable (FileChangeNotification) async -> Void
    ) throws {
        guard watchers[url] == nil else { return }
        
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )
        
        source.setEventHandler { [weak self] in
            guard self != nil else { return }
            
            let notification: FileChangeNotification
            if source.data.contains(.delete) {
                notification = FileChangeNotification(
                    path: url.path,
                    changeType: .deleted
                )
            } else if source.data.contains(.rename) {
                notification = FileChangeNotification(
                    path: url.path,
                    changeType: .renamed(from: url.path, to: url.path)
                )
            } else {
                notification = FileChangeNotification(
                    path: url.path,
                    changeType: .modified
                )
            }
            
            Task {
                await handler(notification)
            }
        }
        
        source.setCancelHandler {
            close(descriptor)
        }
        
        source.resume()
        
        watchers[url] = FileWatcher(
            url: url,
            handler: handler,
            source: source
        )
    }
    
    /// Stop watching file
    public func unwatchFile(at url: URL) {
        if let watcher = watchers[url] {
            watcher.source?.cancel()
            watchers.removeValue(forKey: url)
        }
    }
    
    deinit {
        // Clean up file handles and watchers synchronously
        for (_, handle) in fileHandles {
            try? handle.close()
        }
        
        for (_, watcher) in watchers {
            watcher.source?.cancel()
        }
    }
}

/// Actor responsible for managing performance metrics
@available(macOS 13.0, iOS 16.0, *)
public actor PerformanceMetricsActor {
    private var metrics: [String: [SendablePerformanceMetric]] = [:]
    private let maxMetricsPerCategory = 1_000
    private var aggregatedStats: [String: AggregatedStats] = [:]
    
    public struct AggregatedStats: Sendable {
        public let category: String
        public let count: Int
        public let averageDuration: Duration
        public let minDuration: Duration
        public let maxDuration: Duration
        public let percentile95: Duration
        public let lastUpdated: Date
    }
    
    /// Record a performance metric
    public func record(_ metric: SendablePerformanceMetric) {
        let category = metric.name
        
        // Add to metrics array
        var categoryMetrics = metrics[category] ?? []
        categoryMetrics.append(metric)
        
        // Limit array size
        if categoryMetrics.count > maxMetricsPerCategory {
            categoryMetrics.removeFirst(categoryMetrics.count - maxMetricsPerCategory)
        }
        
        metrics[category] = categoryMetrics
        
        // Update aggregated stats
        updateAggregatedStats(for: category)
    }
    
    /// Get aggregated statistics for a category
    public func getStats(for category: String) -> AggregatedStats? {
        aggregatedStats[category]
    }
    
    /// Get all aggregated statistics
    public func getAllStats() -> [String: AggregatedStats] {
        aggregatedStats
    }
    
    /// Clear metrics for a specific category
    public func clearMetrics(for category: String) {
        metrics.removeValue(forKey: category)
        aggregatedStats.removeValue(forKey: category)
    }
    
    /// Clear all metrics
    public func clearAllMetrics() {
        metrics.removeAll()
        aggregatedStats.removeAll()
    }
    
    private func updateAggregatedStats(for category: String) {
        guard let categoryMetrics = metrics[category], !categoryMetrics.isEmpty else { return }
        
        let durations = categoryMetrics.map { $0.duration }
        
        // Convert durations to milliseconds for sorting
        let durationMs = durations.map { duration in
            Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        }
        
        let sortedIndices = Array(0..<durations.count).sorted { firstIndex, secondIndex in
            durationMs[firstIndex] < durationMs[secondIndex]
        }
        
        let sortedDurations = sortedIndices.map { durations[$0] }
        
        let totalMs = durationMs.reduce(0.0, +)
        
        let averageMs = totalMs / Double(durations.count)
        let percentile95Index = Int(Double(sortedDurations.count) * 0.95)
        
        aggregatedStats[category] = AggregatedStats(
            category: category,
            count: categoryMetrics.count,
            averageDuration: .milliseconds(Int(averageMs)),
            minDuration: sortedDurations.first ?? .zero,
            maxDuration: sortedDurations.last ?? .zero,
            percentile95: sortedDurations[min(percentile95Index, sortedDurations.count - 1)],
            lastUpdated: Date()
        )
    }
}

/// Actor responsible for managing document state
@available(macOS 13.0, iOS 16.0, *)
public actor DocumentStateActor {
    private var documents: [UUID: DocumentState] = [:]
    private var documentURLs: [URL: UUID] = [:]
    
    public struct DocumentState: Sendable {
        public let id: UUID
        public let url: URL?
        public var content: String
        public var isDirty: Bool
        public var version: Int
        public var language: Language
        public var lastModified: Date
        public var metadata: [String: String]
        
        public init(
            content: String,
            url: URL? = nil,
            language: Language = .plainText,
            metadata: [String: String] = [:]
        ) {
            self.id = UUID()
            self.url = url
            self.content = content
            self.isDirty = false
            self.version = 0
            self.language = language
            self.lastModified = Date()
            self.metadata = metadata
        }
    }
    
    /// Create a new document
    public func createDocument(
        content: String,
        url: URL? = nil,
        language: Language = .plainText
    ) -> UUID {
        let state = DocumentState(content: content, url: url, language: language)
        documents[state.id] = state
        
        if let url {
            documentURLs[url] = state.id
        }
        
        return state.id
    }
    
    /// Update document content
    public func updateContent(for documentId: UUID, content: String) {
        guard var state = documents[documentId] else { return }
        
        state.content = content
        state.isDirty = true
        state.version += 1
        state.lastModified = Date()
        
        documents[documentId] = state
    }
    
    /// Get document state
    public func getDocument(_ documentId: UUID) -> DocumentState? {
        documents[documentId]
    }
    
    /// Get document by URL
    public func getDocument(at url: URL) -> DocumentState? {
        guard let id = documentURLs[url] else { return nil }
        return documents[id]
    }
    
    /// Mark document as saved
    public func markSaved(_ documentId: UUID) {
        guard var state = documents[documentId] else { return }
        state.isDirty = false
        documents[documentId] = state
    }
    
    /// Close document
    public func closeDocument(_ documentId: UUID) {
        if let state = documents[documentId], let url = state.url {
            documentURLs.removeValue(forKey: url)
        }
        documents.removeValue(forKey: documentId)
    }
}
