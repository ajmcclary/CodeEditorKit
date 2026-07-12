@testable import CodeEditorCompletion
import CodeEditorLanguages
import Foundation
import Testing

private actor ProviderGate {
    private var arrivalCount = 0
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func arriveAndWait(for count: Int) async {
        arrivalCount += 1
        if arrivalCount == count {
            continuations.forEach { $0.resume() }
            continuations.removeAll()
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func arrivals() -> Int {
        arrivalCount
    }
}

private enum CoordinatorTestError: Error {
    case providerFailed
}

private struct CoordinatorProvider: CompletionProvider {
    let id: String
    let supportedLanguages: [Language] = [.swift]
    let gate: ProviderGate?
    let waitsForPeerCount: Int
    let label: String?
    let failure: (any Error)?
    let delay: Duration?

    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        if let gate {
            await gate.arriveAndWait(for: waitsForPeerCount)
        }
        if let delay {
            try await Task.sleep(for: delay)
        }
        if let failure {
            throw failure
        }
        return CompletionResult(
            items: label.map { [CompletionItemModel(label: $0, kind: .keyword)] } ?? [],
            context: context,
            isIncomplete: false,
            processingTime: 0
        )
    }
}

@MainActor
@Suite("CompletionRequestCoordinator")
struct CompletionRequestCoordinatorTests {
    private func context(_ text: String = "let") -> CompletionContextModel {
        CompletionContextModel(
            text: text,
            cursorPosition: text.utf16.count,
            language: .swift
        )
    }

    private func merge(
        _ results: [CompletionResult],
        context: CompletionContextModel,
        startTime _: Date
    ) -> CompletionResult {
        CompletionResult(
            items: results.flatMap(\.items),
            context: context,
            isIncomplete: results.contains { $0.isIncomplete },
            processingTime: 0
        )
    }

    @Test("providers fan out concurrently and failures remain isolated")
    func concurrentFanOutAndFailureIsolation() async throws {
        let gate = ProviderGate()
        let coordinator = CompletionRequestCoordinator(eventSink: CompletionEventBroadcaster())
        let providers: [any CompletionProvider] = [
            CoordinatorProvider(
                id: "successful",
                gate: gate,
                waitsForPeerCount: 2,
                label: "result",
                failure: nil,
                delay: nil
            ),
            CoordinatorProvider(
                id: "failing",
                gate: gate,
                waitsForPeerCount: 2,
                label: nil,
                failure: CoordinatorTestError.providerFailed,
                delay: nil
            )
        ]

        let result = try await coordinator.request(
            providers: providers,
            context: context(),
            processor: merge
        )

        #expect(await gate.arrivals() == 2)
        #expect(result.items.map(\.label) == ["result"])
    }

    @Test("a newer request cancels the active request")
    func newerRequestCancelsActiveRequest() async throws {
        let gate = ProviderGate()
        let coordinator = CompletionRequestCoordinator(eventSink: CompletionEventBroadcaster())
        let slow = CoordinatorProvider(
            id: "slow",
            gate: gate,
            waitsForPeerCount: 1,
            label: "stale",
            failure: nil,
            delay: .seconds(30)
        )
        let fast = CoordinatorProvider(
            id: "fast",
            gate: nil,
            waitsForPeerCount: 0,
            label: "fresh",
            failure: nil,
            delay: nil
        )

        let first = Task { @MainActor in
            try await coordinator.request(
                providers: [slow],
                context: context("first"),
                processor: merge
            )
        }
        while await gate.arrivals() == 0 {
            await Task.yield()
        }

        let second = try await coordinator.request(
            providers: [fast],
            context: context("second"),
            processor: merge
        )

        await #expect(throws: CancellationError.self) {
            try await first.value
        }
        #expect(second.items.map(\.label) == ["fresh"])
    }
}
