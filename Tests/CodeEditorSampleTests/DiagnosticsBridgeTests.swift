#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import Combine
import Testing

@MainActor
@Suite("DiagnosticsBridge")
struct DiagnosticsBridgeTests {
    @Test func translatesErrorDiagnosticToAnnotation() async throws {
        let hub = AnnotationsHub()
        let subject = PassthroughSubject<[String: [LSPDiagnostic]], Never>()
        let bridge = DiagnosticsBridge(
            diagnosticsPublisher: subject.eraseToAnyPublisher(),
            hub: hub,
            applyDecoration: { _, _ in },
            clearAllDecorations: {},
            activeURI: { "file:///x.swift" },
            currentTextLength: { 20 }
        )
        bridge.start()

        let diag = LSPDiagnostic(
            range: LSPRange(
                start: Position(line: 0, character: 13),
                end: Position(line: 0, character: 19)
            ),
            message: "Cannot convert",
            severity: .error
        )
        subject.send(["file:///x.swift": [diag]])
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(hub.diagnosticAnnotations.count == 1)
        #expect(hub.diagnosticAnnotations.first?.content.hasPrefix("ERROR:") == true)
        #expect(bridge.counts.errors == 1)
    }

    @Test func clearsOnEmptyEmission() async throws {
        let hub = AnnotationsHub()
        let subject = PassthroughSubject<[String: [LSPDiagnostic]], Never>()
        let bridge = DiagnosticsBridge(
            diagnosticsPublisher: subject.eraseToAnyPublisher(),
            hub: hub,
            applyDecoration: { _, _ in },
            clearAllDecorations: {},
            activeURI: { "file:///x.swift" },
            currentTextLength: { 20 }
        )
        bridge.start()

        let diag = LSPDiagnostic(
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 1)
            ),
            message: "x",
            severity: .error
        )
        subject.send(["file:///x.swift": [diag]])
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(hub.diagnosticAnnotations.count == 1)

        subject.send([:])
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(hub.diagnosticAnnotations.isEmpty)
    }

    @Test func clampsOutOfBoundsRange() async throws {
        let hub = AnnotationsHub()
        let subject = PassthroughSubject<[String: [LSPDiagnostic]], Never>()
        var captured: [NSRange] = []
        let bridge = DiagnosticsBridge(
            diagnosticsPublisher: subject.eraseToAnyPublisher(),
            hub: hub,
            applyDecoration: { _, range in captured.append(range) },
            clearAllDecorations: {},
            activeURI: { "file:///x.swift" },
            currentTextLength: { 3 }  // only 3 chars in buffer
        )
        bridge.start()

        let diag = LSPDiagnostic(
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 999)
            ),
            message: "way too long",
            severity: .warning
        )
        subject.send(["file:///x.swift": [diag]])
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(hub.diagnosticAnnotations.count == 1)
        // Range clamped to within [0, 3).
        #expect(captured.count <= 1)
        if let only = captured.first {
            #expect(only.location + only.length <= 3)
        }
    }
}
#endif
