import CodeEditorAnnotations
import CodeEditorPlatform
import CodeEditorPlugin
import CodeEditorSwiftUI
import CodeEditorTextModel
import CodeEditorView
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Sample-side `AnnotationsDataSource` that surfaces two kinds of
/// per-line markers:
///
/// 1. **Breakpoints** — toggled red `ERROR` badges that stand in for the
///    debugger gutter. The framework's `DebuggerIntegrationCore` is
///    internal, so the sample fakes the rendering through annotations.
/// 2. **Demo annotations** — TODO / FIXME / WARNING badges added by the
///    user through the command palette or knob buttons.
///
/// Both render through the framework's existing annotation gutter. Each
/// `Annotation` carries an explicit `kind: AnnotationKind`, so the badge
/// color follows the host's intent rather than the framework parsing the
/// `content` string. The hub borrows the host's `EditorController` to
/// translate 1-based line numbers into ranges on demand.
@MainActor
@Observable
final class AnnotationsHub: AnnotationsDataSource {
    /// Set of 1-based line numbers carrying a breakpoint marker.
    private(set) var breakpointLines: Set<Int> = []

    /// 1-based line number → demo annotation kind. One entry per line
    /// (re-adding a different kind overwrites).
    private(set) var demoAnnotations: [Int: AnnotationKind] = [:]

    /// Server-vended diagnostic annotations (typically from LSP). Stored as a
    /// separate bucket so toggling the language server off doesn't disturb
    /// user-placed breakpoints or demo annotations.
    private(set) var diagnosticAnnotations: [Annotation] = []

    /// Weak handle on the host's `EditorController`; needed to translate
    /// line numbers into ranges when vending annotations.
    @ObservationIgnored
    weak var controller: EditorController?

    init(controller: EditorController? = nil) {
        self.controller = controller
    }

    // MARK: - Breakpoints

    func toggleBreakpoint(at line: Int) {
        guard line >= 1 else { return }
        if breakpointLines.contains(line) {
            breakpointLines.remove(line)
        } else {
            breakpointLines.insert(line)
        }
        controller?.reloadAnnotations()
    }

    func clearAllBreakpoints() {
        breakpointLines.removeAll()
        controller?.reloadAnnotations()
    }

    // MARK: - Demo annotations

    func addDemoAnnotation(kind: AnnotationKind, at line: Int) {
        guard line >= 1 else { return }
        demoAnnotations[line] = kind
        controller?.reloadAnnotations()
    }

    func removeDemoAnnotation(at line: Int) {
        demoAnnotations.removeValue(forKey: line)
        controller?.reloadAnnotations()
    }

    func clearAllDemoAnnotations() {
        demoAnnotations.removeAll()
        controller?.reloadAnnotations()
    }

    // MARK: - Diagnostic annotations

    /// Replace the current diagnostic bucket with `annotations` and trigger an
    /// annotation reload. Breakpoints and demo annotations are untouched.
    func replaceDiagnosticAnnotations(_ annotations: [Annotation]) {
        diagnosticAnnotations = annotations
        controller?.reloadAnnotations()
    }

    // MARK: - AnnotationsDataSource

    func annotations(for range: NSRange) -> [Annotation] {
        let all = currentAnnotations()
        return all.filter { TextRangeUtilities.overlaps($0.range, range) }
    }

    var textViewAnnotations: [CodeEditorViewAnnotation] {
        currentAnnotations().map { annotation in
            CodeEditorViewAnnotation(
                utf16Location: annotation.range.location,
                content: annotation.content,
                id: annotation.id
            )
        }
    }

    func textView(
        _: CodeEditorView,
        viewForLineAnnotation _: CodeEditorViewAnnotation,
        textLineFragment _: NSTextLineFragment,
        proposedViewFrame _: CGRect
    ) -> PlatformView? {
        // Default rendering — the framework reads each annotation's
        // explicit `kind` (set at construction below) for its badge color.
        nil
    }

    // MARK: - Internal builders

    private func currentAnnotations() -> [Annotation] {
        var out: [Annotation] = []
        if let controller {
            for line in breakpointLines.sorted() {
                guard let range = controller.nsRange(forLine: line) else { continue }
                out.append(Annotation(
                    range: range,
                    content: "breakpoint",
                    id: "bp-\(line)",
                    kind: .error
                ))
            }
            for line in demoAnnotations.keys.sorted() {
                guard let kind = demoAnnotations[line],
                      let range = controller.nsRange(forLine: line) else { continue }
                out.append(Annotation(
                    range: range,
                    content: "demo annotation",
                    id: "demo-\(kind.rawValue)-\(line)",
                    kind: kind
                ))
            }
        }
        // Diagnostics arrive with their own pre-computed ranges, so they're
        // visible even before a controller is attached.
        out.append(contentsOf: diagnosticAnnotations)
        return out
    }
}
