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
        let errored = CompletionActivityEntry(
            providerId: "swift-universal",
            language: .swift,
            triggerCharacter: ".",
            prefix: "view",
            itemCount: 0,
            durationMs: 0.8,
            timestamp: Date(timeIntervalSince1970: 0),
            error: "ProviderError(why: \"network\")"
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
        recent: [CompletionActivityEntry],
        last: CompletionActivityEntry?,
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

    private func sampleEntries() -> [CompletionActivityEntry] {
        [
            .init(
                providerId: "swift-universal",
                language: .swift,
                triggerCharacter: ".",
                prefix: "view",
                itemCount: 12,
                durationMs: 1.4,
                timestamp: Date(timeIntervalSince1970: 3),
                error: nil
            ),
            .init(
                providerId: "swift-universal",
                language: .swift,
                triggerCharacter: ".",
                prefix: "vie",
                itemCount: 8,
                durationMs: 0.9,
                timestamp: Date(timeIntervalSince1970: 2),
                error: nil
            ),
            .init(
                providerId: "sample.demo",
                language: .swift,
                triggerCharacter: nil,
                prefix: "",
                itemCount: 3,
                durationMs: 0.1,
                timestamp: Date(timeIntervalSince1970: 1),
                error: nil
            ),
            .init(
                providerId: "python-universal",
                language: .python,
                triggerCharacter: ".",
                prefix: "str",
                itemCount: 4,
                durationMs: 0.7,
                timestamp: Date(timeIntervalSince1970: 0),
                error: nil
            )
        ]
    }
}
#endif
