import Foundation

// MARK: - Text Processing Actor

/// Actor responsible for managing text processing operations
///
/// This actor isolates all text manipulation and processing operations,
/// ensuring thread-safe access to text buffers and processing state.
@available(macOS 13.0, iOS 16.0, *)
public actor TextProcessingActor {
    private var activeProcessors: [UUID: TextProcessor] = [:]
    private var textBuffers: [UUID: String] = [:]
    private let errorRecovery = ErrorRecoveryCoordinator()

    /// Configuration for text processing operations
    public struct TextProcessor {
        let id: UUID
        let type: ProcessorType
        let priority: TextProcessingPriority
        var isCancelled: Bool = false

        public enum ProcessorType: Sendable {
            case indentation
            case bracketMatching
            case lineWrapping
            case whitespaceNormalization
            case encoding(String.Encoding)
        }
    }

    /// Priority levels for editor text-processing work.
    public enum TextProcessingPriority: Int, Comparable, Sendable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        public static func < (lhs: TextProcessingPriority, rhs: TextProcessingPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Helper Methods

    private func convertToSwiftPriority(_ priority: TextProcessingPriority) -> _Concurrency.TaskPriority {
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
        priority: TextProcessingPriority = .high
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
            return try await processIndentation(text, id: processorId)

        case .bracketMatching:
            return try await processBracketMatching(text, id: processorId)

        case .lineWrapping:
            return try await processLineWrapping(text, id: processorId)

        case .whitespaceNormalization:
            return try await normalizeWhitespace(text, id: processorId)

        case .encoding(let encoding):
            return try await processEncoding(text, encoding: encoding, id: processorId)
        }
    }

    /// Cancel all active text processing operations.
    ///
    /// Sets `isCancelled` on every entry in `activeProcessors`. Inflight
    /// processing methods see the flag at their next `checkCancellation`
    /// boundary and throw `CancellationError`. Crucially, this works even
    /// when the *caller's* `Task` is not cancelled — the previous
    /// implementation only flipped the flag and the methods never read
    /// it, so the public API silently no-op'd unless the caller also
    /// cancelled its own task.
    public func cancelAllProcessing() {
        for id in activeProcessors.keys {
            activeProcessors[id]?.isCancelled = true
        }
    }

    // MARK: - Cancellation

    /// Throws `CancellationError` if either the caller's `Task` was
    /// cancelled or `cancelAllProcessing` has flipped this processor's
    /// actor-owned flag.
    private func checkCancellation(id: UUID) throws {
        try Task.checkCancellation()
        if activeProcessors[id]?.isCancelled == true {
            throw CancellationError()
        }
    }

    // MARK: - Processor Implementations
    //
    // Methods are simplified placeholders; real implementations will
    // do meaningful work and naturally insert additional
    // `try checkCancellation(id:)` calls between work units so
    // `cancelAllProcessing()` can interrupt long-running passes.

    private func processIndentation(_ text: String, id: UUID) async throws -> String {
        try checkCancellation(id: id)
        return text
    }

    private func processBracketMatching(_ text: String, id: UUID) async throws -> String {
        try checkCancellation(id: id)
        return text
    }

    private func processLineWrapping(_ text: String, id: UUID) async throws -> String {
        try checkCancellation(id: id)
        return text
    }

    private func normalizeWhitespace(_ text: String, id: UUID) async throws -> String {
        try checkCancellation(id: id)
        return text
    }

    private func processEncoding(_ text: String, encoding: String.Encoding, id: UUID) async throws -> String {
        try checkCancellation(id: id)
        guard let data = text.data(using: encoding),
              let result = String(data: data, encoding: encoding) else {
            throw CodeEditorError.encodingFailed(.utf8)
        }
        return result
    }

    // MARK: - Internal Test Seam

    /// Test-only entry point that simulates a long-running processor:
    /// registers a processor with `activeProcessors`, sleeps briefly to
    /// model real work, then re-checks cancellation. Production stubs
    /// finish synchronously and have no observable suspension window,
    /// so an external `cancelAllProcessing()` call can't race them —
    /// but real future implementations will, and this seam pins the
    /// cancellation contract that protects them.
    internal func processForCancellationTesting(text: String) async throws -> String {
        let processorId = UUID()
        let processor = TextProcessor(id: processorId, type: .indentation, priority: .high)
        activeProcessors[processorId] = processor
        defer { activeProcessors.removeValue(forKey: processorId) }

        try checkCancellation(id: processorId)
        try await Task.sleep(for: .milliseconds(50))
        try checkCancellation(id: processorId)
        return text
    }
}
