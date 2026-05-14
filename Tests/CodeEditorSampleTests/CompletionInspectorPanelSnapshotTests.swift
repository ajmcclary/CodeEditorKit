#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class CompletionInspectorPanelSnapshotTests: XCTestCase {
    func testEmptyStateLight() {
        let view = panel(
            providers: [],
            recent: [],
            last: nil,
            requests: 0,
            cacheHitRate: 0,
            avgMs: 0
        )
        assertSnapshot(of: host(view, scheme: .light), as: .image, named: "empty-light")
    }

    func testEmptyStateDark() {
        let view = panel(
            providers: [],
            recent: [],
            last: nil,
            requests: 0,
            cacheHitRate: 0,
            avgMs: 0
        )
        assertSnapshot(of: host(view, scheme: .dark), as: .image, named: "empty-dark")
    }

    func testPopulatedStateLight() {
        let view = panel(
            providers: sampleProviders(),
            recent: sampleEntries(),
            last: sampleEntries().first,
            requests: 174,
            cacheHitRate: 0.35,
            avgMs: 2.1
        )
        assertSnapshot(of: host(view, scheme: .light), as: .image, named: "populated-light")
    }

    func testPopulatedStateDark() {
        let view = panel(
            providers: sampleProviders(),
            recent: sampleEntries(),
            last: sampleEntries().first,
            requests: 174,
            cacheHitRate: 0.35,
            avgMs: 2.1
        )
        assertSnapshot(of: host(view, scheme: .dark), as: .image, named: "populated-dark")
    }

    func testErrorStateLight() {
        let errored = CompletionEvent(
            providerID: "swift-universal",
            language: .swift,
            triggerCharacter: ".",
            prefix: "view",
            durationMilliseconds: 0.8,
            outcome: .failed(SendableError(message: "ProviderError(why: \"network\")", domain: "CompletionProvider")),
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let view = panel(
            providers: sampleProviders(),
            recent: [errored] + sampleEntries(),
            last: errored,
            requests: 174,
            cacheHitRate: 0.35,
            avgMs: 2.1
        )
        assertSnapshot(of: host(view, scheme: .light), as: .image, named: "error-light")
    }

    // MARK: - Helpers

    private func panel(
        providers: [CompletionSampleCoordinator.RegisteredProviderSummary],
        recent: [CompletionEvent],
        last: CompletionEvent?,
        requests: Int,
        cacheHitRate: Double,
        avgMs: Double
    ) -> some View {
        CompletionInspectorPanel(
            registeredProviders: providers,
            recentActivity: recent,
            lastActivity: last,
            requests: requests,
            cacheHitRate: cacheHitRate,
            avgProcessingMs: avgMs,
            onFireAtCursor: {},
            onClear: {}
        )
        .frame(width: 360)
    }

    private func host<V: View>(_ view: V, scheme: ColorScheme) -> NSView {
        let hosting = NSHostingView(rootView: view.preferredColorScheme(scheme))
        hosting.frame = CGRect(x: 0, y: 0, width: 360, height: 460)
        return hosting
    }

    private func sampleProviders() -> [CompletionSampleCoordinator.RegisteredProviderSummary] {
        [
            .init(providerId: "c-universal", languages: [.c], triggerCharacters: ["."], supportsSnippets: true),
            .init(providerId: "go-universal", languages: [.go], triggerCharacters: ["."], supportsSnippets: true),
            .init(providerId: "java-universal", languages: [.java], triggerCharacters: ["."], supportsSnippets: true),
            .init(providerId: "javascript-universal", languages: [.javascript], triggerCharacters: ["."], supportsSnippets: true),
            .init(providerId: "python-universal", languages: [.python], triggerCharacters: ["."], supportsSnippets: true),
            .init(providerId: "rust-universal", languages: [.rust], triggerCharacters: ["."], supportsSnippets: true),
            .init(providerId: "sample.demo", languages: [], triggerCharacters: [], supportsSnippets: true),
            .init(providerId: "swift-universal", languages: [.swift], triggerCharacters: ["."], supportsSnippets: true),
            .init(providerId: "typescript-universal", languages: [.typescript], triggerCharacters: ["."], supportsSnippets: true)
        ]
    }

    private func sampleEntries() -> [CompletionEvent] {
        [
            CompletionEvent(
                providerID: "swift-universal",
                language: .swift,
                triggerCharacter: ".",
                prefix: "view",
                durationMilliseconds: 1.4,
                outcome: .succeeded(itemCount: 12),
                timestamp: Date(timeIntervalSince1970: 3)
            ),
            CompletionEvent(
                providerID: "swift-universal",
                language: .swift,
                triggerCharacter: ".",
                prefix: "vie",
                durationMilliseconds: 0.9,
                outcome: .succeeded(itemCount: 8),
                timestamp: Date(timeIntervalSince1970: 2)
            ),
            CompletionEvent(
                providerID: "sample.demo",
                language: .swift,
                triggerCharacter: nil,
                prefix: "",
                durationMilliseconds: 0.1,
                outcome: .succeeded(itemCount: 3),
                timestamp: Date(timeIntervalSince1970: 1)
            ),
            CompletionEvent(
                providerID: "python-universal",
                language: .python,
                triggerCharacter: ".",
                prefix: "str",
                durationMilliseconds: 0.7,
                outcome: .succeeded(itemCount: 4),
                timestamp: Date(timeIntervalSince1970: 0)
            )
        ]
    }
}
#endif
