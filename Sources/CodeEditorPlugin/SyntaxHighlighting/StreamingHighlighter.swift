import Foundation

/// A streaming highlighter that processes large files in chunks using AsyncSequence
/// 
/// This highlighter improves perceived performance for very large files by yielding
/// highlight results progressively as they are computed, allowing the UI to update
/// incrementally rather than waiting for the entire file to be processed.
///
/// ## Usage Example
///
/// ```swift
/// let highlighter = StreamingHighlighter()
/// 
/// for try await chunk in highlighter.highlightStream(text: largeText, language: .swift) {
///     // Apply tokens progressively
///     applyTokens(chunk.tokens, to: textView, in: chunk.range)
/// }
/// ```
@available(macOS 13.0, iOS 16.0, *)
public struct StreamingHighlighter: Sendable {
    /// Configuration for streaming behavior
    public struct Configuration: Sendable {
        /// Size of text chunks to process at once (in characters)
        public let chunkSize: Int
        
        /// Maximum number of chunks to buffer ahead
        public let bufferSize: Int
        
        /// Priority for background processing
        public let priority: _Concurrency.TaskPriority
        
        /// Whether to yield empty chunks (useful for progress tracking)
        public let yieldEmptyChunks: Bool
        
        public init(
            chunkSize: Int = 50_000,
            bufferSize: Int = 3,
            priority: _Concurrency.TaskPriority = .high,
            yieldEmptyChunks: Bool = false
        ) {
            self.chunkSize = max(1_000, chunkSize) // Minimum 1KB chunks
            self.bufferSize = max(1, bufferSize)
            self.priority = priority
            self.yieldEmptyChunks = yieldEmptyChunks
        }
        
        /// Configuration optimized for very large files (1MB+)
        public static let largeFile = Self(
            chunkSize: 100_000,
            bufferSize: 2,
            priority: .low
        )
        
        /// Configuration for responsive UI updates
        public static let responsive = Self(
            chunkSize: 25_000,
            bufferSize: 5,
            priority: .high
        )
    }
    
    private let configuration: Configuration
    private let coordinator: SyntaxHighlightingCoordinator
    
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.coordinator = SyntaxHighlightingCoordinator()
    }
    
    /// Stream highlight results for the given text
    /// - Parameters:
    ///   - text: The text to highlight
    ///   - language: The programming language
    /// - Returns: An async sequence of highlight chunks
    public func highlightStream(
        text: String,
        language: Language
    ) -> HighlightStream {
        HighlightStream(
            text: text,
            language: language,
            configuration: configuration,
            coordinator: coordinator
        )
    }
}

/// An async sequence that yields highlight results in chunks
@available(macOS 13.0, iOS 16.0, *)
public struct HighlightStream: AsyncSequence {
    public typealias Element = HighlightChunk
    
    let text: String
    let language: Language
    let configuration: StreamingHighlighter.Configuration
    let coordinator: SyntaxHighlightingCoordinator
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            text: text,
            language: language,
            configuration: configuration,
            coordinator: coordinator
        )
    }
    
    /// An async iterator that processes text in chunks
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let text: String
        private let language: Language
        private let configuration: StreamingHighlighter.Configuration
        private let coordinator: SyntaxHighlightingCoordinator
        private var currentOffset: String.Index
        private let endIndex: String.Index
        private var chunkIndex: Int = 0
        
        init(
            text: String,
            language: Language,
            configuration: StreamingHighlighter.Configuration,
            coordinator: SyntaxHighlightingCoordinator
        ) {
            self.text = text
            self.language = language
            self.configuration = configuration
            self.coordinator = coordinator
            self.currentOffset = text.startIndex
            self.endIndex = text.endIndex
        }
        
        public mutating func next() async throws -> HighlightChunk? {
            // Check if we've processed all text
            guard currentOffset < endIndex else { return nil }
            
            // Check for cancellation
            try Task.checkCancellation()
            
            // Calculate chunk boundaries
            let chunkStart = currentOffset
            let remainingDistance = text.distance(from: currentOffset, to: endIndex)
            let chunkDistance = Swift.min(configuration.chunkSize, remainingDistance)
            let chunkEnd = text.index(currentOffset, offsetBy: chunkDistance)
            
            // Extract chunk text
            let chunkText = String(text[chunkStart..<chunkEnd])
            
            // Process chunk with appropriate priority
            let tokens = await processChunk(chunkText, startOffset: chunkStart)
            
            // Update offset for next iteration
            currentOffset = chunkEnd
            chunkIndex += 1
            
            // Create chunk result
            let chunk = HighlightChunk(
                index: chunkIndex - 1,
                range: chunkStart..<chunkEnd,
                tokens: tokens,
                isComplete: currentOffset >= endIndex
            )
            
            // Skip empty chunks unless configured to yield them
            if tokens.isEmpty && !configuration.yieldEmptyChunks && !chunk.isComplete {
                return try await next()
            }
            
            return chunk
        }
        
        private func processChunk(
            _ chunkText: String,
            startOffset: String.Index
        ) async -> [HighlightedToken] {
            // Get tokens for the chunk
            let chunkTokens = await coordinator.highlightAsync(
                source: chunkText,
                language: language
            )
            
            // Adjust token ranges to account for chunk offset
            let startDistance = text.distance(from: text.startIndex, to: startOffset)
            
            return chunkTokens.map { token in
                let adjustedRange = NSRange(
                    location: token.range.location + startDistance,
                    length: token.range.length
                )
                return HighlightedToken(
                    range: adjustedRange,
                    type: token.type,
                    text: token.text
                )
            }
        }
    }
}

/// A chunk of highlight results
@available(macOS 13.0, iOS 16.0, *)
public struct HighlightChunk: Sendable {
    /// The chunk index (0-based)
    public let index: Int
    
    /// The text range this chunk covers
    public let range: Range<String.Index>
    
    /// The highlight tokens found in this chunk
    public let tokens: [HighlightedToken]
    
    /// Whether this is the final chunk
    public let isComplete: Bool
    
    /// Progress percentage (0.0 to 1.0)
    public var progress: Double {
        // This is an approximation since we don't know total chunks ahead of time
        // Could be improved by pre-calculating based on text length
        isComplete ? 1.0 : Double(index) / Double(index + 3)
    }
}

// MARK: - Integration with AsyncSyntaxHighlighter

@available(macOS 13.0, iOS 16.0, *)
extension AsyncSyntaxHighlighter {
    /// Perform streaming highlighting for very large files
    /// - Parameters:
    ///   - textView: The text view to highlight
    ///   - language: The programming language
    ///   - visibleRange: Optional visible range for priority processing
    ///   - configuration: Streaming configuration
    public func highlightStreamingly(
        for textView: CodeEditorView,
        language: Language,
        visibleRange: NSRange? = nil,
        configuration: StreamingHighlighter.Configuration = .largeFile
    ) async {
        // Cancel any existing highlighting
        cancelAllHighlighting()
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let text = textView.string
        #else
        let text = textView.text ?? ""
        #endif
        
        // Create highlighter
        let highlighter = StreamingHighlighter(configuration: configuration)
        
        // Track processed tokens for deduplication
        var allTokens: [HighlightedToken] = []
        
        // Process stream
        do {
            for try await chunk in highlighter.highlightStream(text: text, language: language) {
                // Check if cancelled
                guard !Task.isCancelled else { break }
                
                // Accumulate tokens
                allTokens.append(contentsOf: chunk.tokens)
                
                // Apply tokens incrementally
                // For visible range, apply immediately
                if let visibleRange {
                    let visibleTokens = chunk.tokens.filter { token in
                        NSLocationInRange(token.range.location, visibleRange) ||
                        NSLocationInRange(visibleRange.location, token.range)
                    }
                    if !visibleTokens.isEmpty {
                        await MainActor.run {
                            applyTokens(visibleTokens, to: textView, visibleRange: visibleRange)
                        }
                    }
                } else {
                    // Apply all tokens from this chunk
                    await MainActor.run {
                        applyTokens(chunk.tokens, to: textView)
                    }
                }
                
                // Update progress if needed
                if chunk.index.isMultiple(of: 5) || chunk.isComplete {
                    // Progress recording would go here if the method existed
                    // await performanceMonitor.recordProgress(chunk.progress)
                }
                
                // Cache if complete
                if chunk.isComplete {
                    let cacheKey = SmartTokenCache.CacheKey(
                        text: text,
                        language: language,
                        version: 0
                    )
                    await tokenCache.setCachedTokens(
                        allTokens,
                        for: cacheKey,
                        computationTime: Duration.seconds(0) // Time tracked separately
                    )
                }
            }
        } catch {
            // Task was cancelled or error occurred
            CrossPlatformLogger.logger().debug("Streaming highlighting cancelled or failed: \(error)")
        }
    }
    
    /// Check if streaming should be used based on text size
    public func shouldUseStreaming(for text: String) -> Bool {
        // Use streaming for files larger than 500KB
        text.count > 500_000
    }
}
