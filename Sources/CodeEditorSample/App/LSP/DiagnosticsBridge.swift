#if canImport(AppKit)
import AppKit
import CodeEditorAnnotations
import CodeEditorPlugin
import Combine

/// Translates LSP diagnostics into sample-side `Annotation` values for the
/// gutter, and into inline temporary-attribute decorations for the squiggle.
///
/// Designed for dependency injection — production passes
/// `client.$diagnostics.eraseToAnyPublisher()` plus closures that route to
/// `EditorController.applyTemporaryAttributes` and `clearAllTemporaryAttributes`.
/// Tests pass a `PassthroughSubject` and no-op decoration closures.
@MainActor
final class DiagnosticsBridge {
    struct Counts: Equatable {
        var errors = 0
        var warnings = 0
        var info = 0
        static let zero = Self()
    }

    private(set) var counts: Counts = .zero

    private let diagnosticsPublisher: AnyPublisher<[String: [LSPDiagnostic]], Never>
    private let hub: AnnotationsHub
    private let applyDecoration: (_ attributes: [NSAttributedString.Key: Any], _ range: NSRange) -> Void
    private let clearAllDecorations: () -> Void
    private let activeURI: @MainActor () -> String?
    /// Convert an LSP range into a UTF-16 `NSRange` against the active
    /// buffer. Production wires this to `EditorController.nsRange(forLSPRange:)`;
    /// tests can stub it to a fixture-aware identity-style function.
    private let convertLSPRange: @MainActor (LSPRange) -> NSRange?
    private var subscription: AnyCancellable?

    init(
        diagnosticsPublisher: AnyPublisher<[String: [LSPDiagnostic]], Never>,
        hub: AnnotationsHub,
        applyDecoration: @escaping (_ attributes: [NSAttributedString.Key: Any], _ range: NSRange) -> Void,
        clearAllDecorations: @escaping () -> Void,
        activeURI: @escaping @MainActor () -> String?,
        convertLSPRange: @escaping @MainActor (LSPRange) -> NSRange?
    ) {
        self.diagnosticsPublisher = diagnosticsPublisher
        self.hub = hub
        self.applyDecoration = applyDecoration
        self.clearAllDecorations = clearAllDecorations
        self.activeURI = activeURI
        self.convertLSPRange = convertLSPRange
    }

    func start() {
        // Don't rely on `receive(on: DispatchQueue.main)` + `assumeIsolated` —
        // DispatchQueue.main isolation is not statically equivalent to MainActor
        // and the assumption only holds by convention. Hop into MainActor
        // explicitly via a Task so the isolation is checked by the compiler.
        subscription = diagnosticsPublisher
            .sink { [weak self] dict in
                Task { @MainActor [weak self] in
                    self?.handle(dict)
                }
            }
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
        clearAllDecorations()
        hub.replaceDiagnosticAnnotations([])
        counts = .zero
    }

    private func handle(_ dict: [String: [LSPDiagnostic]]) {
        guard let uri = activeURI() else {
            clearAllDecorations()
            hub.replaceDiagnosticAnnotations([])
            counts = .zero
            return
        }
        let diagnostics = dict[uri] ?? []

        clearAllDecorations()

        var annotations: [Annotation] = []
        var newCounts = Counts()

        for diag in diagnostics {
            switch diag.severity {
            case .error: newCounts.errors += 1
            case .warning: newCounts.warnings += 1
            default: newCounts.info += 1
            }

            let nsRange = convertLSPRange(diag.range) ?? NSRange(location: 0, length: 0)
            if nsRange.length > 0 {
                let color: NSColor = {
                    switch diag.severity {
                    case .error: return .systemRed
                    case .warning: return .systemYellow
                    default: return .systemBlue
                    }
                }()
                let pattern = NSUnderlineStyle([.single, .patternDot]).rawValue
                applyDecoration(
                    [
                        .underlineColor: color,
                        .underlineStyle: pattern
                    ],
                    nsRange
                )
            }

            let annotationKind: AnnotationKind = {
                switch diag.severity {
                case .error: return .error
                case .warning: return .warning
                default: return .info
                }
            }()
            annotations.append(Annotation(
                range: nsRange.length > 0 ? nsRange : NSRange(location: 0, length: 0),
                content: diag.message,
                kind: annotationKind
            ))
        }

        hub.replaceDiagnosticAnnotations(annotations)
        counts = newCounts
    }
}
#endif
