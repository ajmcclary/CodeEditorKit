import CodeEditorCommon
import CodeEditorLanguages
import Foundation

/// Receives completion-provider execution events.
protocol CompletionEventSink: Sendable {
    func publish(_ event: CompletionEvent)
}

extension CompletionEventBroadcaster: CompletionEventSink {}

/// Owns cancellation, debouncing, and concurrent completion-provider fan-out.
@MainActor
final class CompletionRequestCoordinator {
    typealias ResultProcessor = @MainActor @Sendable (
        [CompletionResult],
        CompletionContextModel,
        Date
    ) -> CompletionResult

    private var currentRequest: Task<CompletionResult, Error>?
    private var currentRequestID: UUID?
    private let debouncer: CompletionDebouncer
    private let eventSink: any CompletionEventSink

    init(
        eventSink: any CompletionEventSink,
        debouncer: CompletionDebouncer = CompletionDebouncer()
    ) {
        self.debouncer = debouncer
        self.eventSink = eventSink
    }

    /// Configures the operation invoked by the public debounced-request API.
    func setDebouncedRequestHandler(
        _ handler: @escaping @Sendable (CompletionContextModel) async throws -> CompletionResult
    ) {
        debouncer.setCompletionHandler(handler)
    }

    /// Executes all applicable providers concurrently and processes their results.
    func request(
        providers: [any CompletionProvider],
        context: CompletionContextModel,
        processor: @escaping ResultProcessor
    ) async throws -> CompletionResult {
        currentRequest?.cancel()

        let requestID = UUID()
        let eventSink = eventSink
        let request = Task { @MainActor in
            let startTime = Date()
            let results = await Self.collectResultsConcurrently(
                from: providers,
                context: context,
                eventSink: eventSink
            )
            try Task.checkCancellation()
            return processor(results, context, startTime)
        }
        currentRequest = request
        currentRequestID = requestID

        defer {
            if currentRequestID == requestID {
                currentRequest = nil
                currentRequestID = nil
            }
        }
        return try await request.value
    }

    /// Requests completions through the configured debounce policy.
    func requestDebounced(
        for context: CompletionContextModel,
        priority: CompletionPriority,
        completion: @escaping @Sendable (Result<CompletionResult, Error>) -> Void
    ) {
        debouncer.requestCompletions(
            for: context,
            priority: priority
        ) { result in
            Task { @MainActor in
                completion(result)
            }
        }
    }

    /// Cancels both active and queued requests.
    func cancelCurrentRequest() {
        currentRequest?.cancel()
        currentRequest = nil
        currentRequestID = nil
        debouncer.cancelAllRequests()
    }

    /// Mutable debounce policy exposed by the source-compatible façade.
    var debouncingConfiguration: CompletionDebouncer {
        debouncer
    }

    private static func collectResultsConcurrently(
        from providers: [any CompletionProvider],
        context: CompletionContextModel,
        eventSink: any CompletionEventSink
    ) async -> [CompletionResult] {
        await withTaskGroup(of: CompletionResult?.self) { group in
            for provider in providers {
                group.addTask {
                    let start = Date()
                    do {
                        let result = try await provider.completions(for: context)
                        eventSink.publish(
                            CompletionEvent(
                                providerID: provider.id,
                                context: context,
                                durationMilliseconds: Date().timeIntervalSince(start) * 1_000,
                                outcome: .succeeded(itemCount: result.items.count)
                            )
                        )
                        return result
                    } catch {
                        eventSink.publish(
                            CompletionEvent(
                                providerID: provider.id,
                                context: context,
                                durationMilliseconds: Date().timeIntervalSince(start) * 1_000,
                                outcome: .failed(SendableError(error, domain: "CompletionProvider"))
                            )
                        )
                        return nil
                    }
                }
            }

            var results: [CompletionResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }
    }
}
